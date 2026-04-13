/*
========================================
ブロンズ層のtable作成
========================================
目的:
    内部ステージからのデータロードの受け皿となる、ブロンズ層のテーブルを作成する
*/


-- コンテキスト設定
use role sysadmin;
use warehouse compute_wh;
use database data_warehouse;
use schema bronze;

-- 命名規則: <sourcesystem>_<entity>

create or replace table crm_cust_info (
    cst_id int,
    cst_key varchar(50),
    cst_firstname varchar(50),
    cst_lastname varchar(50),
    cst_marital_status varchar(50),
    cst_gndr varchar(50),
    cst_create_date date
);

-- todo: 
-- 教材ではprd_start_dt, prd_end_dtの型をdatetimeにしていた
-- 理由不明。必要ないことが分かればdate型に直す
create or replace table crm_prd_info (
    prd_id int,
    prd_key varchar(50),
    prd_nm varchar(50),
    prd_cost int,
    prd_line varchar(50),
    prd_start_dt datetime, 
    prd_end_dt datetime
);

create or replace table crm_sales_details (
    sls_ord_num varchar(50),
    sls_prd_key varchar(50),
    sls_cust_id int,
    sls_order_dt int,
    sls_ship_dt int,
    sls_due_dt int,
    sls_sales int,
    sls_quantity int,
    sls_price int
);

create or replace table erp_CUST_AZ12 (
    CID varchar(50),
    BDATE date,
    GEN  varchar(50)
);

create or replace table erp_LOC_A101 (
    CID varchar(50),
    CNTRY varchar(50)
);

create or replace table erp_PX_CAT_G1V2 (
    ID varchar(50),
    CAT varchar(50),
    SUBCAT varchar(50),
    MAINTENANCE varchar(50)
);