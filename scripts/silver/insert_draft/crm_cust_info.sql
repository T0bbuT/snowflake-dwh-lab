-- ============================================================================
-- DATA_WAREHOUSE.BRONZE.crm_cust_info のチェック、insert文下書き
-- ============================================================================
-- 完成品
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
    cst_create_date,
FROM
    (
        SELECT
            *,
            ROW_NUMBER() over (
                PARTITION BY
                    cst_id
                ORDER BY
                    cst_create_date desc
            ) AS flag_last
        FROM
            bronze.crm_cust_info
        WHERE
            cst_id IS NOT NULL -- cst_idがnullの行は落とす
    )
WHERE
    flag_last = 1;

-- 初期チェック
SELECT
    top 1000 *
FROM
    bronze.crm_cust_info;

-- ============================================================================
-- 1. 主キーたるcst_idに重複がある。見ていく
-- ============================================================================
SELECT
    cst_id,
    COUNT(*)
FROM
    bronze.crm_cust_info
GROUP BY
    cst_id
HAVING
    COUNT(*) > 1
    OR cst_id IS NULL;

SELECT
    *
FROM
    bronze.crm_cust_info
WHERE
    cst_id IS NULL;

SELECT
    *
FROM
    bronze.crm_cust_info
WHERE
    cst_id = 29466;

-- window関数(rouw_number)を使って、cst_create_dateが一番新しいものを抜き取ることにする
SELECT
    *,
    ROW_NUMBER() over (
        PARTITION BY
            cst_id
        ORDER BY
            cst_create_date desc
    ) AS flag_last
FROM
    bronze.crm_cust_info
WHERE
    cst_id = 29466;

SELECT
    *,
    ROW_NUMBER() over (
        PARTITION BY
            cst_id
        ORDER BY
            cst_create_date desc
    ) AS flag_last
FROM
    bronze.crm_cust_info
WHERE
    cst_id IS NULL;

SELECT
    top 1000 *,
    ROW_NUMBER() over (
        PARTITION BY
            cst_id
        ORDER BY
            cst_create_date desc
    ) AS flag_last
FROM
    bronze.crm_cust_info;

SELECT
    *
FROM
    (
        SELECT
            *,
            ROW_NUMBER() over (
                PARTITION BY
                    cst_id
                ORDER BY
                    cst_create_date desc
            ) AS flag_last
        FROM
            bronze.crm_cust_info
    )
WHERE
    flag_last != 1;

-- cst_create_dateが一番新しいものを抜き取ったテーブル
-- これでcst_idの重複を排除したテーブルが手に入った
SELECT
    *
FROM
    (
        SELECT
            *,
            ROW_NUMBER() over (
                PARTITION BY
                    cst_id
                ORDER BY
                    cst_create_date desc
            ) AS flag_last
        FROM
            bronze.crm_cust_info
    )
WHERE
    flag_last = 1;

-- ============================================================================
-- 2. 次に、いずれかのカラムに不要な空白が入ったレコードが散見される。見ていく
-- ============================================================================
SELECT
    cst_firstname
FROM
    bronze.crm_cust_info
WHERE
    cst_firstname != TRIM(cst_firstname);

SELECT
    cst_lastname
FROM
    bronze.crm_cust_info
WHERE
    cst_lastname != TRIM(cst_lastname);

-- 不要な空白が入るのはcst_firstnameとcst_lastnameの2つのよう
SELECT
    top 1000 cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
FROM
    bronze.crm_cust_info;

-- ============================================================================
-- 3. 1と2を合体
-- ============================================================================
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date,
FROM
    (
        SELECT
            *,
            ROW_NUMBER() over (
                PARTITION BY
                    cst_id
                ORDER BY
                    cst_create_date desc
            ) AS flag_last
        FROM
            bronze.crm_cust_info
        WHERE
            cst_id IS NOT NULL -- cst_idがnullの行は落とす
    )
WHERE
    flag_last = 1;

-- ============================================================================
-- 4. CST_MARITAL_STATUS, CST_GNDR列を調べる
-- ============================================================================
SELECT
    cst_marital_status,
    COUNT(*)
FROM
    bronze.crm_cust_info
GROUP BY
    cst_marital_status;

-- 一旦これが完成形？
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    -- CST_MARITAL_STATUS,
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
    cst_create_date,
FROM
    (
        SELECT
            *,
            ROW_NUMBER() over (
                PARTITION BY
                    cst_id
                ORDER BY
                    cst_create_date desc
            ) AS flag_last
        FROM
            bronze.crm_cust_info
        WHERE
            cst_id IS NOT NULL -- cst_idがnullの行は落とす
    )
WHERE
    flag_last = 1;

-- ============================================================================
-- 5. sliver層へのinsert
-- ============================================================================
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
    cst_create_date,
FROM
    (
        SELECT
            *,
            ROW_NUMBER() over (
                PARTITION BY
                    cst_id
                ORDER BY
                    cst_create_date desc
            ) AS flag_last
        FROM
            bronze.crm_cust_info
        WHERE
            cst_id IS NOT NULL -- cst_idがnullの行は落とす
    )
WHERE
    flag_last = 1;

-- ============================================================================
-- 6. 品質チェック
-- ============================================================================
-- truncate table data_warehouse.silver.crm_cust_info;
SELECT
    *
FROM
    data_warehouse.silver.crm_cust_info;

-- 重複排除
SELECT
    COUNT(*),
    COUNT(DISTINCT cst_id),
FROM
    data_warehouse.silver.crm_cust_info;

-- nullの混入チェック
SELECT
    COUNT(*)
FROM
    data_warehouse.silver.crm_cust_info
WHERE
    cst_id IS NULL;

-- 空白の混入をチェック
SELECT
    cst_firstname
FROM
    silver.crm_cust_info
WHERE
    cst_firstname != TRIM(cst_firstname);

SELECT
    cst_lastname
FROM
    silver.crm_cust_info
WHERE
    cst_lastname != TRIM(cst_lastname);