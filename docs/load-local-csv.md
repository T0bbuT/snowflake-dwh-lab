# CSVアップロードの補足

アップロード・配置確認・Bronze / Silverのロードまでの実行コマンドは、[セットアップガイドの手順7以降](setup.md#7-csvをステージへアップロードする)にまとめています。このページでは、アップロードオプションとファイル不足時の対応を説明します。

## 取り込みの流れ

```text
datasets/ → snow stage copy（内部でPUT）→ STG_CSV_FILES → LOAD_BRONZE() → Bronzeテーブル
```

CSVはローカルから内部ステージへアップロードします。SnowsightのワークスペースへのCSV配置は不要です。ステージは初回構築時に作成するため、CSV更新のたびに作り直す必要はありません。

## アップロードオプションの意味

- `--overwrite`：同名ファイルを上書きします。
- `--no-auto-compress`：gzipへ自動圧縮せず、`.csv` のまま配置します。
- `--refresh`：ステージのディレクトリテーブルを更新します。
- `--database DATA_WAREHOUSE --schema STAGING`：同じ接続セッションのDB・スキーマを指定します。`--refresh` 時のカレントDB未設定エラーを避けるため、明示しています。別の `snow sql` コマンドで実行した `USE DATABASE` は引き継がれません。
- `'*.csv'` を含むパスは引用符で囲み、CLIにワイルドカードを渡します。

アップロード先の `datasets/source_crm/` と `datasets/source_erp/` は、既存の `proc_load_bronze.sql` が参照するパスに合わせています。

アップロードは同名ファイルの上書きであり、ローカルで削除したファイルをステージから削除する同期処理ではありません。

## ファイル不足時の対応

`LOAD_BRONZE()` が `ERROR: Missing required CSV files: ...` を返した場合は、表示されたファイルを[手順7の配置先](setup.md#7-csvをステージへアップロードする)へアップロードし、[手順8の一覧](setup.md#8-アップロード結果を確認する)を確認してから再実行してください。

不足チェックは最初の `TRUNCATE` より前に全6ファイルを対象に行うため、このエラーではBronzeの既存データは変更されません。不足ファイルと再実行の案内はEvent Tableにも記録されます。

プロシージャ内で `ALTER STAGE ... REFRESH` を実行し、ディレクトリテーブルの一覧を更新してから相対パスを完全一致で照合します。各 `COPY INTO` も `FILES` で対象を明示します。前回のCSVが残っている場合の更新漏れ、空ファイル・内容の不備、確認後のファイル変更は事前の存在チェックでは検出できません。PUTの完了を確認し、ロード中はステージのファイルを変更しないでください。ロード開始後のエラーでは、一部のテーブルが更新済みの場合があります。

不足時のデータ保持と通常・再ロードの結果は[実機検証記録](validation-2026-09-21.md)を参照してください。

## 参考

- [Snowflake CLI: snow stage copy](https://docs.snowflake.com/en/developer-guide/snowflake-cli/command-reference/stage-commands/copy)
- [SQL: PUT](https://docs.snowflake.com/en/sql-reference/sql/put)
