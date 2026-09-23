# アーキテクチャ決定記録（ADR）

このディレクトリには、本プロジェクトの設計判断をArchitecture Decision Record（ADR）として記録します。

本プロジェクトは、Baraa Khatib Salkini氏の[SQL Data Warehouse Project](https://github.com/DataWithBaraa/sql-data-warehouse-project)を出発点としています。そのため、各ADRには判断の由来を記載し、元プロジェクトから引き継いだ設計と、本プロジェクトで変更・追加した設計を区別します。

## 由来の分類

| 分類 | 意味 |
| --- | --- |
| 継承 | 元プロジェクトの設計を、そのまま本プロジェクトでも採用した判断 |
| 適応 | 元プロジェクトの設計を基に、Snowflakeの仕様や本プロジェクトの運用に合わせて選び直した判断 |
| 固有 | 元プロジェクトにはなく、本プロジェクトで追加または変更した判断 |

由来は判断の新規性を示すための補足であり、ADRのステータスとは別に扱います。

## ADR一覧

| ADR | ステータス | 由来 | 概要 |
| --- | --- | --- | --- |
| [0001: DWH基盤としてSnowflakeを使用する](0001-use-snowflake-as-dwh-platform.md) | 採用 | 固有 | SQL Server向けの元実装をSnowflake向けに再設計する |
| [0002: Silverの全件置換にTRUNCATEとINSERTを使用する](0002-use-truncate-and-insert-for-silver-refresh.md) | 採用 | 適応 | 挿入件数を正しく記録するため、置換処理を2文に分ける |
| [0003: Goldビューのキーに決定的ハッシュを使用する](0003-use-deterministic-hash-keys-in-gold-views.md) | 採用 | 固有 | ビューの評価ごとに変わりにくいキーを自然キーから生成する |
| [0004: ロードログをEvent Tableへ記録する](0004-use-event-table-for-load-logging.md) | 採用 | 固有 | Snowflake標準のログ機構で実行履歴とエラーを参照可能にする |
| [0005: 必須CSVをロード開始前に検証する](0005-validate-required-files-before-loading.md) | 採用 | 固有 | ファイル不足時は既存Bronzeデータを変更せず終了する |

## 運用ルール

- 採用済みの判断を変更する場合は、既存ADRを削除せず、ステータスを`置換済み`にして後継ADRへリンクします。
- 過去の判断を後から記録した場合は、決定日と記録日を分け、`事後記録: Yes`と記載します。
- 当時検討したことを確認できない選択肢は、実際に比較した案であるかのように記載しません。
- 実装、検証記録、関連コミットを可能な範囲で根拠としてリンクします。
