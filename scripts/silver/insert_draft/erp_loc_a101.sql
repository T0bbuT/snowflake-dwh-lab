-- ================================================================================
-- コンテキスト設定
-- ================================================================================
USE DATABASE data_warehouse;

USE ROLE sysadmin;

USE WAREHOUSE compute_wh;

-- ================================================================================
-- クエリ継ぎ足し
-- ================================================================================
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

-- ================================================================================
-- Insert後の確認
-- ================================================================================
SELECT
    *
FROM
    silver.erp_loc_a101;

SELECT
    *
FROM
    bronze.erp_loc_a101;

SELECT
    COUNT(*)
FROM
    silver.erp_loc_a101;

SELECT
    COUNT(*)
FROM
    bronze.erp_loc_a101;

SELECT
    cid,
FROM
    silver.erp_loc_a101
WHERE
    cid NOT like 'AW%'
    OR cid IS NULL;

SELECT
    cid
FROM
    silver.erp_loc_a101
WHERE
    cid NOT IN (
        SELECT
            cst_key
        FROM
            silver.crm_cust_info
    );

SELECT DISTINCT
    cntry
FROM
    silver.erp_loc_a101;

-- ================================================================================
-- 元のテーブル確認
-- ================================================================================
-- erp_loc_a101
SELECT
    cid,
    cntry
FROM
    bronze.erp_loc_a101;

-- crm_cust_info
-- erp_loc_a101のcidと、crm_cust_infoのcst_keyをつなげたい
SELECT
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
FROM
    silver.crm_cust_info;

-- ================================================================================
-- 実験: cidについて
-- ================================================================================
-- erp_cust_az12のときのとは違い、どれも'AW%'から始まっている
-- nullも存在しない
SELECT
    cid,
FROM
    bronze.erp_loc_a101
WHERE
    cid NOT like 'AW%'
    OR cid IS NULL;

-- しかし、どのcidもcst_keyと一致しない
-- よく見ると、cidの形式が'AW-xxxx'と、不要なハイフンが混ざっている
SELECT
    cid,
FROM
    bronze.erp_loc_a101
WHERE
    cid IN (
        SELECT
            cst_key
        FROM
            silver.crm_cust_info
    );

-- ハイフンを取り除くことで、全てのcidをcst_keyに紐づけることができた
SELECT
    REPLACE(cid, '-', '') AS cid_
FROM
    bronze.erp_loc_a101
WHERE
    cid_ NOT IN (
        SELECT
            cst_key
        FROM
            silver.crm_cust_info
    );

-- ================================================================================
-- 実験: cntryについて
-- ================================================================================
-- だいぶ汚い。略称が使われたり、スペース、nullなど色々混ざっている
SELECT
    cntry,
    COUNT(*)
FROM
    bronze.erp_loc_a101
GROUP BY
    ALL;

-- case式の挙動を確認。大丈夫そう
SELECT DISTINCT
    cntry,
    CASE
        WHEN TRIM(cntry) = 'DE' THEN 'Germany'
        WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
        WHEN TRIM(cntry) = ''
        OR cntry IS NULL THEN 'n/a'
        ELSE TRIM(cntry)
    END AS cntry_
FROM
    bronze.erp_loc_a101
ORDER BY
    cntry_;