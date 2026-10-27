
-- ============================================================
-- E-COMMERCE ANALYTICS ENGINEERING
-- Script: 04_add_ingested_at.sql
-- Purpose: Safely migrate RAW tables to include ingestion
--          timestamps for lineage and incremental processing.
--
-- ingested_at:
--   The time a record entered the RAW layer.
--
-- IMPORTANT:
--   - Connect to ecommerce_analytics before running.
--   - Existing NULL values are backfilled with migration time.
--   - Backfilled values do not represent original ingestion time.
--   - This migration does not modify business/event timestamps.
-- ============================================================


-- ============================================================
-- 1. ENSURE THE RAW SCHEMA EXISTS
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;


-- ============================================================
-- 2. ADD COLUMNS ONLY WHEN MISSING
-- ============================================================

ALTER TABLE raw.customers
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMP;

ALTER TABLE raw.products
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMP;

ALTER TABLE raw.orders
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMP;

ALTER TABLE raw.order_items
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMP;

ALTER TABLE raw.payments
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMP;

ALTER TABLE raw.shipments
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMP;

ALTER TABLE raw.returns
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMP;


-- ============================================================
-- 3. BACKFILL EXISTING NULL VALUES
-- ============================================================
-- These values represent migration time, not original ingestion.
-- ============================================================

UPDATE raw.customers
SET ingested_at = CURRENT_TIMESTAMP
WHERE ingested_at IS NULL;

UPDATE raw.products
SET ingested_at = CURRENT_TIMESTAMP
WHERE ingested_at IS NULL;

UPDATE raw.orders
SET ingested_at = CURRENT_TIMESTAMP
WHERE ingested_at IS NULL;

UPDATE raw.order_items
SET ingested_at = CURRENT_TIMESTAMP
WHERE ingested_at IS NULL;

UPDATE raw.payments
SET ingested_at = CURRENT_TIMESTAMP
WHERE ingested_at IS NULL;

UPDATE raw.shipments
SET ingested_at = CURRENT_TIMESTAMP
WHERE ingested_at IS NULL;

UPDATE raw.returns
SET ingested_at = CURRENT_TIMESTAMP
WHERE ingested_at IS NULL;


-- ============================================================
-- 4. SET DEFAULTS AND REQUIRE NON-NULL VALUES
-- ============================================================

ALTER TABLE raw.customers
    ALTER COLUMN ingested_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN ingested_at SET NOT NULL;

ALTER TABLE raw.products
    ALTER COLUMN ingested_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN ingested_at SET NOT NULL;

ALTER TABLE raw.orders
    ALTER COLUMN ingested_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN ingested_at SET NOT NULL;

ALTER TABLE raw.order_items
    ALTER COLUMN ingested_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN ingested_at SET NOT NULL;

ALTER TABLE raw.payments
    ALTER COLUMN ingested_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN ingested_at SET NOT NULL;

ALTER TABLE raw.shipments
    ALTER COLUMN ingested_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN ingested_at SET NOT NULL;

ALTER TABLE raw.returns
    ALTER COLUMN ingested_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN ingested_at SET NOT NULL;


-- ============================================================
-- 5. VALIDATE INGESTION TIMESTAMPS
-- ============================================================

SELECT
    table_name,
    total_records,
    records_with_ingested_at,
    missing_ingested_at,
    CASE
        WHEN missing_ingested_at = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM (
    SELECT
        'customers' AS table_name,
        COUNT(*) AS total_records,
        COUNT(ingested_at) AS records_with_ingested_at,
        COUNT(*) - COUNT(ingested_at) AS missing_ingested_at
    FROM raw.customers

    UNION ALL

    SELECT
        'products',
        COUNT(*),
        COUNT(ingested_at),
        COUNT(*) - COUNT(ingested_at)
    FROM raw.products

    UNION ALL

    SELECT
        'orders',
        COUNT(*),
        COUNT(ingested_at),
        COUNT(*) - COUNT(ingested_at)
    FROM raw.orders

    UNION ALL

    SELECT
        'order_items',
        COUNT(*),
        COUNT(ingested_at),
        COUNT(*) - COUNT(ingested_at)
    FROM raw.order_items

    UNION ALL

    SELECT
        'payments',
        COUNT(*),
        COUNT(ingested_at),
        COUNT(*) - COUNT(ingested_at)
    FROM raw.payments

    UNION ALL

    SELECT
        'shipments',
        COUNT(*),
        COUNT(ingested_at),
        COUNT(*) - COUNT(ingested_at)
    FROM raw.shipments

    UNION ALL

    SELECT
        'returns',
        COUNT(*),
        COUNT(ingested_at),
        COUNT(*) - COUNT(ingested_at)
    FROM raw.returns
) AS ingestion_validation
ORDER BY table_name;


-- ============================================================
-- 6. VERIFY COLUMN CONFIGURATION
-- ============================================================

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND column_name = 'ingested_at'
ORDER BY table_name;


-- ============================================================
-- END OF INGESTION TIMESTAMP MIGRATION
-- ============================================================
