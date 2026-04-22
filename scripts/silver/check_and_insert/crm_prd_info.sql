-- ============================================================================
-- DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO のチェック、insert文下書き
-- ============================================================================
-- クエリ継ぎ足し場
INSERT INTO
    data_warehouse.silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
SELECT
    prd_id,
    REPLACE(SUBSTR(prd_key, 1, 5), '-', '_') AS cat_id,
    SUBSTR(prd_key, 7, LENGTH(prd_key)) AS prd_key,
    prd_nm,
    COALESCE(prd_cost, 0) AS prd_cost,
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    prd_start_dt,
    DATEADD(
        day,
        -1,
        LEAD(prd_start_dt, 1) over (
            PARTITION BY
                prd_key
            ORDER BY
                prd_start_dt asc
        )
    ) AS prd_end_dt
FROM
    bronze.crm_prd_info;

-- insert後の確認
SELECT
    *
FROM
    data_warehouse.silver.crm_prd_info
ORDER BY
    cat_id desc,
    prd_key desc;

-- 重複、nullチェック
SELECT
    prd_id,
    cat_id,
    COUNT(*)
FROM
    silver.crm_prd_info
GROUP BY
    ALL
HAVING
    prd_id IS NULL
    OR COUNT(*) > 1;

SELECT
    prd_nm
FROM
    silver.crm_prd_info
WHERE
    prd_nm != TRIM(prd_nm);

SELECT
    prd_cost
FROM
    silver.crm_prd_info
WHERE
    prd_cost IS NULL
    OR prd_cost < 0;

SELECT DISTINCT
    prd_line
FROM
    silver.crm_prd_info;

SELECT
    *
FROM
    silver.crm_prd_info
WHERE
    prd_start_dt > prd_end_dt;

-- TRUNCATE
TRUNCATE TABLE data_warehouse.silver.crm_prd_info;