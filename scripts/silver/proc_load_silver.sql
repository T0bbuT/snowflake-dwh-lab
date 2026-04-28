/*
================================================================================
ストアドプロシージャ: シルバー層へのデータロード(ブロンズ -> シルバー)
================================================================================
目的:
    本ストアドプロシージャは、bronzeスキーマ内にある各テーブルに対し、種々の変換を行った後
    シルバー層のテーブルへとロードする

    以下の処理を実行する
    - ブロンズ層テーブルからの変換・ロード
    - 各テーブルのロード状況と処理時間をログに記録

引数:
    なし

返り値:
    実行中のログを記録したテキストを文字列として返す

使用例:
    call data_warehouse.silver.load_silver();
================================================================================
*/

use role sysadmin;
use warehouse compute_wh;

-- TODO: このままだと、loaded_rowsがテーブルの行数の2倍になってしまう
-- 恐らく原因はinsert intoにoverwriteオプションを入れていることにより、内部的にtruncateとinsertの両方を実行しているため？
create or replace procedure data_warehouse.silver.load_silver()
returns string
language sql
as
declare
    batch_start_time    timestamp_ntz;
    batch_end_time      timestamp_ntz;
    start_time          timestamp_ntz;
    end_time            timestamp_ntz;
    log_message         string default '';
    loaded_rows         integer;
begin
    batch_start_time := current_timestamp();
    log_message := '================================================\n';
    log_message := log_message || 'Loading Silver Layer\n';
    log_message := log_message || '================================================\n';

    log_message := log_message || '------------------------------------------------\n';
    log_message := log_message || 'Loading CRM Tables\n';
    log_message := log_message || '------------------------------------------------\n';

    -- crm_cust_info
    start_time := current_timestamp();
    log_message := log_message || '>> Processing Table: SILVER.CRM_CUST_INFO\n';
    INSERT OVERWRITE INTO
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
                cst_id IS NOT NULL -- cst_idがnullの行は落とす
        )
    WHERE
        flag_last = 1;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    log_message := log_message || '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message || '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- crm_prd_info
    start_time := current_timestamp();
    log_message := log_message || '>> Processing Table: SILVER.CRM_PRD_INFO\n';
    INSERT OVERWRITE INTO
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
    log_message := log_message || '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message || '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- crm_sales_details
    start_time := current_timestamp();
    log_message := log_message || '>> Processing Table: SILVER.CRM_SALES_DETAILS\n';
    INSERT OVERWRITE INTO
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
    log_message := log_message || '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message || '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    log_message := log_message || '------------------------------------------------\n';
    log_message := log_message || 'Loading ERP Tables\n';
    log_message := log_message || '------------------------------------------------\n';

    -- erp_cust_az12
    start_time := current_timestamp();
    log_message := log_message || '>> Processing Table: SILVER.ERP_CUST_AZ12\n';
    INSERT OVERWRITE INTO
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
    log_message := log_message || '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message || '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- erp_loc_a101
    start_time := current_timestamp();
    log_message := log_message || '>> Processing Table: SILVER.ERP_LOC_A101\n';
    INSERT OVERWRITE INTO
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
    log_message := log_message || '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message || '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    -- erp_px_cat_g1v2
    start_time := current_timestamp();
    log_message := log_message || '>> Processing Table: SILVER.ERP_PX_CAT_G1V2\n';
    INSERT OVERWRITE INTO
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
    log_message := log_message || '>> Loaded: ' || :loaded_rows || ' rows\n';
    log_message := log_message || '>> Load Duration: ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '----------\n';

    batch_end_time := current_timestamp();
    log_message := log_message || '\n==========================================\n';
    log_message := log_message || 'Loading Silver Layer is Completed\n';
    log_message := log_message || '     - Total Load Duration: ' || round(datediff(millisecond, batch_start_time, batch_end_time) / 1000.0, 3) || ' seconds\n';
    log_message := log_message || '==========================================';

    RETURN log_message;

exception
when other then
    log_message := log_message || '\n==========================================\n';
    log_message := log_message || 'ERROR OCCURRED DURING LOADING SILVER LAYER\n';
    log_message := log_message || 'Error Message: ' || SQLERRM || '\n';
    log_message := log_message || 'Error Code: ' || SQLCODE || '\n';
    log_message := log_message || '==========================================';

    RETURN log_message;
end;