-- dim_customers
CREATE OR REPLACE VIEW data_warehouse.gold.dim_customers AS
SELECT
    MD5(ci.cst_id) AS customer_key, -- サロゲートキー
    ci.cst_id AS customer_id, -- ナチュラルキー
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,
    la.cntry AS country,
    ci.cst_marital_status AS marital_status,
    -- gender: crm_cust_infoとerp_cust_az12の両方に含まれる情報を融合
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- crmが使用不可でない限り、crm側の情報を優先して使用する
        ELSE COALESCE(ca.gen, 'n/a') -- 現状ca.genにNULLは紛れていないが、left joinしている都合上今後混ざるかもしれない。そのためcoalesceを噛ませている
    END AS gender,
    ca.bdate AS birthdate,
    ci.cst_create_date AS create_date,
FROM
    data_warehouse.silver.crm_cust_info AS ci
    LEFT JOIN data_warehouse.silver.erp_cust_az12 AS ca ON ci.cst_key = ca.cid
    LEFT JOIN data_warehouse.silver.erp_loc_a101 AS la ON ci.cst_key = la.cid;

-- dim_products
CREATE OR REPLACE VIEW data_warehouse.gold.dim_products AS
SELECT
    MD5(pn.prd_id) AS product_key, -- サロゲートキー
    pn.prd_id AS product_id, -- ナチュラルキー
    pn.prd_key AS product_number,
    pn.prd_nm AS product_name,
    pn.cat_id AS category_id,
    pc.cat AS category,
    pc.subcat AS subcategory,
    pc.maintenance,
    pn.prd_cost AS cost,
    pn.prd_line AS product_line,
    pn.prd_start_dt AS start_date,
FROM
    data_warehouse.silver.crm_prd_info AS pn
    LEFT JOIN data_warehouse.silver.erp_px_cat_g1v2 AS pc ON pn.cat_id = pc.id
WHERE
    pn.prd_end_dt IS NULL -- end_dtが入力されている過去の商品については扱わない
;

-- fact_sales
SELECT
    sd.sls_ord_num,
    pr.product_key,
    cu.customer_key,
    sd.sls_order_dt,
    sd.sls_ship_dt,
    sd.sls_due_dt,
    sd.sls_sales,
    sd.sls_quantity,
    sd.sls_price,
FROM
    data_warehouse.silver.crm_sales_details AS sd
    LEFT JOIN data_warehouse.gold.dim_products AS pr ON sd.sls_prd_key = pr.product_number
    LEFT JOIN data_warehouse.gold.dim_customers AS cu ON sd.sls_cust_id = cu.customer_id;