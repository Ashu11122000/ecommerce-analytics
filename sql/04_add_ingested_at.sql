-- These timestamps represent when records were
-- loaded into the raw layer.
-- They are used for dbt source freshness checks.

-- Add ingestion timestamp to customers
ALTER TABLE raw.customers
ADD COLUMN ingested_at TIMESTAMP;


-- Add ingestion timestamp to products
ALTER TABLE raw.products
ADD COLUMN ingested_at TIMESTAMP;


-- Add ingestion timestamp to orders
ALTER TABLE raw.orders
ADD COLUMN ingested_at TIMESTAMP;


-- Add ingestion timestamp to order_items
ALTER TABLE raw.order_items
ADD COLUMN ingested_at TIMESTAMP;

-- Backfill Existing Records
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

-- Set Default for Future Records
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

-- Make ingestion timestamp required
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