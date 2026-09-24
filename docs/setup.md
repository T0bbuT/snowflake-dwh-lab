# セットアップとデータ更新の実行順序

このページを入口として、接続準備からGoldの品質確認まで順番に進めます。初回構築・全体の作り直しは下記の順序表を上から実行します。構築済み環境のCSV更新は「データ更新時」、SQLや設定の更新は「定義を変更したときの再実行範囲」へ進んでください。

CSV不足チェック・通常ロード・再ロードの結果は[2026-09-21の実機検証記録](validation-2026-09-21.md)、以前の構築結果は[2026-09-13の実機検証記録](validation-2026-09-13.md)を参照してください。最新の検証は専用DBで実施し、既存DBの置き換えとアカウント全体のログ出力先変更は対象外です。実行方法の差分は検証記録に記載しています。

## 前提と接続準備

- Snowflake CLI（`snow`）をインストールし、[キーペア認証ガイド](setup-keypair-auth.md)に従って接続を設定します。`mise` を使用する場合は、リポジトリのルートで `mise install` を実行すると、`mise.toml` で指定した Snowflake CLI 3.26.0 が入ります。
- `COMPUTE_WH` が存在し、接続ユーザーが利用できることを確認します。このリポジトリにはウェアハウス作成SQLはありません。
- 通常の構築・ロード、Event Tableの作成・ログ確認には `SYSADMIN` を使用します。`logging/configure_event_target.sql` だけがアカウントのログ出力先設定に `ACCOUNTADMIN` を使用し、最後に `SYSADMIN` に戻ります。
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
| 2 | [logging/ensure_event_table.sql](../scripts/logging/ensure_event_table.sql) | ログ保存先を作成。既に存在する場合はログを保持 |
| 3 | [logging/configure_event_target.sql](../scripts/logging/configure_event_target.sql) | アカウントのログ出力先を設定 |
| 4 | [proc_load_bronze.sql](../scripts/bronze/proc_load_bronze.sql) | `LOAD_BRONZE()` を定義（まだロードしない） |
| 5 | [proc_load_silver.sql](../scripts/silver/proc_load_silver.sql) | `LOAD_SILVER()` を定義（まだロードしない） |
| 6 | [logging/configure_logging.sql](../scripts/logging/configure_logging.sql) | 両プロシージャのログレベルをINFOに設定 |
| 7 | [CSVをステージへアップロードする](#7-csvをステージへアップロードする) | CRM・ERPのCSVをローカルからアップロード |
| 8 | [アップロード結果を確認する](#8-アップロード結果を確認する) | ステージ内に必要な6ファイルがすべてあることを確認 |
| 9 | [Bronzeへロードする](#9-bronzeへロードする) | CSV → Bronze。戻り値が `SUCCESS` であることを確認 |
| 10 | [Silverへロードする](#10-silverへロードする) | Bronze → Silver。戻り値が `SUCCESS` であることを確認 |
| 11 | [Silverの品質を確認する](#11-silverの品質を確認する) | Silverの品質チェックを実行 |
| 12 | [Goldを作成する](#12-goldを作成する) | 顧客・商品・売上の3ビューを作成 |
| 13 | [Goldの品質を確認する](#13-goldの品質を確認する) | Goldのキー重複・参照整合性を確認 |

手順6は両プロシージャへの `ALTER PROCEDURE` を含むため、必ず手順4〜5の後に実行します。ログ保存先・出力先・ログレベルは、ロードを呼び出す前に設定します。手順3はアカウント全体のEvent Table設定を変更するため、既存のログ出力先がある環境ではその設定を確認してください。

### 1〜6. オブジェクトとログ設定を準備する

以下は順序表に対応するコマンドです。リポジトリのルートから実行し、各コマンドの成功を確認してから次へ進みます。

```bash
snow sql -c my_connection -f scripts/setup/rebuild.sql
snow sql -c my_connection -f scripts/logging/ensure_event_table.sql
snow sql -c my_connection -f scripts/logging/configure_event_target.sql
snow sql -c my_connection -f scripts/bronze/proc_load_bronze.sql
snow sql -c my_connection -f scripts/silver/proc_load_silver.sql
snow sql -c my_connection -f scripts/logging/configure_logging.sql
```

`rebuild.sql` はSnowflake CLIの `!source` で既存のBronze / SilverのDDLを読み込みます。参照パスはリポジトリルート基準です。CLI専用のコマンドを含むため、Snowsightでこのファイルを直接実行することはできません。[Snowflake CLIのファイル読み込み仕様](https://docs.snowflake.com/en/developer-guide/snowflake-cli/sql/execute-sql#execute-sql-in-local-files-or-urls)

### 7. CSVをステージへアップロードする

手順1〜6では、CSVのアップロードはまだ行っていません。ローカルの `datasets/` にあるCRM・ERPの計6ファイルを、内部ステージへアップロードします。以下の2コマンドをリポジトリのルートから順に実行してください。

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

両方のコマンドが正常に完了したら、手順8で配置されたファイルを確認します。オプションの意味は[CSVアップロードの補足](load-local-csv.md#アップロードオプションの意味)を参照してください。

### 8. アップロード結果を確認する

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

**上記6ファイルがすべて確認できたら、手順9のBronzeロードへ進みます。** 不足やパスの違いがあれば、手順7のアップロード先を確認して再実行してください。前回のCSVが残っている場合は一覧だけで更新完了を判断できないため、今回のアップロード結果も確認します。

### 9. Bronzeへロードする

ステージ上のCSVをBronzeテーブルへ取り込みます。ここからは既存データを全件入れ替える処理です。

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -q 'CALL DATA_WAREHOUSE.BRONZE.LOAD_BRONZE();'
```

戻り値が `SUCCESS` であることを確認してから、手順10へ進みます。両ロードプロシージャは失敗時に `ERROR: ...` を返すため、CLIの終了コードだけでは成功を判断できません。

Bronzeは最初の `TRUNCATE` より前にステージの一覧を更新し、必要な6ファイルを確認します。`ERROR: Missing required CSV files: ...` の場合は全Bronzeテーブルを変更せず終了します。表示された不足ファイルを[手順7](#7-csvをステージへアップロードする)でアップロードし、[手順8](#8-アップロード結果を確認する)で確認してから再実行してください。

その他のエラーでは、ロードが始まり一部だけ更新されている可能性があります。Silverへ進まず、[ログを確認](#ログを確認する)してください。ファイルの存在チェックでは、CSVの更新漏れや内容の正しさは判断しません。

### 10. Silverへロードする

Bronzeの戻り値が `SUCCESS` であることを確認したら、クレンジング・標準化してSilverへ取り込みます。

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -q 'CALL DATA_WAREHOUSE.SILVER.LOAD_SILVER();'
```

戻り値が `SUCCESS` であることを確認してから、手順11へ進みます。`ERROR: ...` の場合は後続の処理へ進まず、[ログを確認](#ログを確認する)してください。Silverも全件入れ替えのため、失敗時は一部だけ更新されている可能性があります。

### 11. Silverの品質を確認する

Silverが `SUCCESS` になったら品質を確認します。

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  --database DATA_WAREHOUSE -f tests/quality_checks_silver.sql
```

「期待: 結果なし」のクエリは0件であることを確認します。`SELECT DISTINCT` など値の分布を確認するクエリは、表示された値が想定どおりかを確認します。問題があれば調査してからGoldへ進みます。

生年月日のチェックは実行日から120年前より古い日付を確認対象として抽出します（120年前の同日は対象外）。120歳は調査の目安であり、不正値と断定する基準ではありません。100歳前後を含め、古い日付は元の値を保持します。未来の日付は変換処理でNULLにするため、Silverで検出された場合は処理を調査してください。

### 12. Goldを作成する

Silverの品質確認が済んだら、分析用の3ビューを作成します。

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -f scripts/gold/ddl_gold.sql
```

### 13. Goldの品質を確認する

ビュー作成が成功したら、キー重複・参照整合性を確認します。

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -f tests/quality_checks_gold.sql
```

Goldの品質チェックは各クエリが0件であることを確認します。Goldはビューなので、別途ロード用のプロシージャを呼ぶ必要はありません。

## ログを確認する

```bash
snow sql -c my_connection --role SYSADMIN --warehouse COMPUTE_WH \
  -f scripts/logging/query_load_logs.sql
```

[query_load_logs.sql](../scripts/logging/query_load_logs.sql)はBronze / Silverの最新100件ずつとエラーログの最新50件を、それぞれ古い順に表示します。Event Tableへの反映には数分のラグがある場合があります。Event Tableは `SYSADMIN` で作成し、同じロールで参照します。

## データ更新時

構築済みなら、次の順序で実行します。

1. このページの[手順7](#7-csvをステージへアップロードする)でCSVを上書きアップロードし、[手順8](#8-アップロード結果を確認する)で6ファイルを確認する。
2. `LOAD_BRONZE()` を呼び、`SUCCESS` を確認する。
3. `LOAD_SILVER()` を呼び、`SUCCESS` を確認する。
4. Silver / Goldの品質チェックを実行し、必要に応じてログを確認する。

コマンドは上の手順7〜13を参照してください。Goldのビュー定義を変更していなければ、手順12のDDL実行は不要です。

## 定義を変更したときの再実行範囲

通常の設定・定義更新では `setup/rebuild.sql` を実行しません。

| 変更・状況 | 実行するもの |
| --- | --- |
| Bronze / Silverのプロシージャだけ変更 | 該当する `proc_load_*.sql` → `logging/configure_logging.sql` → 対象レイヤから下流のロード・品質確認 |
| ログレベルだけ変更 | `logging/configure_logging.sql` の値を変更して実行 |
| Goldのビュー定義だけ変更 | `ddl_gold.sql` → Gold品質チェック |
| ログ出力先を設定し直す | 保存先が存在することを確認 → `logging/configure_event_target.sql` |
| Bronze / Silverのテーブルを再作成 | 対象の `ddl_*.sql` → 対象レイヤから下流のロード・品質確認。列定義を変えた場合は関連プロシージャ・ビューも整合させる |
| DB全体を作り直す | 初回構築・再構築の手順1〜13をすべて実行 |

プロシージャ更新の例（Bronzeを変更した場合）:

```bash
snow sql -c my_connection -f scripts/bronze/proc_load_bronze.sql
snow sql -c my_connection -f scripts/logging/configure_logging.sql
```

両プロシージャが存在する構築済み環境で実行します。その後、Bronze → Silverのロード、Silver / Goldの品質確認、ログ確認を行います。全件入れ替えの変更では再ロードも確認してください。

`logging/ensure_event_table.sql` はログ保存先がなければ作成し、既存ログを保持します。`logging/configure_logging.sql` も再実行時にログや業務データを削除しません。通常のCSV更新には、どちらも再実行不要です。
