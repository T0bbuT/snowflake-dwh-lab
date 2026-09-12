# セットアップとデータ更新の実行順序

このページを入口として、接続準備からGoldの品質確認まで順番に進めます。初回は下記の順序表を上から実行し、構築済みの環境では「データ更新時」へ進んでください。

実行結果と確認事項は[2026-09-13の実機検証記録](validation-2026-09-13.md)を参照してください。

## 前提と接続準備

- Snowflake CLI（`snow`）をインストールし、[キーペア認証ガイド](setup-keypair-auth.md)に従って接続を設定します。
- `COMPUTE_WH` が存在し、接続ユーザーが利用できることを確認します。このリポジトリにはウェアハウス作成SQLはありません。
- 通常の構築・ロードには `SYSADMIN`、Event Tableの作成とアカウント設定には `ACCOUNTADMIN` を使用します。
- コマンドはリポジトリのルートで実行し、`my_connection` を自分の接続名に置き換えます。各SQLに固定されたロール・ウェアハウスを変更する場合は、SQL内の `USE` 文も合わせてください。

```bash
snow connection test -c my_connection
```

SnowsightでGit上のSQLを編集・実行したい場合は、[Git Workspaceガイド](setup-git-workspace.md)も参照してください。Git連携は任意です。ローカルCSVのアップロードはターミナルから行います。

## 初回セットアップの順序

**新規環境向けの手順です。`init_databases.sql` は既存DBを置き換え、Bronze / SilverのDDLはテーブルを再作成します。`init_stage.sql` はステージを再作成してアップロード済みファイルを削除します。構築済み環境で一括再実行しないでください。**

