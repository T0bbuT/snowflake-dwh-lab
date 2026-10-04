/*
===============================================================================
品質チェック: Silver
===============================================================================
スクリプトの目的:
    Silverレイヤーのデータについて、主キーのNULL・重複、不要な空白、
    分類値の標準化、日付の妥当性、売上・数量・単価の整合性を確認する。

結果の見方:
    1つのクエリで、チェックごとに次の1行を返す。
    - check_id / check_name: チェックの識別子と内容
    - severity: ERROR(不正値。0件であるべき) / WARN(確認対象。行があっても不正とは限らない)
    - failed_rows: 条件に該当した行数
    - status: PASS(0件) / FAIL(ERRORで1件以上) / WARN(WARNで1件以上)
    - examples: 該当した値またはキーの例(重複を除き最大5件、カンマ区切り)

    statusがFAILの行がないことを確認する。WARNは内容を確認し、仕様どおりか判断する。

使用上の注意:
    - Silverレイヤーのデータ読み込み後に実行する。
===============================================================================
*/

WITH results AS (
    -- ====================================================================
    -- silver.crm_cust_info
    -- ====================================================================
    SELECT
        'S01' AS check_id,
        'crm_cust_info: 主キー(cst_id)のNULL・重複' AS check_name,
        'ERROR' AS severity,
        COUNT(*) AS failed_rows,
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ') AS examples
    FROM (
        SELECT COALESCE(TO_VARCHAR(cst_id), 'NULL') AS example
        FROM data_warehouse.silver.crm_cust_info
        GROUP BY cst_id
        HAVING COUNT(*) > 1 OR cst_id IS NULL
    )

    UNION ALL
    SELECT
        'S02', 'crm_cust_info: 顧客キー(cst_key)の前後の空白', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT cst_key AS example
        FROM data_warehouse.silver.crm_cust_info
        WHERE cst_key != TRIM(cst_key)
    )

    UNION ALL
    SELECT
        'S03', 'crm_cust_info: 婚姻状態が Married / Single / n/a 以外', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT COALESCE(cst_marital_status, 'NULL') AS example
        FROM data_warehouse.silver.crm_cust_info
        WHERE COALESCE(cst_marital_status, 'NULL') NOT IN ('Married', 'Single', 'n/a')
    )

    -- ====================================================================
    -- silver.crm_prd_info
    -- ====================================================================
    UNION ALL
    SELECT
        'S04', 'crm_prd_info: 主キー(prd_id)のNULL・重複', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT COALESCE(TO_VARCHAR(prd_id), 'NULL') AS example
        FROM data_warehouse.silver.crm_prd_info
        GROUP BY prd_id
        HAVING COUNT(*) > 1 OR prd_id IS NULL
    )

    UNION ALL
    SELECT
        'S05', 'crm_prd_info: 商品名(prd_nm)の前後の空白', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT prd_nm AS example
        FROM data_warehouse.silver.crm_prd_info
        WHERE prd_nm != TRIM(prd_nm)
    )

    UNION ALL
    SELECT
        'S06', 'crm_prd_info: 原価(prd_cost)のNULL・負の値', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT TO_VARCHAR(prd_id) AS example
        FROM data_warehouse.silver.crm_prd_info
        WHERE prd_cost < 0 OR prd_cost IS NULL
    )

    UNION ALL
    SELECT
        'S07', 'crm_prd_info: 商品ラインが Mountain / Road / Other Sales / Touring / n/a 以外', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT COALESCE(prd_line, 'NULL') AS example
        FROM data_warehouse.silver.crm_prd_info
        WHERE COALESCE(prd_line, 'NULL') NOT IN ('Mountain', 'Road', 'Other Sales', 'Touring', 'n/a')
    )

    UNION ALL
    SELECT
        'S08', 'crm_prd_info: 終了日が開始日より前', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT TO_VARCHAR(prd_id) AS example
        FROM data_warehouse.silver.crm_prd_info
        WHERE prd_end_dt < prd_start_dt
    )

    -- ====================================================================
    -- silver.crm_sales_details
    -- ====================================================================
    UNION ALL
    SELECT
        'S09', 'crm_sales_details: 期日がNULL・1900-01-01より前・2050-01-01より後', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT sls_ord_num AS example
        FROM data_warehouse.silver.crm_sales_details
        WHERE sls_due_dt IS NULL
            OR sls_due_dt > '2050-01-01'::DATE
            OR sls_due_dt < '1900-01-01'::DATE
    )

    UNION ALL
    SELECT
        'S10', 'crm_sales_details: 注文日が出荷日・期日より後', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT sls_ord_num AS example
        FROM data_warehouse.silver.crm_sales_details
        WHERE sls_order_dt > sls_ship_dt
            OR sls_order_dt > sls_due_dt
    )

    -- 売上は数量×単価で再計算するため、値がある行では常に一致し、すべて正になるはず。
    UNION ALL
    SELECT
        'S11', 'crm_sales_details: 売上 != 数量×単価、または0以下の値', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT sls_ord_num AS example
        FROM data_warehouse.silver.crm_sales_details
        WHERE sls_sales != sls_quantity * sls_price
            OR sls_sales <= 0
            OR sls_quantity <= 0
            OR sls_price <= 0
    )

    -- ソースの数量・単価が欠損または不正な行はNULLとする仕様(ADR-0006)。
    -- GoldのFACT_SALESからは除外される。件数と元の値を確認する。
    UNION ALL
    SELECT
        'S12', 'crm_sales_details: 売上・数量・単価のNULL(Goldでは除外)', 'WARN', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT sls_ord_num AS example
        FROM data_warehouse.silver.crm_sales_details
        WHERE sls_sales IS NULL
            OR sls_quantity IS NULL
            OR sls_price IS NULL
    )

    -- ====================================================================
    -- silver.erp_cust_az12
    -- ====================================================================
    -- 未来の生年月日はLOAD_SILVERでNULLにするため、検出された場合は処理を調査する。
    UNION ALL
    SELECT
        'S13', 'erp_cust_az12: 未来の生年月日', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT cid AS example
        FROM data_warehouse.silver.erp_cust_az12
        WHERE bdate > CURRENT_DATE()
    )

    -- 120歳は調査の目安であり、不正値とは断定しない。古い日付は補正せず保持する。
    -- 120年前の同日は対象外。
    UNION ALL
    SELECT
        'S14', 'erp_cust_az12: 実行日から120年前より古い生年月日', 'WARN', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT cid AS example
        FROM data_warehouse.silver.erp_cust_az12
        WHERE bdate < DATEADD(year, -120, CURRENT_DATE())
    )

    UNION ALL
    SELECT
        'S15', 'erp_cust_az12: 性別が Male / Female / n/a 以外', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT COALESCE(gen, 'NULL') AS example
        FROM data_warehouse.silver.erp_cust_az12
        WHERE COALESCE(gen, 'NULL') NOT IN ('Male', 'Female', 'n/a')
    )

    -- ====================================================================
    -- silver.erp_loc_a101
    -- ====================================================================
    -- 新しい国が追加されることはあり得るため、一覧外の値は確認対象とする。
    -- 国コード(例: UK)が残っている場合は、LOAD_SILVERの変換を見直す。
    UNION ALL
    SELECT
        'S16', 'erp_loc_a101: 国が既知の6か国・n/a 以外', 'WARN', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT COALESCE(cntry, 'NULL') AS example
        FROM data_warehouse.silver.erp_loc_a101
        WHERE COALESCE(cntry, 'NULL') NOT IN (
            'Australia', 'Canada', 'France', 'Germany', 'United Kingdom', 'United States', 'n/a'
        )
    )

    -- ====================================================================
    -- silver.erp_px_cat_g1v2
    -- ====================================================================
    UNION ALL
    SELECT
        'S17', 'erp_px_cat_g1v2: カテゴリ・サブカテゴリ・保守区分の前後の空白', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT id AS example
        FROM data_warehouse.silver.erp_px_cat_g1v2
        WHERE cat != TRIM(cat)
            OR subcat != TRIM(subcat)
            OR maintenance != TRIM(maintenance)
    )

    UNION ALL
    SELECT
        'S18', 'erp_px_cat_g1v2: 保守区分が Yes / No 以外', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT COALESCE(maintenance, 'NULL') AS example
        FROM data_warehouse.silver.erp_px_cat_g1v2
        WHERE COALESCE(maintenance, 'NULL') NOT IN ('Yes', 'No')
    )
)

SELECT
    check_id,
    check_name,
    severity,
    failed_rows,
    CASE
        WHEN failed_rows = 0 THEN 'PASS'
        WHEN severity = 'ERROR' THEN 'FAIL'
        ELSE 'WARN'
    END AS status,
    examples
FROM
    results
ORDER BY
    check_id;
