# ADR-0002: Silverの全件置換にTRUNCATEとINSERTを使用する

- ステータス: 採用
- 由来: 適応
- 決定日: 2026-04-30
- 記録日: 2026-09-23
- 事後記録: Yes

## 背景・課題

Silverは全件入れ替え方式であり、Snowflakeでは`INSERT OVERWRITE`によって置換を一文で表現できる。本プロジェクトでも一度`INSERT OVERWRITE`を採用したが、直後に取得する`SQLROWCOUNT`が挿入行数として期待した値にならず、ロード件数のログが不正確になった。

参照元のプロジェクトは`TRUNCATE TABLE`と`INSERT INTO`を使用しているが、本プロジェクトではSnowflake固有の候補を試したうえで、処理件数の観測可能性を優先して方式を選び直した。

## 決定事項

Silverの各テーブルは、`TRUNCATE TABLE`を実行した後、別の文として`INSERT INTO ... SELECT ...`を実行する。挿入直後の`SQLROWCOUNT`を、そのテーブルのロード件数として記録する。

## 検討した選択肢

### INSERT OVERWRITE

置換を一文で表現できるが、本プロジェクトで必要とする挿入件数を`SQLROWCOUNT`から正しく取得できなかったため採用しない。

## 影響

- ログに記録する挿入件数の意味が明確になる。
- 置換が二つのSQL文に分かれ、`TRUNCATE`後に`INSERT`が失敗すると対象テーブルが空または不完全な状態になる可能性がある。
- 一文での置換よりSQLの記述量が増える。
- 将来、件数取得方法またはトランザクション設計を変更した場合は、`INSERT OVERWRITE`を再評価できる。

## 見直し条件

- Snowflakeの`SQLROWCOUNT`の挙動または利用するロード方式が変わった場合
- 全件置換を原子的に行うことが要件になった場合
- ロード件数を別の監査テーブルやクエリ履歴から取得する場合

## 根拠・関連資料

- [Silverロードプロシージャ](../../scripts/silver/proc_load_silver.sql)
- 関連コミット: `6459dd7`（`INSERT OVERWRITE`を導入）
- 関連コミット: `0917d3a`（件数取得の問題により`TRUNCATE + INSERT`へ変更）
- 参照元: [Silverロード](https://github.com/DataWithBaraa/sql-data-warehouse-project/blob/main/scripts/silver/proc_load_silver.sql)