| 順序 | 実行するもの | 目的・完了の目安 |
| --- | --- | --- |
| 1 | [init_databases.sql](../scripts/init_databases.sql) | `DATA_WAREHOUSE` と `STAGING` / `BRONZE` / `SILVER` / `GOLD` スキーマを作成 |
| 2 | [init_stage.sql](../scripts/init_stage.sql) | CSV用の内部ステージとファイルフォーマットを設定 |
| 3 | [ddl_bronze.sql](../scripts/bronze/ddl_bronze.sql) | Bronzeの6テーブルを作成 |
| 4 | [ddl_silver.sql](../scripts/silver/ddl_silver.sql) | Silverの6テーブルを作成 |
| 5 | [proc_load_bronze.sql](../scripts/bronze/proc_load_bronze.sql) | `LOAD_BRONZE()` を定義（まだロードしない） |
| 6 | [proc_load_silver.sql](../scripts/silver/proc_load_silver.sql) | `LOAD_SILVER()` を定義（まだロードしない） |
| 7 | [init_event_table.sql](../scripts/init_event_table.sql) | Event Tableを作成し、両プロシージャのログレベルを設定 |
| 8 | [CSVガイドの手順3〜4](load-local-csv.md#3-csvをアップロード) | CSVをアップロードし、ステージ内の6ファイルを確認 |
| 9 | `CALL DATA_WAREHOUSE.BRONZE.LOAD_BRONZE();` | CSV → Bronze。戻り値が `SUCCESS` であることを確認 |
| 10 | `CALL DATA_WAREHOUSE.SILVER.LOAD_SILVER();` | Bronze → Silver。戻り値が `SUCCESS` であることを確認 |
| 11 | [quality_checks_silver.sql](../tests/quality_checks_silver.sql) | Silverの品質を確認 |
| 12 | [ddl_gold.sql](../scripts/gold/ddl_gold.sql) | 顧客・商品・売上の3ビューを作成 |
| 13 | [quality_checks_gold.sql](../tests/quality_checks_gold.sql) | Goldのキー重複・参照整合性を確認 |

手順7は両プロシージャへの `ALTER PROCEDURE` を含むため、必ず手順5〜6の後に実行します。プロシージャ内の「事前にEvent Tableを設定」という前提は、ロードを呼び出す前の準備を指します。また、手順7はアカウントのEvent Table設定を変更するため、既存のログ出力先がある環境ではその設定を確認してください。

### 1〜7. オブジェクトを作成する

以下は順序表に対応するコマンドです。各コマンドの成功を確認してから次へ進みます。

```bash
snow sql -c my_connection -f scripts/init_databases.sql
snow sql -c my_connection -f scripts/init_stage.sql
snow sql -c my_connection -f scripts/bronze/ddl_bronze.sql
snow sql -c my_connection -f scripts/silver/ddl_silver.sql
snow sql -c my_connection -f scripts/bronze/proc_load_bronze.sql
snow sql -c my_connection -f scripts/silver/proc_load_silver.sql
snow sql -c my_connection -f scripts/init_event_table.sql
```

### 8〜11. CSVをロードし、Silverを確認する

[CSVガイドの手順3〜4](load-local-csv.md#3-csvをアップロード)でアップロードと6ファイルの確認を済ませた後、以下を1コマンドずつ実行します。

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -q 'CALL DATA_WAREHOUSE.BRONZE.LOAD_BRONZE();'
```

戻り値が `SUCCESS` なら、Silverへ進みます。

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -q 'CALL DATA_WAREHOUSE.SILVER.LOAD_SILVER();'
```

両プロシージャは例外を捕捉し、失敗時には `ERROR: ...` を返します。CLIの終了コードだけでは成功を判断できません。エラーがあれば次のレイヤへ進まず、下記のログを確認してください。ロードは各テーブルを `TRUNCATE` して入れ替えるため、失敗時は一部だけ更新されている可能性があります。

Silverが `SUCCESS` になったら品質を確認します。

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  --database DATA_WAREHOUSE -f tests/quality_checks_silver.sql
```

「期待: 結果なし」のクエリは0件であることを確認します。`SELECT DISTINCT` など値の分布を確認するクエリは、表示された値が想定どおりかを確認します。問題があれば調査してからGoldへ進みます。

生年月日のチェックは1926-01-01より前の日付も抽出しますが、現在の変換処理はこの下限を制限していません。同梱CSVでは19件が該当するため、結果を確認し、許容範囲を判断してください。

### 12〜13. Goldを作成して確認する

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -f scripts/gold/ddl_gold.sql
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -f tests/quality_checks_gold.sql
```

Goldの品質チェックは各クエリが0件であることを確認します。Goldはビューなので、別途ロード用のプロシージャを呼ぶ必要はありません。

## ログを確認する

```bash
snow sql -c my_connection --role ACCOUNTADMIN --warehouse COMPUTE_WH \
  -f scripts/query_load_logs.sql
```

[query_load_logs.sql](../scripts/query_load_logs.sql)はBronze / Silverのログとエラーログを表示します。Event Tableへの反映には数分のラグがある場合があります。現行のセットアップは `ACCOUNTADMIN` でEvent Tableを作成し、他ロールへの参照権限を付与していないため、ここでは作成時のロールで確認します。

## データ更新時

構築済みなら、次の順序で実行します。

1. [CSVガイドの手順3〜4](load-local-csv.md#3-csvをアップロード)でCSVを上書きアップロードし、ファイルを確認する。
2. `LOAD_BRONZE()` を呼び、`SUCCESS` を確認する。
3. `LOAD_SILVER()` を呼び、`SUCCESS` を確認する。
4. Silver / Goldの品質チェックを実行し、必要に応じてログを確認する。

コマンドは上の手順8〜13を参照してください。Goldのビュー定義を変更していなければ、手順12のDDL実行は不要です。

## 定義を変更したときの再実行範囲

| 変更・状況 | 実行するもの |
| --- | --- |
| Bronze / Silverのプロシージャだけ変更 | 該当する `proc_load_*.sql` → `init_event_table.sql` でログ設定を再適用 → 対象レイヤから下流のロード・品質確認 |
| Goldのビュー定義だけ変更 | `ddl_gold.sql` → Gold品質チェック |
| ステージを再作成 | CSVの再アップロード → Bronze → Silver → 品質確認 |
| Bronze / Silverのテーブルを再作成 | 対象レイヤから下流のロード・品質確認。列定義を変えた場合は関連プロシージャ・ビューも整合させる |
| DBを再作成 | 初回セットアップの手順2以降をすべて実行 |

`init_event_table.sql` は通常のCSV更新時には不要ですが、DBやプロシージャを再作成した場合は再実行してください。
