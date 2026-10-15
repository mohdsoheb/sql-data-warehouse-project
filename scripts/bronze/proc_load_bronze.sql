/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    Loads data into the 'bronze' schema from external CSV files.
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the COPY command to load CSV files into bronze tables.
    - Logs progress, row counts, and load duration for each table.
    - Handles errors and reports error details.

Parameters:
    None.

Usage Example:
    CALL bronze.load_bronze();

Note:
    - COPY reads files from the PostgreSQL SERVER filesystem.
    - The PostgreSQL service account must be able to read the files.
    - The database role needs appropriate permissions, such as superuser
      or pg_read_server_files.
    - Update the file paths to match your dataset directory.
===============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
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
    RAISE NOTICE 'Loading Bronze Layer';
    RAISE NOTICE '================================================';

    ---------------------------------------------------------------------------
    -- Loading CRM Tables
    ---------------------------------------------------------------------------

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '------------------------------------------------';

    -- 1. CRM Customer Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.crm_cust_info';
    TRUNCATE TABLE bronze.crm_cust_info;

    RAISE NOTICE '>> Inserting Data Into: bronze.crm_cust_info';

    COPY bronze.crm_cust_info
    FROM 'C:/sql/dwh_project/datasets/source_crm/cust_info.csv'
    WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    -- 2. CRM Product Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.crm_prd_info';
    TRUNCATE TABLE bronze.crm_prd_info;

    RAISE NOTICE '>> Inserting Data Into: bronze.crm_prd_info';

    COPY bronze.crm_prd_info
    FROM 'C:/sql/dwh_project/datasets/source_crm/prd_info.csv'
    WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    -- 3. CRM Sales Details
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.crm_sales_details';
    TRUNCATE TABLE bronze.crm_sales_details;

    RAISE NOTICE '>> Inserting Data Into: bronze.crm_sales_details';

    COPY bronze.crm_sales_details
    FROM 'C:/sql/dwh_project/datasets/source_crm/sales_details.csv'
    WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');

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

    -- 4. ERP Location Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.erp_loc_a101';
    TRUNCATE TABLE bronze.erp_loc_a101;

    RAISE NOTICE '>> Inserting Data Into: bronze.erp_loc_a101';

    COPY bronze.erp_loc_a101
    FROM 'C:/sql/dwh_project/datasets/source_erp/loc_a101.csv'
    WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    -- 5. ERP Customer Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.erp_cust_az12';
    TRUNCATE TABLE bronze.erp_cust_az12;

    RAISE NOTICE '>> Inserting Data Into: bronze.erp_cust_az12';

    COPY bronze.erp_cust_az12
    FROM 'C:/sql/dwh_project/datasets/source_erp/cust_az12.csv'
    WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Rows Loaded: %', row_count;
    RAISE NOTICE '>> Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';


    -- 6. ERP Product Category Information
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.erp_px_cat_g1v2';
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;

    RAISE NOTICE '>> Inserting Data Into: bronze.erp_px_cat_g1v2';

    COPY bronze.erp_px_cat_g1v2
    FROM 'C:/sql/dwh_project/datasets/source_erp/px_cat_g1v2.csv'
    WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');

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
    RAISE NOTICE 'Loading Bronze Layer is Completed';
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
            err_state   = RETURNED_SQLSTATE;

        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        RAISE NOTICE 'Error Message: %', err_message;
        RAISE NOTICE 'Error State (SQLSTATE): %', err_state;
        RAISE NOTICE '==========================================';

        -- Re-raise the error so the caller knows the load failed.
        RAISE;

END;
$$;


-- Execute the stored procedure
CALL bronze.load_bronze();
