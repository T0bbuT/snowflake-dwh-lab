-- ============================================================================
-- DATA_WAREHOUSE.BRONZE.crm_cust_info のチェック、insert文下書き
-- ============================================================================
-- 完成品
insert into data_warehouse.silver.crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
)
select
    CST_ID,
    CST_KEY,
    trim(CST_FIRSTNAME) as CST_FIRSTNAME,
    trim(CST_LASTNAME) as CST_LASTNAME,
    case 
        when upper(trim(CST_MARITAL_STATUS)) = 'M' then 'Married'
        when upper(trim(CST_MARITAL_STATUS)) = 'S' then 'Single'
        else 'n/a'
    end as CST_MARITAL_STATUS,
    case 
        when upper(trim(CST_GNDR)) = 'F' then 'Female'
        when upper(trim(CST_GNDR)) = 'M' then 'Male'
        else 'n/a'
    end as CST_GNDR,
    CST_CREATE_DATE,
from (
    select
        *,
        row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
    from bronze.crm_cust_info
    where cst_id is not null    -- cst_idがnullの行は落とす
)
where
    flag_last = 1;





-- 初期チェック
select top 1000
*
from bronze.crm_cust_info;

-- ============================================================================
-- 1. 主キーたるcst_idに重複がある。見ていく
-- ============================================================================
select
    cst_id,
    count(*)
from bronze.crm_cust_info
group by cst_id
having
    count(*) > 1
    or cst_id is null;

select *
from bronze.crm_cust_info
where
    cst_id is null;

select *
from bronze.crm_cust_info
where
    cst_id = 29466;

-- window関数(rouw_number)を使って、cst_create_dateが一番新しいものを抜き取ることにする
select
    *,
    row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
from bronze.crm_cust_info
where
    cst_id = 29466;

select
    *,
    row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
from bronze.crm_cust_info
where 
    cst_id is null;


select top 1000
    *,
    row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
from bronze.crm_cust_info;

select *
from (
    select
        *,
        row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
    from bronze.crm_cust_info
)
where flag_last != 1;

-- cst_create_dateが一番新しいものを抜き取ったテーブル
-- これでcst_idの重複を排除したテーブルが手に入った
select *
from (
    select
        *,
        row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
    from bronze.crm_cust_info
)
where flag_last = 1;

-- ============================================================================
-- 2. 次に、いずれかのカラムに不要な空白が入ったレコードが散見される。見ていく
-- ============================================================================
select
    cst_firstname
from bronze.crm_cust_info
where
    cst_firstname != trim(cst_firstname);

select
    cst_lastname
from bronze.crm_cust_info
where
    cst_lastname != trim(cst_lastname);

-- 不要な空白が入るのはcst_firstnameとcst_lastnameの2つのよう
select top 1000
    CST_ID,
    CST_KEY,
    trim(CST_FIRSTNAME) as CST_FIRSTNAME,
    trim(CST_LASTNAME) as CST_LASTNAME,
    CST_MARITAL_STATUS,
    CST_GNDR,
    CST_CREATE_DATE
from bronze.crm_cust_info;

-- ============================================================================
-- 3. 1と2を合体
-- ============================================================================
select
    CST_ID,
    CST_KEY,
    trim(CST_FIRSTNAME) as CST_FIRSTNAME,
    trim(CST_LASTNAME) as CST_LASTNAME,
    CST_MARITAL_STATUS,
    CST_GNDR,
    CST_CREATE_DATE,
from (
    select
        *,
        row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
    from bronze.crm_cust_info
    where cst_id is not null    -- cst_idがnullの行は落とす
)
where
    flag_last = 1;

-- ============================================================================
-- 4. CST_MARITAL_STATUS, CST_GNDR列を調べる
-- ============================================================================
select
    cst_marital_status,
    count(*)
from bronze.crm_cust_info
group by cst_marital_status;

-- 一旦これが完成形？
select
    CST_ID,
    CST_KEY,
    trim(CST_FIRSTNAME) as CST_FIRSTNAME,
    trim(CST_LASTNAME) as CST_LASTNAME,
    -- CST_MARITAL_STATUS,
    case 
        when upper(trim(CST_MARITAL_STATUS)) = 'M' then 'Married'
        when upper(trim(CST_MARITAL_STATUS)) = 'S' then 'Single'
        else 'n/a'
    end as CST_MARITAL_STATUS,
    case 
        when upper(trim(CST_GNDR)) = 'F' then 'Female'
        when upper(trim(CST_GNDR)) = 'M' then 'Male'
        else 'n/a'
    end as CST_GNDR,
    CST_CREATE_DATE,
from (
    select
        *,
        row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
    from bronze.crm_cust_info
    where cst_id is not null    -- cst_idがnullの行は落とす
)
where
    flag_last = 1;

-- ============================================================================
-- 5. sliver層へのinsert
-- ============================================================================
insert into data_warehouse.silver.crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
)
select
    CST_ID,
    CST_KEY,
    trim(CST_FIRSTNAME) as CST_FIRSTNAME,
    trim(CST_LASTNAME) as CST_LASTNAME,
    case 
        when upper(trim(CST_MARITAL_STATUS)) = 'M' then 'Married'
        when upper(trim(CST_MARITAL_STATUS)) = 'S' then 'Single'
        else 'n/a'
    end as CST_MARITAL_STATUS,
    case 
        when upper(trim(CST_GNDR)) = 'F' then 'Female'
        when upper(trim(CST_GNDR)) = 'M' then 'Male'
        else 'n/a'
    end as CST_GNDR,
    CST_CREATE_DATE,
from (
    select
        *,
        row_number() over (partition by cst_id order by CST_CREATE_DATE desc) as flag_last
    from bronze.crm_cust_info
    where cst_id is not null    -- cst_idがnullの行は落とす
)
where
    flag_last = 1;

-- ============================================================================
-- 6. 品質チェック
-- ============================================================================

-- truncate table data_warehouse.silver.crm_cust_info;

select * from DATA_WAREHOUSE.SILVER.CRM_CUST_INFO;

-- 重複排除
select 
    count(*),
    count(distinct cst_id),
from DATA_WAREHOUSE.SILVER.CRM_CUST_INFO;

-- nullの混入チェック
select 
    count(*)
from DATA_WAREHOUSE.SILVER.CRM_CUST_INFO
where
    cst_id is null;

-- 空白の混入をチェック
select
    cst_firstname
from silver.crm_cust_info
where
    cst_firstname != trim(cst_firstname);

select
    cst_lastname
from silver.crm_cust_info
where
    cst_lastname != trim(cst_lastname);