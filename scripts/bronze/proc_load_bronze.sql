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

CREATE OR REPLACE PROCEDURE DATA_WAREHOUSE.BRONZE.LOAD_BRONZE()
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    batch_start_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    start_time       TIMESTAMP_NTZ;
    end_time         TIMESTAMP_NTZ;
    log_message      STRING DEFAULT '';
BEGIN
    log_message := '================================================\n';
    log_message := log_message || 'Loading Bronze Layer\n';
    log_message := log_message || '================================================\n';

    log_message := log_message || '------------------------------------------------\n';
    log_message := log_message || 'Loading CRM Tables\n';
    log_message := log_message || '------------------------------------------------\n';

    -- crm_cust_info
    start_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Truncating Table: bronze.crm_cust_info\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.CRM_CUST_INFO;
    log_message := log_message || '>> Inserting Data Into: bronze.crm_cust_info\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.CRM_CUST_INFO
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_crm/cust_info.csv
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Load Duration: ' || DATEDIFF(SECOND, start_time, end_time) || ' seconds\n';
    log_message := log_message || '>> -------------\n';

    -- crm_prd_info
    start_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Truncating Table: bronze.crm_prd_info\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO;
    log_message := log_message || '>> Inserting Data Into: bronze.crm_prd_info\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_crm/prd_info.csv
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Load Duration: ' || DATEDIFF(SECOND, start_time, end_time) || ' seconds\n';
    log_message := log_message || '>> -------------\n';

    -- crm_sales_details
    start_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Truncating Table: bronze.crm_sales_details\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.CRM_SALES_DETAILS;
    log_message := log_message || '>> Inserting Data Into: bronze.crm_sales_details\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.CRM_SALES_DETAILS
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_crm/sales_details.csv
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Load Duration: ' || DATEDIFF(SECOND, start_time, end_time) || ' seconds\n';
    log_message := log_message || '>> -------------\n';

    log_message := log_message || '------------------------------------------------\n';
    log_message := log_message || 'Loading ERP Tables\n';
    log_message := log_message || '------------------------------------------------\n';

    -- erp_loc_a101
    start_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Truncating Table: bronze.erp_loc_a101\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_LOC_A101;
    log_message := log_message || '>> Inserting Data Into: bronze.erp_loc_a101\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_LOC_A101
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/LOC_A101.csv
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Load Duration: ' || DATEDIFF(SECOND, start_time, end_time) || ' seconds\n';
    log_message := log_message || '>> -------------\n';

    -- erp_cust_az12
    start_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Truncating Table: bronze.erp_cust_az12\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_CUST_AZ12;
    log_message := log_message || '>> Inserting Data Into: bronze.erp_cust_az12\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_CUST_AZ12
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/CUST_AZ12.csv
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Load Duration: ' || DATEDIFF(SECOND, start_time, end_time) || ' seconds\n';
    log_message := log_message || '>> -------------\n';

    -- erp_px_cat_g1v2
    start_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Truncating Table: bronze.erp_px_cat_g1v2\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2;
    log_message := log_message || '>> Inserting Data Into: bronze.erp_px_cat_g1v2\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/PX_CAT_G1V2.csv
    FILE_FORMAT = DATA_WAREHOUSE.STAGING.CSV_FORMAT;
    end_time := CURRENT_TIMESTAMP();
    log_message := log_message || '>> Load Duration: ' || DATEDIFF(SECOND, start_time, end_time) || ' seconds\n';
    log_message := log_message || '>> -------------\n';

    log_message := log_message || '==========================================\n';
    log_message := log_message || 'Loading Bronze Layer is Completed\n';
    log_message := log_message || '   - Total Load Duration: ' || DATEDIFF(SECOND, batch_start_time, CURRENT_TIMESTAMP()) || ' seconds\n';
    log_message := log_message || '==========================================';

    RETURN log_message;

EXCEPTION
    WHEN OTHER THEN
        log_message := log_message || '\n==========================================\n';
        log_message := log_message || 'ERROR OCCURRED DURING LOADING BRONZE LAYER\n';
        log_message := log_message || 'Error Message: ' || SQLERRM || '\n';
        log_message := log_message || 'Error Code: ' || SQLCODE || '\n';
        log_message := log_message || '==========================================';
        RETURN log_message;
END;