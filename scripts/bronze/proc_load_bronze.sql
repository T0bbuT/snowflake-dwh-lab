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
    成功時: 'SUCCESS'
    失敗時: エラーメッセージ

ログ:
    実行中のログはEvent Tableに記録される。
    確認方法は scripts/query_load_logs.sql を参照。

前提:
    - scripts/init_event_table.sql を事前に実行しておくこと

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
    loaded_rows         integer;
begin
    batch_start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: start');

    -- CRM Tables
    SYSTEM$LOG_INFO('LOAD_BRONZE: === Loading CRM Tables ===');

    -- CRM_CUST_INFO
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: Truncating BRONZE.CRM_CUST_INFO');
    truncate table DATA_WAREHOUSE.BRONZE.CRM_CUST_INFO;
    SYSTEM$LOG_INFO('LOAD_BRONZE: Inserting into BRONZE.CRM_CUST_INFO');
    copy into DATA_WAREHOUSE.BRONZE.CRM_CUST_INFO
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/cust_info.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: CRM_CUST_INFO loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- CRM_PRD_INFO
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: Truncating BRONZE.CRM_PRD_INFO');
    truncate table DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO;
    SYSTEM$LOG_INFO('LOAD_BRONZE: Inserting into BRONZE.CRM_PRD_INFO');
    copy into DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/prd_info.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: CRM_PRD_INFO loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- CRM_SALES_DETAILS
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: Truncating BRONZE.CRM_SALES_DETAILS');
    truncate table DATA_WAREHOUSE.BRONZE.CRM_SALES_DETAILS;
    SYSTEM$LOG_INFO('LOAD_BRONZE: Inserting into BRONZE.CRM_SALES_DETAILS');
    copy into DATA_WAREHOUSE.BRONZE.CRM_SALES_DETAILS
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_crm/sales_details.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: CRM_SALES_DETAILS loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- ERP Tables
    SYSTEM$LOG_INFO('LOAD_BRONZE: === Loading ERP Tables ===');

    -- ERP_CUST_AZ12
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: Truncating BRONZE.ERP_CUST_AZ12');
    truncate table DATA_WAREHOUSE.BRONZE.ERP_CUST_AZ12;
    SYSTEM$LOG_INFO('LOAD_BRONZE: Inserting into BRONZE.ERP_CUST_AZ12');
    copy into DATA_WAREHOUSE.BRONZE.ERP_CUST_AZ12
    from @"DATA_WAREHOUSE"."STAGING"."STG_CSV_FILES"/datasets/source_erp/CUST_AZ12.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: ERP_CUST_AZ12 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- ERP_LOC_A101
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: Truncating BRONZE.ERP_LOC_A101');
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_LOC_A101;
    SYSTEM$LOG_INFO('LOAD_BRONZE: Inserting into BRONZE.ERP_LOC_A101');
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_LOC_A101
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/LOC_A101.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: ERP_LOC_A101 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- ERP_PX_CAT_G1V2
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: Truncating BRONZE.ERP_PX_CAT_G1V2');
    TRUNCATE TABLE DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2;
    SYSTEM$LOG_INFO('LOAD_BRONZE: Inserting into BRONZE.ERP_PX_CAT_G1V2');
    COPY INTO DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2
    FROM @DATA_WAREHOUSE.STAGING.STG_CSV_FILES/datasets/source_erp/PX_CAT_G1V2.csv;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: ERP_PX_CAT_G1V2 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- 完了
    batch_end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_BRONZE: completed in ' || round(datediff(millisecond, batch_start_time, batch_end_time) / 1000.0, 3) || 's');

    RETURN 'SUCCESS';

exception
when other then
    SYSTEM$LOG_ERROR('LOAD_BRONZE: failed - ' || SQLERRM || ' (code: ' || SQLCODE || ')');
    RETURN 'ERROR: ' || SQLERRM;
end;
$$;
