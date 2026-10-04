/*
===============================================================================
品質チェック: Gold
===============================================================================
スクリプトの目的:
    Goldレイヤーについて、ディメンションのサロゲートキーの一意性と、
    ファクトとディメンション間の参照整合性を確認する。

結果の見方:
    tests/quality_checks_silver.sql と同じ形式で、チェックごとに1行を返す。
    statusがFAILの行がないことを確認する。

使用上の注意:
    - Goldレイヤーのビューを作成した後に実行する。
===============================================================================
*/

WITH results AS (
    SELECT
        'G01' AS check_id,
        'dim_customers: 顧客キー(customer_key)の重複' AS check_name,
        'ERROR' AS severity,
        COUNT(*) AS failed_rows,
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ') AS examples
    FROM (
        SELECT COALESCE(customer_key, 'NULL') AS example
        FROM data_warehouse.gold.dim_customers
        GROUP BY customer_key
        HAVING COUNT(*) > 1
    )

    UNION ALL
    SELECT
        'G02', 'dim_products: 商品キー(product_key)の重複', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT COALESCE(product_key, 'NULL') AS example
        FROM data_warehouse.gold.dim_products
        GROUP BY product_key
        HAVING COUNT(*) > 1
    )

    UNION ALL
    SELECT
        'G03', 'fact_sales: 顧客または商品ディメンションに関連付けられない売上', 'ERROR', COUNT(*),
        ARRAY_TO_STRING(ARRAY_SLICE(ARRAY_SORT(ARRAY_AGG(DISTINCT example)), 0, 5), ', ')
    FROM (
        SELECT f.order_number AS example
        FROM data_warehouse.gold.fact_sales AS f
        LEFT JOIN data_warehouse.gold.dim_customers AS c
            ON c.customer_key = f.customer_key
        LEFT JOIN data_warehouse.gold.dim_products AS p
            ON p.product_key = f.product_key
        WHERE p.product_key IS NULL OR c.customer_key IS NULL
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
