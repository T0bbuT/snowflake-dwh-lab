/*
===============================================================================
品質チェック
===============================================================================
スクリプトの目的:
    このスクリプトは Gold レイヤーの整合性、一貫性、正確性を確認します。
    以下の項目をチェックします:
    - ディメンションのサロゲートキーの一意性。
    - ファクトとディメンション間の参照整合性。
    - 分析用データモデルにおける関連付けの妥当性。

使用上の注意:
    - Gold レイヤーのビューを作成した後に実行してください。
    - 各チェックの結果が 0 件であることを確認してください。
    - チェックで検出された問題は調査し、解決してください。
===============================================================================
*/

-- ====================================================================
-- 'gold.dim_customers' のチェック
-- ====================================================================
-- 顧客キーの重複をチェック
-- 期待: 結果なし
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM data_warehouse.gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- 'gold.dim_products' のチェック
-- ====================================================================
-- 商品キーの重複をチェック
-- 期待: 結果なし
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM data_warehouse.gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- 'gold.fact_sales' のチェック
-- ====================================================================
-- 顧客または商品ディメンションに関連付けられない売上をチェック
-- 期待: 結果なし
SELECT *
FROM data_warehouse.gold.fact_sales AS f
LEFT JOIN data_warehouse.gold.dim_customers AS c
    ON c.customer_key = f.customer_key
LEFT JOIN data_warehouse.gold.dim_products AS p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL OR c.customer_key IS NULL;
