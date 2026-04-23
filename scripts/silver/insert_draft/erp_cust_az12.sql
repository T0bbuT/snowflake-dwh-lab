-- ================================================================================
-- コンテキスト設定
-- ================================================================================
USE DATABASE data_warehouse;

-- ================================================================================
-- クエリ継ぎ足し
-- ================================================================================
SELECT
    cid,
    bdate,
    gen
FROM
    bronze.erp_cust_az12;

-- ================================================================================
-- 元のテーブル
-- ================================================================================
-- bronze.erp_cust_az12
-- CIDは'NASAW000--'みたいな形式が多い？
SELECT
    cid,
    bdate,
    gen
FROM
    bronze.erp_cust_az12;

-- 接続できるはずのcrm_cust_infoの確認
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
-- 実験
-- ================================================================================
-- crm_cust_infoに居る顧客キー(cst_key)がerp_cust_az12にも居るか確認
-- erp_cust_az12には、'NASAW%'、または'AW%'といった形式の顧客キーがある(それ以外は存在しない)
SELECT
    cid,
    bdate,
    gen
FROM
    bronze.erp_cust_az12
WHERE -- 'NASAW%'、'AW%'でもない形式のもの
    cid NOT like 'NASAW%'
    AND cid NOT like 'AW%';

-- 一方で、crm_cust_infoには'AW%'といった形式の顧客キーしかない
SELECT
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
FROM
    silver.crm_cust_info
WHERE
    cst_key NOT like 'AW%';

-- 'NASAW%'形式のものの先頭の'NAS'を切り落として'AW%'にしてよいのかどうかは不明
-- silver.crm_cust_infoに存在する顧客キー('AW%'形式)のdistinctな個数は18484個
SELECT
    COUNT(DISTINCT cst_key)
FROM
    silver.crm_cust_info;

-- 一方、その顧客キーの中で、bronze.erp_cust_az12にも存在してるもののdistinctな個数は7442個
SELECT
    COUNT(DISTINCT cst_key)
FROM
    silver.crm_cust_info
WHERE
    cst_key IN (
        SELECT
            cid
        FROM
            bronze.erp_cust_az12
    );

-- bronze.erp_cust_az12の'NASAW%'形式の顧客キーの先頭の'NAS'を切り落とした場合にどうなるのか見る
-- 一致する個数は、元の個数である18484個と一致した。どうやら、やって良さそう…？何かしらの情報の損失だけ怖いけど
SELECT
    COUNT(DISTINCT cst_key)
FROM
    silver.crm_cust_info
WHERE
    cst_key IN (
        SELECT
            CASE
                WHEN cid like 'NASAW%' THEN REGEXP_REPLACE(cid, '^NAS', '')
                WHEN cid like 'AW%' THEN cid
                ELSE NULL
            END AS cid
        FROM
            bronze.erp_cust_az12
    );