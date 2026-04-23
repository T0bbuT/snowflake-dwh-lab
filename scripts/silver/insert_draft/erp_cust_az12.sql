-- ================================================================================
-- コンテキスト設定
-- ================================================================================
USE DATABASE data_warehouse;

-- ================================================================================
-- クエリ継ぎ足し
-- ================================================================================
INSERT INTO
    data_warehouse.silver.erp_cust_az12 (cid, bdate, gen)
SELECT
    CASE
        WHEN cid like 'NASAW%' THEN SUBSTR(cid, 4, LEN(cid))
        ELSE cid
    END AS cid,
    CASE
        WHEN bdate > CURRENT_DATE() THEN NULL
        ELSE bdate
    END AS bdate,
    CASE
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        ELSE 'n/a'
    END AS gen,
FROM
    bronze.erp_cust_az12;

-- ================================================================================
-- チェック: insertしたsilver.erp_cust_az12
-- ================================================================================
-- 概観
SELECT
    *
FROM
    silver.erp_cust_az12;

-- cid列
SELECT
    COUNT(DISTINCT cst_key)
FROM
    silver.crm_cust_info
WHERE
    cst_key NOT IN (
        SELECT
            cid
        FROM
            silver.erp_cust_az12
    );

-- bdata列
SELECT
    bdate
FROM
    silver.erp_cust_az12
WHERE
    bdate > CURRENT_DATE() -- 未来
;

-- gen列
SELECT
    gen,
    COUNT(*)
FROM
    silver.erp_cust_az12
GROUP BY
    gen;

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
-- 実験: cidについて
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
-- 一致する個数は、元の個数である18484個と一致した。どうやら、やって良さそう？
SELECT
    COUNT(DISTINCT cst_key)
FROM
    silver.crm_cust_info
WHERE
    cst_key IN (
        SELECT
            CASE
                WHEN cid like 'NASAW%' THEN SUBSTR(cid, 4, LEN(cid))
                ELSE cid
            END AS cid
        FROM
            bronze.erp_cust_az12
    );

-- 以下を見てみると、'NASAW%'を切り落として'AW%'としても、erp_cust_az12内の既存の'AW%'と重複することは無さそうだということが分かった
-- 本当はNASがついている理由が分かる人に聞いて判断すべきだが、今回は居ないので切り落として良いと判断
SELECT
    CASE
        WHEN cid like 'NASAW%' THEN SUBSTR(cid, 4, LEN(cid))
        ELSE cid
    END AS cid,
    COUNT(*)
FROM
    bronze.erp_cust_az12
GROUP BY
    ALL
HAVING
    COUNT(*) > 1;

-- ================================================================================
-- 実験: bdateについて
-- ================================================================================
-- どうやらNULLはないようだが、一部明らかに不正な日時(例: 2050-07-06, 9999-09-13)が入っている
-- 100歳以上の顧客も入っているようだが…ここでは無視することとする
SELECT
    bdate
FROM
    bronze.erp_cust_az12
WHERE
    bdate IS NULL
    OR bdate > CURRENT_DATE() -- 未来
    OR bdate < DATEADD(year, -100, CURRENT_DATE()) -- 100歳以上
;

-- ================================================================================
-- 実験: genについて
-- ================================================================================
-- nullの割合が少し多い
-- また、大多数はMaleかFemaleが入っているが、一部別の文字列(例: 空白、M、F)が入ってしまっている
SELECT
    gen,
    COUNT(*)
FROM
    bronze.erp_cust_az12
GROUP BY
    gen;

-- CASE式の挙動確認。これで問題なさそう
SELECT
    gen,
    CASE
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        ELSE 'n/a'
    END AS gen_,
    COUNT(*)
FROM
    bronze.erp_cust_az12
WHERE
    gen NOT IN ('Male', 'Female')
    OR gen IS NULL;

-- ちゃんと、Male, Female, n/aの3つに分けられている
SELECT
    CASE
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        ELSE 'n/a'
    END AS gen_,
    COUNT(*)
FROM
    bronze.erp_cust_az12
GROUP BY
    ALL;
