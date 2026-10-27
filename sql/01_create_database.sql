-- ============================================================
-- E-COMMERCE ANALYTICS
-- Script: 01_create_database.sql
-- Purpose: Create the PostgreSQL database for the analytics
--          engineering pipeline.
--
-- Database layers:
--   1. RAW     - Source data
--   2. BRONZE  - Initial ingestion and standardization
--   3. SILVER  - Cleaned and validated data
--   4. GOLD    - Analytics-ready reporting models
--
-- EXECUTION REQUIREMENTS:
--   - Connect to an existing database, such as postgres.
--   - The executing user must have CREATEDB privileges.
--   - CREATE DATABASE must run outside a transaction block.
--   - PostgreSQL does not support CREATE DATABASE IF NOT EXISTS.
--   - If the target database already exists, do not recreate it.
--
-- SAFETY:
--   - This script does not drop or modify an existing database.
--   - It does not create schemas or tables.
--   - Connect to ecommerce_analytics after creation.
-- ============================================================

-- Check whether the database already exists before executing
-- this statement. If it exists, skip database creation.

CREATE DATABASE ecommerce_analytics
    WITH
        ENCODING = 'UTF8'
        TEMPLATE = template0;