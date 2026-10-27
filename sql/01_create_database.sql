
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
-- IMPORTANT:
--   - Run this script while connected to an existing database,
--     such as postgres.
--   - PostgreSQL CREATE DATABASE cannot run inside a
--     transaction block.
--   - This script does not create schemas or tables.
--   - Connect to ecommerce_analytics after creation.
-- ============================================================

CREATE DATABASE ecommerce_analytics;
