/*
===============================================================================
品質チェック
===============================================================================
スクリプトの目的:
このスクリプトは『silver』レイヤーにおけるデータの整合性、
正確性、標準化に関する各種品質チェックを実行します。以下を含みます:
- 主キーの NULL または重複。
- 文字列フィールドの不要な空白。
- データの標準化と整合性。
- 無効な日付範囲や日付順序。
- 関連フィールド間のデータ整合性。

使用上の注意:
- Silver レイヤーのデータ読み込み後にこれらのチェックを実行してください。
- チェックで検出された問題は調査し、解決してください。
===============================================================================
*/
-- ====================================================================
-- コンテキスト設定
-- ====================================================================
USE SCHEMA data_warehouse.silver;

-- ====================================================================
-- 'silver.crm_cust_info' のチェック
-- ====================================================================
-- 主キーの NULL または重複をチェック
-- 期待: 結果なし
SELECT
    cst_id,
    COUNT(*)
FROM
    silver.crm_cust_info
GROUP BY
    cst_id
HAVING
    COUNT(*) > 1
    OR cst_id IS NULL;

-- 余計な空白をチェック
-- 期待: 結果なし
SELECT
    cst_key
FROM
    silver.crm_cust_info
WHERE
    cst_key != TRIM(cst_key);

-- データの標準化と整合性
SELECT DISTINCT
    cst_marital_status
FROM
    silver.crm_cust_info;

-- ====================================================================
-- 'silver.crm_prd_info' のチェック
-- ====================================================================
-- 主キーの NULL または重複をチェック
-- 期待: 結果なし
SELECT
    prd_id,
    COUNT(*)
FROM
    silver.crm_prd_info
GROUP BY
    prd_id
HAVING
    COUNT(*) > 1
    OR prd_id IS NULL;

-- 余計な空白をチェック
-- 期待: 結果なし
SELECT
    prd_nm
FROM
    silver.crm_prd_info
WHERE
    prd_nm != TRIM(prd_nm);

-- コストの NULL または負の値をチェック
-- 期待: 結果なし
SELECT
    prd_cost
FROM
    silver.crm_prd_info
WHERE
    prd_cost < 0
    OR prd_cost IS NULL;

-- データの標準化と整合性
SELECT DISTINCT
    prd_line
FROM
    silver.crm_prd_info;

-- 日付順序が不正（開始日 > 終了日）をチェック
-- 期待: 結果なし
SELECT
    *
FROM
    silver.crm_prd_info
WHERE
    prd_end_dt < prd_start_dt;

-- ====================================================================
-- 'silver.crm_sales_details' のチェック
-- ====================================================================
-- 無効な日付をチェック
-- 期待: 無効な日付なし
SELECT
    sls_due_dt
FROM
    silver.crm_sales_details
WHERE
    sls_due_dt IS NULL
    OR sls_due_dt > '2050-01-01'::date
    OR sls_due_dt < '1900-01-01'::date;

-- 日付順序が不正（注文日 > 出荷日/期日）をチェック
-- 期待: 結果なし
SELECT
    *
FROM
    silver.crm_sales_details
WHERE
    sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;

-- データ整合性チェック: 売上 = 数量 * 価格
-- 期待: 結果なし
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM
    silver.crm_sales_details
WHERE
    sls_sales != sls_quantity * sls_price
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

-- ====================================================================
-- 'silver.erp_cust_az12' のチェック
-- ====================================================================
-- 範囲外の日付を特定
-- 期待: 生年月日は 1926-01-01 から今日まで(ただし、1926-01-01以前についてはproc側での規制はしていない)
SELECT DISTINCT
    bdate
FROM
    silver.erp_cust_az12
WHERE
    bdate < '1926-01-01'
    OR bdate > getdate ();

-- データの標準化と整合性
SELECT DISTINCT
    gen
FROM
    silver.erp_cust_az12;

-- ====================================================================
-- 'silver.erp_loc_a101' のチェック
-- ====================================================================
-- データの標準化と整合性
SELECT DISTINCT
    cntry
FROM
    silver.erp_loc_a101
ORDER BY
    cntry;

-- ====================================================================
-- 'silver.erp_px_cat_g1v2' のチェック
-- ====================================================================
-- 余計な空白をチェック
-- 期待: 結果なし
SELECT
    *
FROM
    silver.erp_px_cat_g1v2
WHERE
    cat != TRIM(cat)
    OR subcat != TRIM(subcat)
    OR maintenance != TRIM(maintenance);

-- データの標準化と整合性
SELECT DISTINCT
    maintenance
FROM
    silver.erp_px_cat_g1v2;
