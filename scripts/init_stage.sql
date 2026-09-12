/*
================================================================================================
ワークスペース内のCSVを内部ステージへコピー
================================================================================================
コードの目的:
    本コードは、データロード用のファイルフォーマットを設定した
    内部ステージ 'STG_CSV_FILES' を作成する。
    その後、Snowflakeワークスペース上の指定されたディレクトリから、
    CRMおよびERP関連のソースCSVファイルをステージへコピー（ロード）する。

注意:
    本コードを実行すると、既存の 'STG_CSV_FILES' は上書き（OR REPLACE）される。
    ステージを再作成する場合、ステージ内に未ロードのファイルが残っていても削除されるため注意すること。
    COPY FILESコマンドによりワークスペースの最新状態がステージへ反映されるが、
    ファイルパスやファイル名に変更がある場合は、FILES句のリストを更新する必要がある。
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

-- ステージにworkspace内のcsvを投入
-- TODO: workspace内から投入するの、あまり気に入らない。snowflake cli使っているのだから、ローカルからPUTするほうが良いだろう
COPY FILES INTO @DATA_WAREHOUSE.STAGING.STG_CSV_FILES
FROM 'snow://workspace/USER$.PUBLIC."snowflake-dwh-lab"/versions/head'
FILES=(
    'datasets/source_crm/cust_info.csv',
    'datasets/source_crm/prd_info.csv',
    'datasets/source_crm/sales_details.csv',
    'datasets/source_erp/CUST_AZ12.csv',
    'datasets/source_erp/LOC_A101.csv',
    'datasets/source_erp/PX_CAT_G1V2.csv'
);