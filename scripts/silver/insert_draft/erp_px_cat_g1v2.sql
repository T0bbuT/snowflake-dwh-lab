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
    data_warehouse.silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
SELECT
    id,
    cat,
    subcat,
    maintenance
FROM
    bronze.erp_px_cat_g1v2;

-- ================================================================================
-- Insert後の確認
-- ================================================================================
SELECT
    *
FROM
    silver.erp_px_cat_g1v2;
-- ================================================================================
-- 元のテーブル確認
-- ================================================================================
SELECT
    id,
    cat,
    subcat,
    maintenance
FROM
    bronze.erp_px_cat_g1v2;

SELECT
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
FROM
    silver.crm_prd_info;

-- ================================================================================
-- 検査: idについて
-- ================================================================================
-- data_integrationの図には、erp_px_cat_g1v2とのidとsilver.crm_prd_infoのcat_id(silver層で新設)が繋がっている
-- ここについては、cat_idを作った時に問題がないことまで確認済みなので、これ以上手を加える必要はない
SELECT
    *
FROM
    bronze.erp_px_cat_g1v2
WHERE
    id IN (
        SELECT
            cat_id
        FROM
            silver.crm_prd_info
    );

-- ================================================================================
-- 検査: catについて
-- ================================================================================
-- おかしなカテゴリーは無さそう
SELECT DISTINCT
    cat
FROM
    bronze.erp_px_cat_g1v2;

-- スペースの混入もなし
SELECT
    cat
FROM
    bronze.erp_px_cat_g1v2
WHERE
    TRIM(cat) != cat;

-- ================================================================================
-- 検査: subcatについて
-- ================================================================================
-- おかしなサブカテゴリーは無さそう
SELECT DISTINCT
    subcat
FROM
    bronze.erp_px_cat_g1v2;

-- スペースの混入もなし
SELECT
    subcat
FROM
    bronze.erp_px_cat_g1v2
WHERE
    TRIM(subcat) != subcat;

-- ================================================================================
-- 検査: maintenanceについて
-- ================================================================================
-- おかしな入力はなさそう
SELECT DISTINCT
    maintenance
FROM
    bronze.erp_px_cat_g1v2;

SELECT
    maintenance
FROM
    bronze.erp_px_cat_g1v2
WHERE
    TRIM(maintenance) != maintenance;