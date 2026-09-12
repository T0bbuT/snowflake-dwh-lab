# ローカルCSVをSnowflake CLIで取り込む

ローカルの `datasets/` にあるCSVを `snow stage copy` で内部ステージへアップロードし、既存の `LOAD_BRONZE()` でBronzeテーブルへ取り込みます。SnowsightのワークスペースへのCSV配置は不要です。

```text
datasets/ → snow stage copy（内部でPUT）→ STG_CSV_FILES → LOAD_BRONZE() → Bronzeテーブル
```

## 前提

- Snowflake CLI（`snow`）をインストール済みであること。
- 接続設定が済んでいること。設定方法は[キーペア認証ガイド](setup-keypair-auth.md)を参照してください。
- 接続ユーザーが `SYSADMIN` ロールと `COMPUTE_WH` ウェアハウスを利用できること。このリポジトリのSQLもこの設定を使用します。
- 以下のコマンドはBashなどのターミナルで、リポジトリのルートから実行すること。

`my_connection` は自分のCLI接続名に置き換えてください。

```bash
snow connection test -c my_connection
```

## 1. 初回の準備

初回は[セットアップガイド](setup.md)の手順1〜7を実行し、DB・ステージ・テーブル・プロシージャ・ログ設定を準備してください。完了したら、このページの「3. CSVをアップロード」へ進みます。

構築済みでCSVを更新する場合も、手順3から開始します。

## 2. ステージの作成

セットアップガイドで作成済みならスキップします。ステージだけを作成し直す必要がある場合に実行してください。

```bash
snow sql -c my_connection -f scripts/init_stage.sql
```

`CREATE OR REPLACE STAGE` を使用するため、既存のステージは再作成され、アップロード済みファイルも削除されます。実行後は、手順3でCSVを再アップロードしてください。ファイルフォーマットなどの設定も、このSQLの定義に置き換わります。

## 3. CSVをアップロード

```bash
# CRMの3ファイル
snow stage copy 'datasets/source_crm/*.csv' \
  '@DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_crm/' \
  -c my_connection --role SYSADMIN \
  --database DATA_WAREHOUSE --schema STAGING \
  --overwrite --no-auto-compress --refresh

# ERPの3ファイル
snow stage copy 'datasets/source_erp/*.csv' \
  '@DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/' \
  -c my_connection --role SYSADMIN \
  --database DATA_WAREHOUSE --schema STAGING \
  --overwrite --no-auto-compress --refresh
```

- `--overwrite`：同名ファイルを上書きします。
- `--no-auto-compress`：gzipへ自動圧縮せず、`.csv` のまま配置します。
- `--refresh`：ステージのディレクトリテーブルを更新します。
- `--database DATA_WAREHOUSE --schema STAGING`：同じ接続セッションのDB・スキーマを指定します。`--refresh` 時のカレントDB未設定エラーを避けるため、明示しています。別の `snow sql` コマンドで実行した `USE DATABASE` は引き継がれません。
- `'*.csv'` を含むパスは引用符で囲み、CLIにワイルドカードを渡します。

アップロード先の `datasets/source_crm/` と `datasets/source_erp/` は、既存の `proc_load_bronze.sql` が参照するパスに合わせています。

## 4. アップロード結果を確認

両方のアップロードが成功したことを確認してから、一覧を表示します。

```bash
snow sql -c my_connection --role SYSADMIN \
  -q 'LIST @DATA_WAREHOUSE.STAGING.STG_CSV_FILES;'
```

次の6ファイルが配置されていることを確認します（一覧ではステージ名が先頭に付きます）。

```text
datasets/source_crm/cust_info.csv
datasets/source_crm/prd_info.csv
datasets/source_crm/sales_details.csv
datasets/source_erp/CUST_AZ12.csv
datasets/source_erp/LOC_A101.csv
datasets/source_erp/PX_CAT_G1V2.csv
```

## 5. Bronzeへ取り込む

**既存の `LOAD_BRONZE()` は各Bronzeテーブルを `TRUNCATE` してからCSVをロードします。既存データを入れ替える処理です。**

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -q 'CALL DATA_WAREHOUSE.BRONZE.LOAD_BRONZE();'
```

プロシージャの戻り値が `SUCCESS` であることを確認してください。現在の実装は例外を捕捉して `ERROR: ...` を返すため、CLIの終了コードだけでは成功を判断できません。詳細ログの確認と、この後のSilver / Goldの処理は[セットアップガイド](setup.md)を参照してください。

CSVを更新したら、手順3〜5を繰り返します。アップロードは同名ファイルの上書きであり、ローカルで削除したファイルをステージから削除する同期処理ではありません。

## 参考

- [Snowflake CLI: snow stage copy](https://docs.snowflake.com/en/developer-guide/snowflake-cli/command-reference/stage-commands/copy)
- [SQL: PUT](https://docs.snowflake.com/en/sql-reference/sql/put)
