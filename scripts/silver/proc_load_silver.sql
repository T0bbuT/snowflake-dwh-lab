/*
================================================================================
ストアドプロシージャ: シルバー層へのデータロード(ブロンズ -> シルバー)
================================================================================
目的:
    本ストアドプロシージャは、bronzeスキーマ内にある各テーブルに対し、種々の変換を行った後
    シルバー層のテーブルへとロードする

    以下の処理を実行する
    - 各シルバー層テーブルをtruncateし、ブロンズ層から変換した結果をinsertする(全件入れ替え)
    - テーブルごとの主な変換は次のとおり。詳細は各INSERT文の直前のコメントを参照
        crm_cust_info   : 顧客IDごとに最新の1行へ重複排除、氏名の空白除去、コード値の展開
        crm_prd_info    : 商品キーからカテゴリIDを分離、終了日を次バージョンの開始日から再計算
        crm_sales_details: 整数の日付をDATEへ変換、売上・単価の欠損や不整合を補正
        erp_cust_az12   : 顧客IDの接頭辞を除去、未来の生年月日をNULL化、性別の表記統一
        erp_loc_a101    : 顧客IDのハイフンを除去、国コードを国名へ統一
        erp_px_cat_g1v2 : 変換なし
    - 顧客IDの変換は、ERPの顧客IDをCRMの顧客キー(例: AW00011000)と結合できる形式へ揃えるためのもの

    各テーブルは別々の文で処理されるため、途中で失敗すると一部のテーブルだけが更新済み、
    または空の状態で終了する。LOAD_BRONZE()がSUCCESSを返したことを確認してから呼び出す。

引数:
    なし

返り値:
    成功時: 'SUCCESS'
    失敗時: 'ERROR: <エラーメッセージ>'

ログ:
    実行中のログはEvent Tableに記録される。
    確認方法は scripts/logging/query_load_logs.sql を参照。

前提:
    - scripts/logging/ensure_event_table.sql と configure_event_target.sql でログ保存先・出力先を設定済みであること
    - scripts/logging/configure_logging.sql をロード呼び出し前に実行しておくこと

使用例:
    call data_warehouse.silver.load_silver();
================================================================================
*/

use role sysadmin;
use warehouse compute_wh;

create or replace procedure data_warehouse.silver.load_silver()
returns string
language sql
as
$$
declare
    batch_start_time    timestamp_ntz;
    batch_end_time      timestamp_ntz;
    start_time          timestamp_ntz;
    end_time            timestamp_ntz;
    loaded_rows         integer;
