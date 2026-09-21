# セットアップとデータ更新の実行順序

このページを入口として、接続準備からGoldの品質確認まで順番に進めます。初回構築・全体の作り直しは下記の順序表を上から実行します。構築済み環境のCSV更新は「データ更新時」、SQLや設定の更新は「定義を変更したときの再実行範囲」へ進んでください。

実行結果と確認事項は[2026-09-13の実機検証記録](validation-2026-09-13.md)を参照してください。現在のファイル分割・実行順序は、この実機検証後の変更です。

## 前提と接続準備

- Snowflake CLI（`snow`）をインストールし、[キーペア認証ガイド](setup-keypair-auth.md)に従って接続を設定します。
- `COMPUTE_WH` が存在し、接続ユーザーが利用できることを確認します。このリポジトリにはウェアハウス作成SQLはありません。
- 通常の構築・ロード、Event Tableの作成・ログ確認には `SYSADMIN` を使用します。`setup/configure_event_target.sql` だけがアカウントのログ出力先設定に `ACCOUNTADMIN` を使用し、最後に `SYSADMIN` に戻ります。
- コマンドはリポジトリのルートで実行し、`my_connection` を自分の接続名に置き換えます。各SQLに固定されたロール・ウェアハウスを変更する場合は、SQL内の `USE` 文も合わせてください。

```bash
snow connection test -c my_connection
```

SnowsightでGit上のSQLを編集・実行したい場合は、[Git Workspaceガイド](setup-git-workspace.md)も参照してください。Git連携は任意です。ローカルCSVのアップロードはターミナルから行います。

## 初回構築・再構築の順序

**`setup/rebuild.sql` は既存DBを置き換えます。データ・アップロード済みCSV・過去のログ・プロシージャ・Goldビューも作り直しになります。通常の更新では実行しないでください。**

