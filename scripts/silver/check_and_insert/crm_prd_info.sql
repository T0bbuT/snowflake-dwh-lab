-- ============================================================================
-- DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO のチェック、insert文下書き
-- ============================================================================

-- クエリ継ぎ足し場
insert into data_warehouse.silver.crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt, 
    prd_end_dt
)
select
    PRD_ID,
    replace(substr(PRD_KEY, 1, 5), '-', '_') as cat_id,
    substr(PRD_KEY, 7, length(PRD_KEY)) as prd_key,
    PRD_NM,
    coalesce(PRD_COST, 0) as prd_cost,
    case upper(trim(PRD_LINE))
        when 'M' then 'Mountain'
        when 'R' then 'Road'
        when 'S' then 'Other Sales'
        when 'T' then 'Touring'
        else 'n/a'
    end as prd_line,
    PRD_START_DT,
    dateadd(
        day, -1,
        lead(PRD_START_DT, 1) over (
            partition by PRD_KEY
            order by PRD_START_DT asc
        )
    ) as PRD_END_DT
from BRONZE.CRM_PRD_INFO;


-- insert後の確認
select * from data_warehouse.silver.crm_prd_info
order by
    cat_id desc,
    prd_key desc;

-- 重複、nullチェック
select
    prd_id,
    cat_id,
    count(*)
from silver.crm_prd_info
group by all
having
    prd_id is null
    or count(*) > 1;

select prd_nm
from silver.crm_prd_info
where
    prd_nm != trim(prd_nm);

select prd_cost
from silver.crm_prd_info
where
    prd_cost is null
    or prd_cost < 0;

select distinct PRD_LINE
from silver.crm_prd_info;

select *
from silver.crm_prd_info
where
    PRD_START_DT > PRD_END_DT;
    

-- TRUNCATE
truncate table data_warehouse.silver.crm_prd_info;