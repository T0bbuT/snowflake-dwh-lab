USE DATABASE data_warehouse;

SELECT
    top 10 *
FROM
    bronze.erp_loc_a101;

SELECT
    COUNT(*)
FROM
    bronze.erp_loc_a101;