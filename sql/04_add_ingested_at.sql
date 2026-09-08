-- ============================================================
-- RAW INGESTION TIMESTAMP MIGRATION
-- ============================================================
--
-- Purpose:
--   Add and configure ingested_at timestamps for RAW tables.
--
-- ingested_at represents the time when a record was loaded
-- into the RAW layer.
--
-- It is different from business/event timestamps such as:
--   - signup_date
--   - order_date
--   - payment_date
--   - return_date
--   - shipped_at
--   - delivered_at
--
-- ingested_at is primarily used for:
--   - dbt source freshness checks
--   - incremental processing
--   - identifying late-arriving data
--   - identifying ingestion batches
--
-- IMPORTANT:
-- This migration is intended for an existing database where
-- ingested_at has not yet been created.
--
-- If ingested_at already exists, DO NOT run this migration.
-- ============================================================


-- ============================================================
-- 1. ADD INGESTION TIMESTAMP COLUMNS
-- ============================================================

-- Customers
ALTER TABLE raw.customers
ADD COLUMN ingested_at TIMESTAMP;


-- Products
ALTER TABLE raw.products
ADD COLUMN ingested_at TIMESTAMP;


-- Orders
ALTER TABLE raw.orders
ADD COLUMN ingested_at TIMESTAMP;


-- Order Items
ALTER TABLE raw.order_items
ADD COLUMN ingested_at TIMESTAMP;


-- Payments
ALTER TABLE raw.payments
ADD COLUMN ingested_at TIMESTAMP;


-- Shipments
ALTER TABLE raw.shipments
ADD COLUMN ingested_at TIMESTAMP;


-- Returns
ALTER TABLE raw.returns
ADD COLUMN ingested_at TIMESTAMP;


-- ============================================================
-- 2. BACKFILL EXISTING RECORDS
-- ============================================================
--
-- Existing records do not have an ingestion timestamp because
-- the column was added after the records already existed.
--
-- We therefore populate NULL values with the current timestamp.
--
-- NOTE:
-- This is a migration-time timestamp, not the original historical
-- ingestion time.
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
-- 3. SET DEFAULT FOR FUTURE RECORDS
-- ============================================================
--
-- If a future INSERT does not explicitly provide ingested_at,
-- PostgreSQL automatically assigns the current timestamp.
-- ============================================================


ALTER TABLE raw.customers
ALTER COLUMN ingested_at
SET DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE raw.products
ALTER COLUMN ingested_at
SET DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE raw.orders
ALTER COLUMN ingested_at
SET DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE raw.order_items
ALTER COLUMN ingested_at
SET DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE raw.payments
ALTER COLUMN ingested_at
SET DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE raw.shipments
ALTER COLUMN ingested_at
SET DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE raw.returns
ALTER COLUMN ingested_at
SET DEFAULT CURRENT_TIMESTAMP;


-- ============================================================
-- 4. MAKE INGESTION TIMESTAMP REQUIRED
-- ============================================================
--
-- After backfilling existing records and configuring the
-- default value, ingested_at can safely be made NOT NULL.
--
-- This guarantees that every future RAW record has an
-- ingestion timestamp.
-- ============================================================


ALTER TABLE raw.customers
ALTER COLUMN ingested_at
SET NOT NULL;


ALTER TABLE raw.products
ALTER COLUMN ingested_at
SET NOT NULL;


ALTER TABLE raw.orders
ALTER COLUMN ingested_at
SET NOT NULL;


ALTER TABLE raw.order_items
ALTER COLUMN ingested_at
SET NOT NULL;


ALTER TABLE raw.payments
ALTER COLUMN ingested_at
SET NOT NULL;


ALTER TABLE raw.shipments
ALTER COLUMN ingested_at
SET NOT NULL;


ALTER TABLE raw.returns
ALTER COLUMN ingested_at
SET NOT NULL;


-- ============================================================
-- 5. VALIDATION
-- ============================================================
--
-- Verify that every RAW table now has:
--   - ingested_at column
--   - no NULL ingestion timestamps
-- ============================================================


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
FROM raw.returns;