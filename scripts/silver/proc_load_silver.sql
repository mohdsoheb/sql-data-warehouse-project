/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    Performs the ETL process to populate the Silver schema tables
    from the Bronze schema.

Actions:
    - Truncates Silver tables before loading.
    - Cleans and transforms data from Bronze tables.
    - Removes duplicate customer records.
    - Normalizes marital status, gender, product lines, and countries.
    - Validates dates and corrects invalid sales values.
    - Logs row counts, execution duration, and errors.

Usage:
    CALL silver.load_silver();

Prerequisites:
    - Bronze and Silver schemas already exist.
    - All six Bronze and Silver tables have been created.
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    start_time        TIMESTAMP;
    end_time          TIMESTAMP;
    batch_start_time  TIMESTAMP;
    batch_end_time    TIMESTAMP;
    row_count         BIGINT;
    err_message       TEXT;
    err_state         TEXT;
BEGIN
    batch_start_time := clock_timestamp();

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '================================================';


    ---------------------------------------------------------------------------
    -- Loading CRM Tables
    ---------------------------------------------------------------------------

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '------------------------------------------------';


    -- 1. CRM Customer Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;

    RAISE NOTICE '>> Inserting Data Into: silver.crm_cust_info';

    INSERT INTO silver.crm_cust_info (
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
        TRIM(cst_firstname),
        TRIM(cst_lastname),

        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'S'
                THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M'
                THEN 'Married'
            ELSE 'n/a'
        END,

        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'F'
                THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M'
                THEN 'Male'
            ELSE 'n/a'
        END,

        cst_create_date::DATE

    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY cst_id
                ORDER BY cst_create_date DESC NULLS LAST
            ) AS flag_last
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) AS t
    WHERE flag_last = 1;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    -- 2. CRM Product Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;

    RAISE NOTICE '>> Inserting Data Into: silver.crm_prd_info';

    INSERT INTO silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    WITH product_data AS (
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key FROM 1 FOR 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key FROM 7) AS prd_key,
            prd_nm,
            COALESCE(NULLIF(TRIM(prd_cost::TEXT), '')::INTEGER, 0)
                AS prd_cost,

            CASE
                WHEN UPPER(TRIM(prd_line)) = 'M'
                    THEN 'Mountain'
                WHEN UPPER(TRIM(prd_line)) = 'R'
                    THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'S'
                    THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T'
                    THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,

            NULLIF(TRIM(prd_start_dt::TEXT), '')::DATE AS prd_start_dt

        FROM bronze.crm_prd_info
    )
    SELECT
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,

        (
            LEAD(prd_start_dt) OVER (
                PARTITION BY prd_key
                ORDER BY prd_start_dt
            ) - 1
        )::DATE AS prd_end_dt

    FROM product_data;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    -- 3. CRM Sales Details
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;

    RAISE NOTICE '>> Inserting Data Into: silver.crm_sales_details';

    INSERT INTO silver.crm_sales_details (
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
            WHEN NULLIF(TRIM(sls_order_dt::TEXT), '') ~ '^[0-9]{8}$'
                 AND TRIM(sls_order_dt::TEXT) <> '00000000'
                THEN TO_DATE(TRIM(sls_order_dt::TEXT), 'YYYYMMDD')
            ELSE NULL
        END AS sls_order_dt,

        CASE
            WHEN NULLIF(TRIM(sls_ship_dt::TEXT), '') ~ '^[0-9]{8}$'
                 AND TRIM(sls_ship_dt::TEXT) <> '00000000'
                THEN TO_DATE(TRIM(sls_ship_dt::TEXT), 'YYYYMMDD')
            ELSE NULL
        END AS sls_ship_dt,

        CASE
            WHEN NULLIF(TRIM(sls_due_dt::TEXT), '') ~ '^[0-9]{8}$'
                 AND TRIM(sls_due_dt::TEXT) <> '00000000'
                THEN TO_DATE(TRIM(sls_due_dt::TEXT), 'YYYYMMDD')
            ELSE NULL
        END AS sls_due_dt,

        CASE
            WHEN sls_sales_num IS NULL
                 OR sls_sales_num <= 0
                 OR sls_sales_num <> sls_quantity_num * ABS(sls_price_num)
                THEN sls_quantity_num * ABS(sls_price_num)
            ELSE sls_sales_num
        END AS sls_sales,

        sls_quantity_num AS sls_quantity,

        CASE
            WHEN sls_price_num IS NULL OR sls_price_num <= 0
                THEN sls_sales_num / NULLIF(sls_quantity_num, 0)
            ELSE sls_price_num
        END AS sls_price

    FROM (
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            NULLIF(TRIM(sls_sales::TEXT), '')::INTEGER AS sls_sales_num,
            NULLIF(TRIM(sls_quantity::TEXT), '')::INTEGER AS sls_quantity_num,
            NULLIF(TRIM(sls_price::TEXT), '')::INTEGER AS sls_price_num
        FROM bronze.crm_sales_details
    ) AS sales_data;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    ---------------------------------------------------------------------------
    -- Loading ERP Tables
    ---------------------------------------------------------------------------

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '------------------------------------------------';


    -- 4. ERP Customer Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_cust_az12';

    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT
        CASE
            WHEN cid LIKE 'NAS%'
                THEN SUBSTRING(cid FROM 4)
            ELSE cid
        END AS cid,

        CASE
            WHEN bdate IS NULL OR bdate > CURRENT_DATE
                THEN NULL
            ELSE bdate
        END AS bdate,

        CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE')
                THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')
                THEN 'Male'
            ELSE 'n/a'
        END AS gen

    FROM bronze.erp_cust_az12;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    -- 5. ERP Location Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_loc_a101';

    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT
        REPLACE(cid, '-', '') AS cid,

        CASE
            WHEN UPPER(TRIM(cntry)) = 'DE'
                THEN 'Germany'
            WHEN UPPER(TRIM(cntry)) IN ('US', 'USA')
                THEN 'United States'
            WHEN cntry IS NULL OR TRIM(cntry) = ''
                THEN 'n/a'
            ELSE TRIM(cntry)
        END AS cntry

    FROM bronze.erp_loc_a101;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    -- 6. ERP Product Category Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_px_cat_g1v2';

    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT
        id,
        cat,
        subcat,
        maintenance
    FROM bronze.erp_px_cat_g1v2;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    ---------------------------------------------------------------------------
    -- Completion Summary
    ---------------------------------------------------------------------------

    batch_end_time := clock_timestamp();

    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Loading Silver Layer is Completed';
    RAISE NOTICE 'Total Load Duration: % seconds',
        ROUND(
            EXTRACT(EPOCH FROM (batch_end_time - batch_start_time))::NUMERIC,
            2
        );
    RAISE NOTICE '==========================================';


EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            err_message = MESSAGE_TEXT,
            err_state = RETURNED_SQLSTATE;

        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        RAISE NOTICE 'Error Message: %', err_message;
        RAISE NOTICE 'Error State (SQLSTATE): %', err_state;
        RAISE NOTICE '==========================================';

        -- Re-raise the error so the caller knows the load failed.
        RAISE;
END;
$$;


-- Execute the Silver Layer Load Procedure
CALL silver.load_silver();
