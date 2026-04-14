/*
================================================================================================
ワークスペース内のCSVを内部ステージへコピー
================================================================================================
コードの目的:
    本コードは、データロード用のファイルフォーマット 'CSV_FORMAT' を定義し、
    CSVファイルを管理するための内部ステージ 'STG_CSV_FILES' を作成する。
    その後、Snowflakeワークスペース上の指定されたディレクトリから、
    CRMおよびERP関連のソースCSVファイルをステージへコピー（ロード）する。

注意:
    本コードを実行すると、既存の 'CSV_FORMAT' および 'STG_CSV_FILES' は上書き（OR REPLACE）される。
    ステージを再作成する場合、ステージ内に未ロードのファイルが残っていても削除されるため注意すること。
    COPY FILESコマンドによりワークスペースの最新状態がステージへ反映されるが、
    ファイルパスやファイル名に変更がある場合は、FILES句のリストを更新する必要がある。
================================================================================================
*/

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

-- FIELD_OPTIONALLY_ENCLOSED_BY = '"' で
-- "value" のようにダブルクォートで囲まれた値を正しくパース（カンマを含む値などに対応）
CREATE OR REPLACE FILE FORMAT DATA_WAREHOUSE.STAGING.CSV_FORMAT
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1;

-- 内部ステージ作成。ディレクトリテーブルを有効化することで、snowsight上でステージ内の様子を確認できる
CREATE OR REPLACE STAGE DATA_WAREHOUSE.STAGING.STG_CSV_FILES
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal stage for loading CSV source files into Bronze layer';

-- ステージにworkspace内のcsvを投入
COPY FILES INTO @DATA_WAREHOUSE.STAGING.STG_CSV_FILES
FROM 'snow://workspace/USER$.PUBLIC."sql-data-warehouse-project"/versions/head'
FILES=(
    'datasets/source_crm/cust_info.csv',
    'datasets/source_crm/prd_info.csv',
    'datasets/source_crm/sales_details.csv',
    'datasets/source_erp/CUST_AZ12.csv',
    'datasets/source_erp/LOC_A101.csv',
    'datasets/source_erp/PX_CAT_G1V2.csv'
);