| 順序 | 実行するもの | 目的・完了の目安 |
| --- | --- | --- |
| 1 | [setup/rebuild.sql](../scripts/setup/rebuild.sql) | DB・4スキーマ・CSVステージ・Bronze / Silver各6テーブルを再作成 |
| 2 | [setup/ensure_event_table.sql](../scripts/setup/ensure_event_table.sql) | ログ保存先を作成。既に存在する場合はログを保持 |
| 3 | [setup/configure_event_target.sql](../scripts/setup/configure_event_target.sql) | アカウントのログ出力先を設定 |
| 4 | [proc_load_bronze.sql](../scripts/bronze/proc_load_bronze.sql) | `LOAD_BRONZE()` を定義（まだロードしない） |
| 5 | [proc_load_silver.sql](../scripts/silver/proc_load_silver.sql) | `LOAD_SILVER()` を定義（まだロードしない） |
| 6 | [configure_logging.sql](../scripts/configure_logging.sql) | 両プロシージャのログレベルをINFOに設定 |
| 7 | [CSVガイドの手順3〜4](load-local-csv.md#3-csvをアップロード) | CSVをアップロードし、ステージ内の6ファイルを確認 |
| 8 | `CALL DATA_WAREHOUSE.BRONZE.LOAD_BRONZE();` | CSV → Bronze。戻り値が `SUCCESS` であることを確認 |
| 9 | `CALL DATA_WAREHOUSE.SILVER.LOAD_SILVER();` | Bronze → Silver。戻り値が `SUCCESS` であることを確認 |
| 10 | [quality_checks_silver.sql](../tests/quality_checks_silver.sql) | Silverの品質を確認 |
| 11 | [ddl_gold.sql](../scripts/gold/ddl_gold.sql) | 顧客・商品・売上の3ビューを作成 |
| 12 | [quality_checks_gold.sql](../tests/quality_checks_gold.sql) | Goldのキー重複・参照整合性を確認 |

手順6は両プロシージャへの `ALTER PROCEDURE` を含むため、必ず手順4〜5の後に実行します。ログ保存先・出力先・ログレベルは、ロードを呼び出す前に設定します。手順3はアカウント全体のEvent Table設定を変更するため、既存のログ出力先がある環境ではその設定を確認してください。

### 1〜6. オブジェクトとログ設定を準備する

以下は順序表に対応するコマンドです。リポジトリのルートから実行し、各コマンドの成功を確認してから次へ進みます。

```bash
snow sql -c my_connection -f scripts/setup/rebuild.sql
snow sql -c my_connection -f scripts/setup/ensure_event_table.sql
snow sql -c my_connection -f scripts/setup/configure_event_target.sql
snow sql -c my_connection -f scripts/bronze/proc_load_bronze.sql
snow sql -c my_connection -f scripts/silver/proc_load_silver.sql
snow sql -c my_connection -f scripts/configure_logging.sql
```

`rebuild.sql` はSnowflake CLIの `!source` で既存のBronze / SilverのDDLを読み込みます。参照パスはリポジトリルート基準です。CLI専用のコマンドを含むため、Snowsightでこのファイルを直接実行することはできません。[Snowflake CLIのファイル読み込み仕様](https://docs.snowflake.com/en/developer-guide/snowflake-cli/sql/execute-sql#execute-sql-in-local-files-or-urls)

### 7〜10. CSVをロードし、Silverを確認する

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

生年月日のチェックは実行日から120年前より古い日付を確認対象として抽出します（120年前の同日は対象外）。120歳は調査の目安であり、不正値と断定する基準ではありません。100歳前後を含め、古い日付は元の値を保持します。未来の日付は変換処理でNULLにするため、Silverで検出された場合は処理を調査してください。

### 11〜12. Goldを作成して確認する

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -f scripts/gold/ddl_gold.sql
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -f tests/quality_checks_gold.sql
```

Goldの品質チェックは各クエリが0件であることを確認します。Goldはビューなので、別途ロード用のプロシージャを呼ぶ必要はありません。

## ログを確認する

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -f scripts/query_load_logs.sql
```

[query_load_logs.sql](../scripts/query_load_logs.sql)はBronze / Silverの最新100件ずつとエラーログの最新50件を、それぞれ古い順に表示します。Event Tableへの反映には数分のラグがある場合があります。Event Tableは `SYSADMIN` で作成し、同じロールで参照します。

## データ更新時

構築済みなら、次の順序で実行します。

1. [CSVガイドの手順3〜4](load-local-csv.md#3-csvをアップロード)でCSVを上書きアップロードし、ファイルを確認する。
2. `LOAD_BRONZE()` を呼び、`SUCCESS` を確認する。
3. `LOAD_SILVER()` を呼び、`SUCCESS` を確認する。
4. Silver / Goldの品質チェックを実行し、必要に応じてログを確認する。

コマンドは上の手順7〜12を参照してください。Goldのビュー定義を変更していなければ、手順11のDDL実行は不要です。

## 定義を変更したときの再実行範囲

通常の設定・定義更新では `setup/rebuild.sql` を実行しません。

| 変更・状況 | 実行するもの |
| --- | --- |
| Bronze / Silverのプロシージャだけ変更 | 該当する `proc_load_*.sql` → `configure_logging.sql` → 対象レイヤから下流のロード・品質確認 |
| ログレベルだけ変更 | `configure_logging.sql` の値を変更して実行 |
| Goldのビュー定義だけ変更 | `ddl_gold.sql` → Gold品質チェック |
| ログ出力先を設定し直す | 保存先が存在することを確認 → `setup/configure_event_target.sql` |
| Bronze / Silverのテーブルを再作成 | 対象の `ddl_*.sql` → 対象レイヤから下流のロード・品質確認。列定義を変えた場合は関連プロシージャ・ビューも整合させる |
| DB全体を作り直す | 初回構築・再構築の手順1〜12をすべて実行 |

プロシージャ更新の例（Bronzeを変更した場合）:

```bash
snow sql -c my_connection -f scripts/bronze/proc_load_bronze.sql
snow sql -c my_connection -f scripts/configure_logging.sql
```

両プロシージャが存在する構築済み環境で実行します。その後、Bronze → Silverのロード、Silver / Goldの品質確認、ログ確認を行います。全件入れ替えの変更では再ロードも確認してください。

`setup/ensure_event_table.sql` はログ保存先がなければ作成し、既存ログを保持します。`configure_logging.sql` も再実行時にログや業務データを削除しません。通常のCSV更新には、どちらも再実行不要です。
