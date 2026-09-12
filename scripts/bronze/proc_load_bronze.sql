/*
================================================================================
ストアドプロシージャ: ブロンズ層へのデータロード(ソース -> ブロンズ)
================================================================================
目的:
    本ストアドプロシージャは、STAGINGスキーマ内にある内部ステージ(STG_CSV_FILES)から、
    ブロンズ層のテーブルへとcsvをロードする
    
    以下の処理を実行する
    - ロード前に、ブロンズ層のテーブルをtruncateする
    - `copy into`により、csvデータをブロンズ層のテーブルにロードする

引数:
    なし

返り値:
    実行中のログを記録したテキストを文字列として返す

使用例:
    call data_warehouse.bronze.load_bronze();
================================================================================
*/

use role sysadmin;
use warehouse compute_wh;

create or replace procedure data_warehouse.bronze.load_bronze()
returns string
language sql
as
$$
declare
    batch_start_time    timestamp_ntz;
    batch_end_time      timestamp_ntz;
    start_time          timestamp_ntz;
    end_time            timestamp_ntz;
    log_message         string default '';
    loaded_rows         integer;
begin
    batch_start_time := current_timestamp();
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
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/cust_info.csv;
    loaded_rows := SQLROWCOUNT;  -- 直前のcopy intoで読み込まれた行を取得
    end_time := current_timestamp();
    log_message := log_message ||  '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- CRM_PRD_INFO
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.CRM_PRD_INFO\n';
    truncate table DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO;
    log_message := log_message || '>> Inserting Data into Table: BRONZE.CRM_PRD_INFO\n';
    copy into DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/prd_info.csv;
    loaded_rows := SQLROWCOUNT;  -- 直前のcopy intoで読み込まれた行を取得
    end_time := current_timestamp();
    log_message := log_message ||  '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- CRM_SALES_DETAILS
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.CRM_SALES_DETAILS\n';
    truncate table DATA_WAREHOUSE.BRONZE.CRM_SALES_DETAILS;    
    log_message := log_message || '>> Inserting Data into Table: BRONZE.CRM_SALES_DETAILS\n';
    copy into DATA_WAREHOUSE.BRONZE.CRM_SALES_DETAILS
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/sales_details.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Loaded: ' || :loaded_rows || ' rows\n';
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
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_erp/CUST_AZ12.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- erp_loc_a101
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.ERP_LOC_A101\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_LOC_A101;
    log_message := log_message || '>> Inserting Data into Table: BRONZE.ERP_LOC_A101\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_LOC_A101
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/LOC_A101.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message ||  '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- erp_px_cat_g1v2
    start_time := current_timestamp();
    log_message := log_message || '>> Truncating Table: BRONZE.ERP_PX_CAT_G1V2\n';
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2;
    log_message := log_message || '>> Inserting Data into Table: BRONZE.ERP_PX_CAT_G1V2\n';
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/PX_CAT_G1V2.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    log_message := log_message ||  '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message || '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- 処理全体にかかった時間の出力
    batch_end_time := current_timestamp();
    log_message := log_message || '\n==========================================\n';
    log_message := log_message || 'Loading Bronze Layer is Completed\n';
    log_message := log_message || '     - Tota Load Duration: ' || round(datediff(millisecond, batch_start_time, batch_end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '==========================================';

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
$$;
