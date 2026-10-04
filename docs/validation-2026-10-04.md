# 顧客の重複排除とGold列名の実機検証（2026-10-04 JST）

Snowflake CLI 3.26.0で専用DBを作成し、次の2コミットを適用した状態で、構築・ロード・品質確認・再ロードを検証しました。両ロードとも `SUCCESS` を返し、全15オブジェクトの件数は[2026-09-21の検証](validation-2026-09-21.md)と一致しました。

- `22b4df5` fix(silver): 顧客の重複排除で作成日がNULLの行を最新として選ばない
- `e7aa4b7` docs: データカタログの保守区分の列名をGoldビューに合わせる

SnowflakeはデフォルトでNULLを最大値として扱い、`DESC` ではNULLを先頭に並べます。SQL Serverとは逆の順序です。修正前の `ORDER BY cst_create_date DESC` では、作成日がNULLの重複行が最新として選ばれることを確認し、`DESC NULLS LAST` で日付のある行が選ばれることを確認しました。

## 検証範囲と実行方法の差分

- 専用DB `DATA_WAREHOUSE_NULLORDER_20261004` を使用し、SQL内の完全修飾名をこのDBに置き換えました。既存の `DATA_WAREHOUSE` は変更していません。
- 検証DBは `CREATE OR REPLACE DATABASE` ではなく `CREATE DATABASE` で新規作成しました。既存DBの置き換え動作は検証対象外です。
- `setup/rebuild.sql` の `!source` は使わず、Bronze / SilverのDDLを連結して `snow sql -f` で実行しました。連結時に作業側で余分な `;` を挿入したため、Bronzeテーブル作成後に空文のエラーで停止しました。その後、Silver DDLとEvent Table作成を別途実行しています。リポジトリのSQLファイル自体の問題ではありません。
- 上記の停止により、プロシージャ作成と `logging/configure_logging.sql` は、Event Tableの作成・出力先設定より先に実行しています。ロード前にはすべての設定が完了しており、ログは記録されました。
- ログ出力先は、アカウント全体への影響を避けるため、ACCOUNTADMINによる `ALTER DATABASE ... SET EVENT_TABLE` に変更しました。`logging/configure_event_target.sql` の `ALTER ACCOUNT` は実行していません。
- CSVはリポジトリの6ファイルを使用し、[セットアップガイドの手順7](setup.md#7-csvをステージへアップロードする)どおり `snow stage copy` でアップロードしました。
- 修正の確認用に、検証DBのBronzeへ1行を直接追加しました（後述）。元CSVは変更していません。

## 結果

| 項目 | 結果 |
| --- | --- |
| DB・4スキーマ・ステージ・Bronze / Silver各6テーブル・Event Table | 作成成功 |
| 両ロードプロシージャ作成・ログレベル設定 | 成功 |
| CSVアップロード | 6ファイルを `UPLOADED` で確認 |
| 初回の `LOAD_BRONZE()` / `LOAD_SILVER()` | 両方 `SUCCESS` |
| 全15オブジェクトの件数 | 2026-09-21の検証と一致 |
| Silverの異常検出チェック | 0件を期待する10クエリすべて0件 |
| Silverの分類値 | 婚姻状態がMarried / Single、商品ラインがMountain / Other Sales / Road / Touring / n/a、性別がFemale / Male / n/a、国が6か国とn/a、保守区分がNo / Yes |
| Silverの生年月日確認 | 0種類 |
| Goldの品質チェック | 3クエリすべて0件 |
| Goldの列名 | `DIM_PRODUCTS` の列が `MAINTENANCE`（VARCHAR(50)）であり、修正後のカタログと一致 |
| 作成日がNULLの重複行（後述） | 修正前の並び順ではNULLの行、修正後のSilverでは日付のある行を選択 |
| CSVからの再ロード | 両方 `SUCCESS`。件数・品質チェック結果が初回と一致 |
| ログ | `LOAD_BRONZE` 2回分のINFO 44件、`LOAD_SILVER` 3回分のINFO 66件、ERROR 0件。SYSADMINで `logging/query_load_logs.sql` の実行成功 |
| 後片付け | 検証DBを削除。アカウントのEVENT_TABLE設定と既存DBが検証前後で同じことを確認 |

## 作成日がNULLの重複行の確認

現在のCSVで重複する顧客IDは5件あり、すべて作成日が入っています。作成日がNULLの4行は、いずれも顧客IDもNULLで、ロード時に除外されます。そのため、通常のロードでは修正前後の結果は変わりません。

修正の効果を確認するため、初回ロード後に検証DBのBronzeへ次の1行を追加しました。

```sql
INSERT INTO <検証DB>.BRONZE.CRM_CUST_INFO
VALUES (29433, 'AW00029433', 'NULLDATE_TEST', 'King', 'S', 'F', NULL);
```

| 確認方法 | 選ばれた行 |
| --- | --- |
| 修正前の `ORDER BY cst_create_date DESC` をBronzeに直接適用 | `NULLDATE_TEST`（作成日NULL） |
| 修正後の `LOAD_SILVER()` を実行し、Silverを参照 | `Thomas`、Married、Male、2026-01-27 |

修正後のSilverの `CRM_CUST_INFO` は18,484件で、`NULLDATE_TEST` は0件でした。確認後、CSVから `LOAD_BRONZE()` / `LOAD_SILVER()` を再実行して追加行を除いています。

## データ件数

初回・再ロードで以下の件数が一致しました。

| オブジェクト | 件数 |
| --- | ---: |
| `BRONZE.CRM_CUST_INFO` | 18,494 |
| `BRONZE.CRM_PRD_INFO` | 397 |
| `BRONZE.CRM_SALES_DETAILS` | 60,398 |
| `BRONZE.ERP_CUST_AZ12` | 18,484 |
| `BRONZE.ERP_LOC_A101` | 18,484 |
| `BRONZE.ERP_PX_CAT_G1V2` | 37 |
| `SILVER.CRM_CUST_INFO` | 18,484 |
| `SILVER.CRM_PRD_INFO` | 397 |
| `SILVER.CRM_SALES_DETAILS` | 60,398 |
| `SILVER.ERP_CUST_AZ12` | 18,484 |
| `SILVER.ERP_LOC_A101` | 18,484 |
| `SILVER.ERP_PX_CAT_G1V2` | 37 |
| `GOLD.DIM_CUSTOMERS` | 18,484 |
| `GOLD.DIM_PRODUCTS` | 295 |
| `GOLD.FACT_SALES` | 60,398 |

## 制限と未検証の範囲

- 商品の `LEAD(prd_start_dt) OVER (... ORDER BY prd_start_dt ASC)` もNULLの位置がSQL Serverと逆ですが、開始日がNULLの行の扱いは業務ルールが未決定のため変更していません。現在のCSVでは開始日がNULLの行は0件です。
- `!source` によるファイル読み込み、`CREATE OR REPLACE DATABASE`、`ALTER ACCOUNT SET EVENT_TABLE` は実行していません。
- 再ロード前後の比較は件数と品質チェックであり、全行の完全一致は検証していません。

## 参照仕様

- [ORDER BYとNULLの並び順](https://docs.snowflake.com/en/sql-reference/constructs/order-by)
- [ウィンドウ関数の構文](https://docs.snowflake.com/en/sql-reference/functions-analytic)
