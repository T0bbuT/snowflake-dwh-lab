/*
================================================================================
ログ確認用クエリ: Event Table からロードログを参照する
================================================================================
前提:
    - scripts/init_event_table.sql を事前に実行しておくこと
    - LOAD_BRONZE / LOAD_SILVER を少なくとも一度実行済みであること
    - Event Table への書き込みには数分のラグがある場合がある
================================================================================
*/

-- LOAD_BRONZE のログを時系列で表示
SELECT
    TIMESTAMP AS time,
    RECORD['severity_text']::STRING AS severity,
    VALUE::STRING AS message
FROM
    data_warehouse.staging.load_events
WHERE
    RESOURCE_ATTRIBUTES['snow.executable.name'] LIKE '%LOAD_BRONZE%'
    AND RECORD_TYPE = 'LOG'
ORDER BY
    TIMESTAMP DESC
LIMIT 100;

-- LOAD_SILVER のログを時系列で表示
SELECT
    TIMESTAMP AS time,
    RECORD['severity_text']::STRING AS severity,
    VALUE::STRING AS message
FROM
    data_warehouse.staging.load_events
WHERE
    RESOURCE_ATTRIBUTES['snow.executable.name'] LIKE '%LOAD_SILVER%'
    AND RECORD_TYPE = 'LOG'
ORDER BY
    TIMESTAMP DESC
LIMIT 100;

-- エラーログのみ抽出
SELECT
    TIMESTAMP AS time,
    RESOURCE_ATTRIBUTES['snow.executable.name']::STRING AS procedure_name,
    VALUE::STRING AS message
FROM
    data_warehouse.staging.load_events
WHERE
    RECORD_TYPE = 'LOG'
    AND RECORD['severity_text']::STRING = 'ERROR'
ORDER BY
    TIMESTAMP DESC
LIMIT 50;
