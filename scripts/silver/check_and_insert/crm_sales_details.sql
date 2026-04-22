USE DATABASE data_warehouse;
-- ================================================================================
-- データ移行スクリプト: bronzeからsilverへのデータ移行
-- ================================================================================
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
    bronze.crm_sales_details;

-- =================================================================================
-- データ確認クエリ
-- =================================================================================

-- 元の文
SELECT
    top 100 sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
FROM
    bronze.crm_sales_details;

SELECT
    *
FROM
    silver.crm_sales_details;

-- 実験
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
FROM
    silver.crm_sales_details
WHERE
    sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt
    OR sls_ship_dt > sls_due_dt;

SELECT
    sls_quantity,
    sls_price,
    sls_sales,
FROM
    silver.crm_sales_details
WHERE
    sls_sales != sls_quantity * ABS(sls_price)
    OR sls_sales IS NULL
    OR sls_quantity IS NULL
    OR sls_price IS NULL
    OR sls_sales <= 0
    OR sls_quantity <= 0
    OR sls_price <= 0
ORDER BY
    sls_sales,
    sls_quantity,
    sls_price;