/*
================================================================================
ストアドプロシージャ: シルバー層へのデータロード(ブロンズ -> シルバー)
================================================================================
目的:
    本ストアドプロシージャは、bronzeスキーマ内にある各テーブルに対し、種々の変換を行った後
    シルバー層のテーブルへとロードする

    以下の処理を実行する
    - ブロンズ層テーブルからの変換・ロード

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
    call data_warehouse.silver.load_silver();
================================================================================
*/

use role sysadmin;
use warehouse compute_wh;

create or replace procedure data_warehouse.silver.load_silver()
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
    SYSTEM$LOG_INFO('LOAD_SILVER: start');

    -- CRM Tables
    SYSTEM$LOG_INFO('LOAD_SILVER: === Loading CRM Tables ===');

    -- crm_cust_info
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.CRM_CUST_INFO');
    TRUNCATE TABLE data_warehouse.silver.crm_cust_info;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.CRM_CUST_INFO');
    INSERT INTO
        data_warehouse.silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            ELSE 'n/a'
        END AS cst_marital_status,
        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            ELSE 'n/a'
        END AS cst_gndr,
        cst_create_date
    FROM
        (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS flag_last
            FROM
                data_warehouse.bronze.crm_cust_info
            WHERE
                cst_id IS NOT NULL
        )
    WHERE
        flag_last = 1;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: CRM_CUST_INFO loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- crm_prd_info
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.CRM_PRD_INFO');
    TRUNCATE TABLE data_warehouse.silver.crm_prd_info;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.CRM_PRD_INFO');
    INSERT INTO
        data_warehouse.silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
    SELECT
        prd_id,
        REPLACE(SUBSTR(prd_key, 1, 5), '-', '_') AS cat_id,
        SUBSTR(prd_key, 7, LENGTH(prd_key)) AS prd_key,
        prd_nm,
        COALESCE(prd_cost, 0) AS prd_cost,
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,
        prd_start_dt,
        DATEADD(
            day,
            -1,
            LEAD(prd_start_dt, 1) OVER (
                PARTITION BY prd_key
                ORDER BY prd_start_dt ASC
            )
        ) AS prd_end_dt
    FROM
        data_warehouse.bronze.crm_prd_info;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: CRM_PRD_INFO loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- crm_sales_details
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.CRM_SALES_DETAILS');
    TRUNCATE TABLE data_warehouse.silver.crm_sales_details;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.CRM_SALES_DETAILS');
    INSERT INTO
        data_warehouse.silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE
            WHEN sls_order_dt <= 0
            OR LEN(sls_order_dt) != 8 THEN NULL
            ELSE TO_DATE(sls_order_dt::VARCHAR, 'YYYYMMDD')
        END AS sls_order_dt,
        CASE
            WHEN sls_ship_dt <= 0
            OR LEN(sls_ship_dt) != 8 THEN NULL
            ELSE TO_DATE(sls_ship_dt::VARCHAR, 'YYYYMMDD')
        END AS sls_ship_dt,
        CASE
            WHEN sls_due_dt <= 0
            OR LEN(sls_due_dt) != 8 THEN NULL
            ELSE TO_DATE(sls_due_dt::VARCHAR, 'YYYYMMDD')
        END AS sls_due_dt,
        CASE
            WHEN sls_sales IS NULL
            OR sls_sales <= 0
            OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales,
        sls_quantity,
        CASE
            WHEN sls_price IS NULL
            OR sls_price <= 0 THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END AS sls_price
    FROM
        data_warehouse.bronze.crm_sales_details;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: CRM_SALES_DETAILS loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- ERP Tables
    SYSTEM$LOG_INFO('LOAD_SILVER: === Loading ERP Tables ===');

    -- erp_cust_az12
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.ERP_CUST_AZ12');
    TRUNCATE TABLE data_warehouse.silver.erp_cust_az12;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.ERP_CUST_AZ12');
    INSERT INTO
        data_warehouse.silver.erp_cust_az12 (cid, bdate, gen)
    SELECT
        CASE
            WHEN cid LIKE 'NASAW%' THEN SUBSTR(cid, 4, LEN(cid))
            ELSE cid
        END AS cid,
        CASE
            WHEN bdate > CURRENT_DATE() THEN NULL
            ELSE bdate
        END AS bdate,
        CASE
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            ELSE 'n/a'
        END AS gen
    FROM
        data_warehouse.bronze.erp_cust_az12;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: ERP_CUST_AZ12 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- erp_loc_a101
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.ERP_LOC_A101');
    TRUNCATE TABLE data_warehouse.silver.erp_loc_a101;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.ERP_LOC_A101');
    INSERT INTO
        data_warehouse.silver.erp_loc_a101 (cid, cntry)
    SELECT
        REPLACE(cid, '-', '') AS cid,
        CASE
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = ''
            OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(cntry)
        END AS cntry
    FROM
        data_warehouse.bronze.erp_loc_a101;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: ERP_LOC_A101 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- erp_px_cat_g1v2
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.ERP_PX_CAT_G1V2');
    TRUNCATE TABLE data_warehouse.silver.erp_px_cat_g1v2;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.ERP_PX_CAT_G1V2');
    INSERT INTO
        data_warehouse.silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT
        id,
        cat,
        subcat,
        maintenance
    FROM
        data_warehouse.bronze.erp_px_cat_g1v2;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: ERP_PX_CAT_G1V2 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- 完了
    batch_end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: completed in ' || round(datediff(millisecond, batch_start_time, batch_end_time) / 1000.0, 3) || 's');

    RETURN 'SUCCESS';

exception
when other then
    SYSTEM$LOG_ERROR('LOAD_SILVER: failed - ' || SQLERRM || ' (code: ' || SQLCODE || ')');
    RETURN 'ERROR: ' || SQLERRM;
end;
$$;
