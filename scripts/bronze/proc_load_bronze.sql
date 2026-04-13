/*
==================================================================
ストアドプロシージャ作成: ブロンズ層のテーブルへのデータロード
==================================================================
目的:
    内部ステージにあるcsvからブロンズ層のテーブルへとロードする
    今回、ブロンズ層では毎回フルロードを行う設定なので、COPY INTOの前にTRUNCATEを挟んでいる
*/

use role sysadmin;
use warehouse compute_wh;
use database data_warehouse;
use schema bronze;

create or replace procedure data_warehouse.bronze.load_bronze()
returns string
language sql
as
declare
    batch_start_time    timestamp_ntz default current_timestamp(); 
    start_time          timestamp_ntz;
    end_time            timestamp_ntz;
    log_message         string default '';
begin
    log_message :=                '================================================\n';
    log_message := log_message || 'Loading Bronze Layer\n';
    log_message := log_message || '================================================\n';

    -- CRM Tables
    log_message := log_message || '------------------------------------------------\n';
    log_message := log_message || 'Loading CRM Tables\n';
    log_message := log_message || '------------------------------------------------\n';
    
    -- CRM_CUST_INFO
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.CRM_CUST_INFO\n';
    truncate table DATA_WAREHOUSE.BRONZE.CRM_CUST_INFO;
    log_message := log_message || '>> Inserting Data into Table: BRONZE.CRM_CUST_INFO\n';
    copy into DATA_WAREHOUSE.BRONZE.CRM_CUST_INFO
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/cust_info.csv
    file_format = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- CRM_PRD_INFO
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.CRM_PRD_INFO\n';
    truncate table DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO;
    log_message := log_message || '>> Inserting Data into Table: BRONZE.CRM_PRD_INFO\n';
    copy into DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/prd_info.csv
    file_format = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- CRM_SALES_DETAILS
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.CRM_SALES_DETAILS\n';
    truncate table DATA_WAREHOUSE.BRONZE.CRM_SALES_DETAILS;    
    log_message := log_message || '>> Inserting Data into Table: BRONZE.CRM_SALES_DETAILS\n';
    copy into DATA_WAREHOUSE.BRONZE.CRM_SALES_DETAILS
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/sales_details.csv
    file_format = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- ERP Tables
    log_message := log_message || '------------------------------------------------\n';
    log_message := log_message || 'Loading ERP Tables\n';
    log_message := log_message || '------------------------------------------------\n';

    -- ERP_CUST_AZ12
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.ERP_CUST_AZ12\n';
    truncate table DATA_WAREHOUSE.BRONZE.ERP_CUST_AZ12;
    log_message := log_message || '>> Inserting Data into Table: BRONZE.ERP_CUST_AZ12\n';
    copy into DATA_WAREHOUSE.BRONZE.ERP_CUST_AZ12
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_erp/CUST_AZ12.csv
    file_format = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- erp_loc_a101
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.ERP_LOC_A101\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_LOC_A101;
    log_message := log_message || '>> Inserting Data into Table: BRONZE.ERP_LOC_A101\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_LOC_A101
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/LOC_A101.csv
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- erp_px_cat_g1v2
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.ERP_PX_CAT_G1V2\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2;
    log_message := log_message || '>> Inserting Data into Table: BRONZE.ERP_PX_CAT_G1V2\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/PX_CAT_G1V2.csv
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := current_timestamp();
    log_message := log_message || '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    RETURN log_message;

-- 例外処理
exception
when other then
    log_message := log_message || '\n==========================================\n';
    log_message := log_message || 'ERROR OCCURRED DURING LOADING BRONZE LAYER\n';
    log_message := log_message || 'Error Message: ' || SQLERRM || '\n';
    log_message := log_message || 'Error Code: ' || SQLCODE || '\n';
    log_message := log_message || '==========================================';

    RETURN log_message;
end;