-- ============================================================================
-- DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO のチェック、insert文下書き
-- ============================================================================

-- クエリ継ぎ足し場
select
    PRD_ID,
    -- PRD_KEY,
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
    PRD_END_DT,
    dateadd(
        day, -1,
        lead(PRD_START_DT, 1) over (
            partition by PRD_KEY
            order by PRD_START_DT asc
        )
    ) as PRD_END_DT_test
from BRONZE.CRM_PRD_INFO;


select
    PRD_ID, 
    PRD_KEY, 
    PRD_NM, 
    PRD_START_DT, 
    PRD_END_DT
from BRONZE.CRM_PRD_INFO
where
    PRD_KEY in ('AC-HE-HL-U509-R', 'CL-JE-LJ-0192-S');

-- やりたいことは…PRD_KEYごとにpartitionを区切って、PRD_START_DTが自身よりも1つ先に行ってる行のPRD_START_DTが欲しいということ
select
    PRD_ID,
    PRD_KEY,
    PRD_NM,
    PRD_START_DT,
    PRD_END_DT,
    dateadd(
        day, -1,
        lead(PRD_START_DT, 1) over (
            partition by PRD_KEY
            order by PRD_START_DT asc
        )
    ) as PRD_END_DT_test
from BRONZE.CRM_PRD_INFO
order by
    PRD_KEY asc,
    PRD_START_DT asc;