begin
    batch_start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: start');

    -- CRM Tables
    SYSTEM$LOG_INFO('LOAD_SILVER: === Loading CRM Tables ===');

    -- crm_cust_info
    -- 顧客IDがNULLの行は除外し、同じ顧客IDが複数ある場合は作成日が最も新しい1行だけを残す。
    -- 氏名は前後の空白を除去し、婚姻状態(M/S)と性別(F/M)のコードを表記へ展開する。
    -- 想定外のコード・空欄・NULLは 'n/a' とする。
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.CRM_CUST_INFO');
    TRUNCATE TABLE data_warehouse.silver.crm_cust_info;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.CRM_CUST_INFO');
    INSERT INTO
        data_warehouse.silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            ELSE 'n/a'
        END AS cst_marital_status,
        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            ELSE 'n/a'
        END AS cst_gndr,
        cst_create_date
    FROM
        data_warehouse.bronze.crm_cust_info
    WHERE
        cst_id IS NOT NULL
    QUALIFY
        ROW_NUMBER() OVER (
            PARTITION BY cst_id
            -- SnowflakeはDESCでNULLを先頭に並べるため、作成日のない行を最新として選ばないよう明示する
            ORDER BY cst_create_date DESC NULLS LAST
        ) = 1;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: CRM_CUST_INFO loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- crm_prd_info
    -- ソースの商品キー(例: CO-RF-FR-R92B-58)は、先頭5文字がカテゴリ、7文字目以降が商品を表す。
    --   cat_id : 先頭5文字のハイフンをアンダースコアに置換(例: CO_RF)。erp_px_cat_g1v2.id と結合する
    --   prd_key: 7文字目以降(例: FR-R92B-58)。crm_sales_details.sls_prd_key と結合する
    -- 原価のNULLは0とし、商品ライン(M/R/S/T)のコードを表記へ展開する。
    -- 同じ商品キーに、原価などが異なる複数バージョンの行がある。ソースの終了日は開始日より前になるなど
    -- 整合しないため使わず、同じ商品キーを開始日順に並べ「次のバージョンの開始日の前日」で再計算する。
    --   例: 2011-07-01開始 → 2012-06-30終了、2012-07-01開始 → 2013-06-30終了、2013-07-01開始 → NULL
    -- 最新バージョンは終了日がNULLになり、Goldの dim_products はこれを現行の商品として扱う。
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.CRM_PRD_INFO');
    TRUNCATE TABLE data_warehouse.silver.crm_prd_info;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.CRM_PRD_INFO');
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
            LEAD(prd_start_dt, 1) OVER (
                PARTITION BY prd_key
                ORDER BY prd_start_dt ASC
            )
        ) AS prd_end_dt
    FROM
        data_warehouse.bronze.crm_prd_info;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: CRM_PRD_INFO loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- crm_sales_details
    -- 日付はソースで整数(YYYYMMDD)のため、DATEへ変換する。0以下や8桁でない値はNULLとする。
    -- 売上・単価は「売上 = 数量 × 単価」が成り立つよう補正する。
    --   売上: NULL・0以下・数量×単価と不一致の場合は、数量×|単価| で置き換える(単価を正とみなす)
    --   単価: NULL・0以下の場合は、売上÷数量で補う。割り切れない場合はINT列への格納時に
    --         四捨五入される(SQL Serverの整数除算は切り捨てで、元教材と結果が異なり得る)
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.CRM_SALES_DETAILS');
    TRUNCATE TABLE data_warehouse.silver.crm_sales_details;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.CRM_SALES_DETAILS');
    INSERT INTO
        data_warehouse.silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE
            WHEN sls_order_dt <= 0
            OR LEN(sls_order_dt) != 8 THEN NULL
            ELSE TO_DATE(sls_order_dt::VARCHAR, 'YYYYMMDD')
        END AS sls_order_dt,
        CASE
            WHEN sls_ship_dt <= 0
            OR LEN(sls_ship_dt) != 8 THEN NULL
            ELSE TO_DATE(sls_ship_dt::VARCHAR, 'YYYYMMDD')
        END AS sls_ship_dt,
        CASE
            WHEN sls_due_dt <= 0
            OR LEN(sls_due_dt) != 8 THEN NULL
            ELSE TO_DATE(sls_due_dt::VARCHAR, 'YYYYMMDD')
        END AS sls_due_dt,
        CASE
            WHEN sls_sales IS NULL
            OR sls_sales <= 0
            OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales,
        sls_quantity,
        CASE
            WHEN sls_price IS NULL
            OR sls_price <= 0 THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END AS sls_price
    FROM
        data_warehouse.bronze.crm_sales_details;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: CRM_SALES_DETAILS loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- ERP Tables
    SYSTEM$LOG_INFO('LOAD_SILVER: === Loading ERP Tables ===');

    -- erp_cust_az12
    -- 顧客IDの一部に付く接頭辞 'NAS' を除去し(例: NASAW00011000 → AW00011000)、
    -- crm_cust_info.cst_key と結合できる形式へ揃える。
    -- 未来の生年月日は不正値としてNULLにする。古い生年月日は補正せず保持する。
    -- 性別はM/MALE、F/FEMALEを表記へ統一し、それ以外・空欄・NULLは 'n/a' とする。
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.ERP_CUST_AZ12');
    TRUNCATE TABLE data_warehouse.silver.erp_cust_az12;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.ERP_CUST_AZ12');
    INSERT INTO
        data_warehouse.silver.erp_cust_az12 (cid, bdate, gen)
    SELECT
        IFF(cid LIKE 'NASAW%', SUBSTR(cid, 4, LEN(cid)), cid) AS cid,
        IFF(bdate > CURRENT_DATE(), NULL, bdate) AS bdate,
        CASE
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            ELSE 'n/a'
        END AS gen
    FROM
        data_warehouse.bronze.erp_cust_az12;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: ERP_CUST_AZ12 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- erp_loc_a101
    -- 顧客IDのハイフンを除去し(例: AW-00011000 → AW00011000)、crm_cust_info.cst_key と結合できる形式へ揃える。
    -- 国はコード(DE、US、USA)を国名へ統一し、空欄・NULLは 'n/a' とする。それ以外は前後の空白だけ除去する。
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.ERP_LOC_A101');
    TRUNCATE TABLE data_warehouse.silver.erp_loc_a101;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.ERP_LOC_A101');
    INSERT INTO
        data_warehouse.silver.erp_loc_a101 (cid, cntry)
    SELECT
        REPLACE(cid, '-', '') AS cid,
        CASE
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = ''
            OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(cntry)
        END AS cntry
    FROM
        data_warehouse.bronze.erp_loc_a101;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: ERP_LOC_A101 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- erp_px_cat_g1v2
    -- 空白や表記揺れが見つかっていないため、変換せずにコピーする。IDは crm_prd_info.cat_id と同じ形式(例: AC_BR)。
    start_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: Truncating SILVER.ERP_PX_CAT_G1V2');
    TRUNCATE TABLE data_warehouse.silver.erp_px_cat_g1v2;
    SYSTEM$LOG_INFO('LOAD_SILVER: Inserting into SILVER.ERP_PX_CAT_G1V2');
    INSERT INTO
        data_warehouse.silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT
        id,
        cat,
        subcat,
        maintenance
    FROM
        data_warehouse.bronze.erp_px_cat_g1v2;
    loaded_rows := SQLROWCOUNT;
    end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: ERP_PX_CAT_G1V2 loaded ' || :loaded_rows || ' rows in ' || round(datediff(millisecond, start_time, end_time) / 1000.0, 3) || 's');

    -- 完了
    batch_end_time := current_timestamp();
    SYSTEM$LOG_INFO('LOAD_SILVER: completed in ' || round(datediff(millisecond, batch_start_time, batch_end_time) / 1000.0, 3) || 's');

    RETURN 'SUCCESS';

exception
when other then
    SYSTEM$LOG_ERROR('LOAD_SILVER: failed - ' || SQLERRM || ' (code: ' || SQLCODE || ')');
    RETURN 'ERROR: ' || SQLERRM;
end;
$$;
