/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    Creates a new database named 'datawarehouse'. If it already
    exists, it is dropped and recreated. Then sets up three
    schemas: 'bronze', 'silver', and 'gold'.

WARNING:
    Running this script drops the entire 'datawarehouse' database
    if it exists. All data will be permanently deleted. Ensure
    you have backups before running.

Usage (psql):
    psql -U postgres -d postgres -f scripts/init_database.sql
    (Run while connected to 'postgres', not 'datawarehouse'.)

Note for pgAdmin users:
    \connect works only in psql. In pgAdmin, run the database
    statements first, then open a Query Tool on 'datawarehouse'
    and run the CREATE SCHEMA statements separately.
*/

-- Disconnect anyone currently using the database
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'datawarehouse'
  AND pid <> pg_backend_pid();

-- Drop and recreate the database
DROP DATABASE IF EXISTS datawarehouse;
CREATE DATABASE datawarehouse;

-- Switch into the new database (psql only)
\connect datawarehouse

-- Create the medallion layers
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
