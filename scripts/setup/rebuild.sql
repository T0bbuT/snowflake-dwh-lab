/*
================================================================================
初回構築・再構築: DB・スキーマ・ステージ・Bronze / Silverテーブルを作成
================================================================================
注意:
    既存のDATA_WAREHOUSEを置き換えるため、データ・アップロード済みCSV・
    Event Tableのログ・プロシージャ・Goldビューも含めて作り直しになる。
    通常のデータ更新やプロシージャ更新では実行しない。

実行方法:
    リポジトリのルートからSnowflake CLIで実行する。
    snow sql -c my_connection -f scripts/setup/rebuild.sql
    !sourceはCLIのコマンドであり、Snowsightではこのファイルを直接実行できない。

実行後:
    docs/setup.md に従い、ログ設定・プロシージャ定義・CSV投入・ロード・Gold作成を行う。
================================================================================
*/

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE OR REPLACE DATABASE DATA_WAREHOUSE;
USE DATABASE DATA_WAREHOUSE;

CREATE OR REPLACE SCHEMA STAGING;
CREATE OR REPLACE SCHEMA BRONZE;
CREATE OR REPLACE SCHEMA SILVER;
CREATE OR REPLACE SCHEMA GOLD;

-- CSV用の内部ステージ。ファイルフォーマットはステージ内に定義する。
-- ダブルクォートで囲まれたカンマを含む値に対応し、ヘッダーを読み飛ばす。
CREATE OR REPLACE STAGE DATA_WAREHOUSE.STAGING.STG_CSV_FILES
    FILE_FORMAT = (
        TYPE = 'CSV'
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        SKIP_HEADER = 1
    )
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal stage for loading CSV source files into Bronze layer';

-- テーブル定義は各レイヤのDDLを参照する（パスはリポジトリルート基準）。
!source scripts/bronze/ddl_bronze.sql
!source scripts/silver/ddl_silver.sql
