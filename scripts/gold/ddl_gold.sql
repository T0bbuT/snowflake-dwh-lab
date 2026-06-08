SELECT
    ci.cst_id AS customer_id,
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