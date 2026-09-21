# CSV不足チェックとロードの実機検証（2026-09-21 JST）

Snowflake CLI 3.26.0で専用DBを作成し、変更後の `LOAD_BRONZE()` の不足チェック、通常ロード、再ロードとSilver / Goldの品質を確認しました。必要なCSVが不足している場合は `ERROR: Missing required CSV files: ...` を返し、全6Bronzeテーブルの件数と内容ハッシュが呼び出し前後で一致しました。

## 検証範囲と実行方法の差分

- 専用DB `DATA_WAREHOUSE_PREFLIGHT_20260921_075949` を使用し、SQL内の完全修飾名とログ出力先もこのDBに置き換えました。既存の `DATA_WAREHOUSE` は変更していません。
- `setup/rebuild.sql` の `!source` をCLI 3.26.0のファイル読み込み処理で展開し、そのSQLを `snow sql -f` で実行しました。検証DBは先に `CREATE DATABASE` で新規作成し、`CREATE OR REPLACE DATABASE` は実行していません。既存DBの置き換え動作は検証対象外です。
- Event Tableは `setup/ensure_event_table.sql` によりSYSADMINで作成しました。アカウント全体への影響を避けるため、出力先設定だけはACCOUNTADMINによる `ALTER DATABASE ... SET EVENT_TABLE` に変更しました。`setup/configure_event_target.sql` の `ALTER ACCOUNT` は実行していません。
- Bronze / Silverのプロシージャ、`configure_logging.sql`、Goldビュー、既存の品質チェックSQLと `query_load_logs.sql` を使用しました。
- CSVはリポジトリの6ファイルを使用しました。アップロードは `snow sql` 経由の `PUT ... AUTO_COMPRESS=FALSE OVERWRITE=TRUE` で実施し、`snow stage copy` は今回の対象外です。PUT後に別途REFRESHせず、プロシージャ内の一覧更新で検出できることを確認しました。
- 誤ったファイル名を検証するため、元CSVを変更せず、検証ステージに `datasets/source_erp/PX_CAT_G1V2.csv.bak` を追加しました。

## 結果

| ケース | 結果 |
| --- | --- |
| ステージが空 | 必要な6パスすべてを含むERRORを返却。各Bronzeテーブルに事前投入した1行の件数・内容ハッシュを保持 |
| 正しいCSVが5つ、残りが `.csv.bak` | 不足している正しいパスのみを返却。全6テーブルの件数・内容ハッシュを保持 |
| 正しいCSVを追加し、6ファイルを配置 | `LOAD_BRONZE()` / `LOAD_SILVER()` がともに `SUCCESS` |
| `.csv.bak` が残った状態でロード | CSVとBronzeの件数が全6テーブルで一致。似た名前の余分なファイルをロードしない |
| ロード後に正しいCSVを1つ削除 | REFRESHを別途実行せず呼び出して不足を検出。ロード済みの全6Bronzeテーブルの件数・内容ハッシュを保持 |
| 同じ6CSVを再PUT・再ロード | Bronze / Silverともに `SUCCESS`。全15オブジェクトの件数が初回と一致 |
| Silverの異常検出チェック | 初回・再ロードともに0件を期待する10クエリすべて0件 |
| Goldの品質チェック | 初回・再ロードともに3クエリすべて0件 |
| ログ | INFO 91件、想定した不足検出のERROR 3件。正常ロード4回分の完了ログを確認。SYSADMINでログ確認SQLを実行成功 |
| 後片付け | 検証DBを削除し、存在しないことを確認。アカウントのEVENT_TABLE設定が検証前後で同じことを確認 |

Silverの分類値は、婚姻状態がMarried / Single、性別がFemale / Male / n/a、商品ラインがMountain / Other Sales / Road / Touring / n/a、国が6か国とn/a、保守区分がNo / Yesであることを確認しました。生年月日の確認対象（実行日から120年前より古い値、または未来の日付）は初回・再ロードともに0種類でした。年齢の目安に該当すること自体を不具合とは判断していません。

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

## 再確認する場合

専用DBへ参照先を置き換え、次の順番で確認します。既存環境でファイルを削除して試さないでください。

1. DB・ステージ・テーブル・ログ保存先・プロシージャを作成し、DB単位のログ出力先とログレベルを設定する。
2. Bronzeの全6テーブルに確認用データを入れ、件数と `HASH_AGG(*)` を記録する。
3. ステージが空の状態で `LOAD_BRONZE()` を呼び、不足6ファイルのERRORとデータ保持を確認する。
4. 正しいCSVを5つと `.csv.bak` をPUTして呼び出し、残り1ファイルのERRORとデータ保持を確認する。
5. 正しい残り1ファイルをPUTし、Bronze → Silver → Gold作成・品質確認を実行する。
6. 正しいCSVを1つ削除して再度Bronzeを呼び、不足ERRORと全6テーブルのデータ保持を確認する。
7. 全6CSVを再PUTしてBronze → Silverの再ロードを行い、件数・品質・ログを確認する。
8. 検証DBを削除し、アカウント設定に変更がないことを確認する。

## 制限と未検証の範囲

存在チェックは、過去のCSVが残っている場合の更新漏れ、空ファイル、CSV内容の不備を判定しません。チェックとCOPYの間にファイルを変更する競合や、ロード途中の障害復旧・全テーブルの原子性は対象外です。ロード中にステージを変更しないでください。

不足時の保持確認には件数と `HASH_AGG(*)` を使用しました。正常な再ロード前後の比較は件数と品質チェックであり、全行の完全一致は検証していません。

## 参照仕様

- [ディレクトリテーブルの参照](https://docs.snowflake.com/en/user-guide/data-load-dirtables-query)
- [ALTER STAGEによる一覧更新](https://docs.snowflake.com/en/sql-reference/sql/alter-stage)
- [COPY INTOのFILES・ON_ERROR](https://docs.snowflake.com/en/sql-reference/sql/copy-into-table)
