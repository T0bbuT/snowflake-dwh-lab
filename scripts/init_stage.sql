-- ===================================
-- ワークスペース内のcsvをステージにコピー
-- ===================================
use role sysadmin;
use warehouse compute_wh;
USE DATABASE DATA_WAREHOUSE;
USE SCHEMA STAGING;

-- FIELD_OPTIONALLY_ENCLOSED_BY = '"' で
-- "value" のようにダブルクォートで囲まれた値を正しくパース（カンマを含む値などに対応）
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1;

-- 内部ステージ作成。ディレクトリテーブルを有効化することで、snowsight上でステージ内の様子を確認できる
CREATE OR REPLACE STAGE STG_CSV_FILES
    FILE_FORMAT = CSV_FORMAT
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