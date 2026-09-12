/*
================================================================================================
ローカルCSVのアップロード先となる内部ステージを作成
================================================================================================
コードの目的:
    本コードは、データロード用のファイルフォーマットを設定した
    内部ステージ 'STG_CSV_FILES' を作成する。
    CSVのアップロードは、ローカルのターミナルからSnowflake CLIで行う。
    手順: docs/load-local-csv.md

注意:
    CREATE OR REPLACEにより、既存のステージを再作成する。
    アップロード済みファイルも削除されるため、実行後はCSVを再アップロードすること。
================================================================================================
*/

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

-- 内部ステージ作成。ファイルフォーマットはステージ内に定義する
-- FIELD_OPTIONALLY_ENCLOSED_BY = '"' でカンマを含むダブルクォート内の値などを正しくパースする
-- ディレクトリテーブルを有効化することで、Snowsight上でステージ内の様子を確認できる
CREATE OR REPLACE STAGE DATA_WAREHOUSE.STAGING.STG_CSV_FILES
    FILE_FORMAT = (
        TYPE = 'CSV'
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        SKIP_HEADER = 1
    )
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal stage for loading CSV source files into Bronze layer';
