# ADR-0001: DWH基盤としてSnowflakeを使用する

- ステータス: 採用
- 由来: 固有
- 決定日: 2026-04-09
- 記録日: 2026-09-23
- 事後記録: Yes

## 背景・課題

参照元のプロジェクトは、SQL ServerとSQL Server Management Studioを使用して、ERP・CRMのCSVからDWHを構築している。本プロジェクトでは、参照元のデータモデルと変換内容を活用しながら、クラウドDWHであるSnowflakeのオブジェクト、データロード、SQL実行、ログ管理を扱うことを目的とした。

SQL Server向けのT-SQLをそのまま実行することはできず、CSVの取り込み、ストアドプロシージャ、日付・文字列関数、ログ出力などをSnowflake向けに設計し直す必要がある。

## 決定事項

DWH基盤としてSnowflakeを使用し、SQLはSnowflake SQLで実装する。

参照元の論理的なデータフローを出発点とするが、次の機能はSnowflakeの仕組みに置き換える。

- SQL Serverの`BULK INSERT`は、内部ステージと`COPY INTO`へ置き換える。
- T-SQLのストアドプロシージャは、Snowflake ScriptingによるSQLストアドプロシージャへ置き換える。
- SQL Server固有の関数と構文は、Snowflakeで同等の意味になるよう変更する。

## 影響

- Snowflakeのステージ、スキーマ、ロール、ウェアハウス、ストアドプロシージャを一つのプロジェクトで扱える。
- 参照元との差分が生じるため、構文を置換するだけでなく、Snowflake上で実際の挙動を検証する必要がある。
- 実行にはSnowflakeアカウントと利用可能なウェアハウスが必要になる。
- Snowflakeの権限やアカウント設定を扱う処理には、既存環境への影響を避けるための運用上の注意が必要になる。

## 見直し条件

- Snowflake以外のDWH製品を対象に含める場合
- SQLを特定のDWHに依存しない変換フレームワークへ移行する場合

## 根拠・関連資料

- [README](../../README.md)
- [セットアップ手順](../setup.md)
- 関連コミット: `b140cb3`（DB・スキーマ作成処理をSnowflake向けに変更）
- 参照元: [DataWithBaraa/sql-data-warehouse-project](https://github.com/DataWithBaraa/sql-data-warehouse-project)
