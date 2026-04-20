-- ============================================================================
-- DATA_WAREHOUSE.BRONZE.CRM_PRD_INFO のチェック、insert文下書き
-- ============================================================================

-- クエリ継ぎ足し場
select
    PRD_ID,
    PRD_KEY,
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
    PRD_END_DT
from BRONZE.CRM_PRD_INFO
;

-- PRD_END_DT > PRD_START_DTを満たす行が1つもない…？
-- どうやら、PRD_END_DTは異常な値が入ってしまっているようだ
-- また、nullの割合も50%近くある
select *
from BRONZE.CRM_PRD_INFO
where
    PRD_END_DT < PRD_START_DT;


select
    PRD_ID, 
    PRD_KEY, 
    PRD_NM, 
    PRD_START_DT, 
    PRD_END_DT
from BRONZE.CRM_PRD_INFO
where
    PRD_KEY in ('AC-HE-HL-U509-R', 'CL-JE-LJ-0192-S');

-- やりたいことは…PRD_KEYごとにpartitionを区切って、PRD_START_DTが自身よりも1つ先に言ってる行のPRD_START_DTが欲しいということ
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



select *
from BRONZE.CRM_PRD_INFO
where
    PRD_END_DT is not null;


-- 初期チェック
select top 1000
*
from BRONZE.CRM_PRD_INFO;

-- PRD_ID → 問題なし
select
    PRD_ID,
    count(*)
from bronze.crm_prd_info
group by PRD_ID
having
    count(*) > 1
    or PRD_ID is null;

-- PRD_KEY
-- 前半5文字が製品カテゴリを表している
select
    substr(PRD_KEY, 1, 5) as cat
from BRONZE.CRM_PRD_INFO;

select id from DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2;

-- 突合してみたが、合致しない。よく見るとつなぎ文字が違う
select
    c.PRD_KEY,
    replace(substr(c.PRD_KEY, 1, 5), '-', '_'),
    e.id
from BRONZE.CRM_PRD_INFO as c
inner join (
    select id from DATA_WAREHOUSE.BRONZE.ERP_PX_CAT_G1V2
) as e
on
    replace(substr(c.PRD_KEY, 1, 5), '-', '_') = e.id;

-- PRD_NMの空白チェック → 問題なし
select
    PRD_NM
from bronze.crm_prd_info
where
    PRD_NM != trim(PRD_NM);

select
    
from bronze.crm_prd_info
where
    PRD_COST < 0
    or PRD_COST is null;