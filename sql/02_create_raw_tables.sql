-- ============================================================
-- E-COMMERCE ANALYTICS ENGINEERING
-- Script: 02_create_raw_tables.sql
-- Purpose: Create source-aligned tables in the RAW schema.
-- Database: ecommerce_analytics
--
-- Pipeline:
--   RAW -> BRONZE -> SILVER -> GOLD -> SEMANTIC LAYER -> BI
--
-- Tables:
--   1. raw.customers
--   2. raw.products
--   3. raw.orders
--   4. raw.order_items
--   5. raw.payments
--   6. raw.shipments
--   7. raw.returns
--
-- Design principles:
--   - Preserve source-oriented column names and data types.
--   - Maintain primary keys for record identification.
--   - Validate referential integrity downstream in dbt.
--   - Preserve source-quality anomalies in the RAW layer.
--   - Keep business transformations in dbt.
--   - Use updated_at for source modification tracking.
--   - Use ingested_at for warehouse ingestion tracking.
--
-- SAFETY:
--   - Connect to ecommerce_analytics before execution.
--   - CREATE TABLE IF NOT EXISTS does not modify existing tables.
--   - This script does not drop, truncate, or reload data.
--   - Index creation is safe to rerun.
--   - Existing table definitions must be checked separately.
-- ============================================================


-- ============================================================
-- 1. RAW SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;


-- ============================================================
-- 2. CUSTOMERS
-- Grain: One row per source customer.
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id       INTEGER PRIMARY KEY,
    customer_name     VARCHAR(100) NOT NULL,
    email             VARCHAR(150) NOT NULL UNIQUE,
    phone             VARCHAR(20),
    gender            VARCHAR(20),
    date_of_birth     DATE,
    city              VARCHAR(100),
    state             VARCHAR(100),
    country           VARCHAR(100),
    postal_code       VARCHAR(10),
    customer_segment  VARCHAR(30),
    customer_status   VARCHAR(30),
    signup_date       DATE NOT NULL,
    updated_at        TIMESTAMP,
    ingested_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 3. PRODUCTS
-- Grain: One row per source product.
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.products (
    product_id       INTEGER PRIMARY KEY,
    product_name     VARCHAR(150) NOT NULL,
    category         VARCHAR(100) NOT NULL,
    subcategory      VARCHAR(100),
    brand            VARCHAR(100),
    supplier_id      INTEGER,
    cost_price       NUMERIC(12, 2),
    selling_price    NUMERIC(12, 2),
    stock_quantity   INTEGER,
    reorder_level    INTEGER,
    product_status   VARCHAR(30),
    launch_date      DATE,
    updated_at       TIMESTAMP,
    ingested_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 4. ORDERS
-- Grain: One row per source order.
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id          INTEGER PRIMARY KEY,
    customer_id       INTEGER NOT NULL,
    order_date        TIMESTAMP NOT NULL,
    order_status      VARCHAR(50) NOT NULL,
    payment_status    VARCHAR(50),
    shipping_method   VARCHAR(50),
    shipping_cost     NUMERIC(12, 2),
    discount_amount   NUMERIC(12, 2),
    tax_amount        NUMERIC(12, 2),
    total_amount      NUMERIC(14, 2),
    sales_channel     VARCHAR(50),
    currency          VARCHAR(10),
    updated_at        TIMESTAMP,
    ingested_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 5. ORDER ITEMS
-- Grain: One row per order line item.
--
-- Do not add restrictive quantity or financial CHECK
-- constraints here. Invalid source records must remain
-- available for downstream quality checks.
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_item_id      INTEGER PRIMARY KEY,
    order_id           INTEGER NOT NULL,
    product_id         INTEGER NOT NULL,
    quantity           INTEGER NOT NULL,
    unit_price         NUMERIC(12, 2) NOT NULL,
    discount_amount    NUMERIC(12, 2),
    tax_amount         NUMERIC(12, 2),
    line_total         NUMERIC(14, 2),
    returned_quantity  INTEGER,
    updated_at         TIMESTAMP,
    ingested_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 6. PAYMENTS
-- Grain: One row per payment transaction.
-- An order may have multiple payment records.
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.payments (
    payment_id             INTEGER PRIMARY KEY,
    order_id               INTEGER NOT NULL,
    payment_date           TIMESTAMP NOT NULL,
    payment_method         VARCHAR(50) NOT NULL,
    payment_status         VARCHAR(50) NOT NULL,
    amount                 NUMERIC(14, 2) NOT NULL,
    transaction_reference  VARCHAR(100),
    updated_at             TIMESTAMP,
    ingested_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 7. SHIPMENTS
-- Grain: One row per shipment record.
-- An order may have multiple shipment records.
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.shipments (
    shipment_id      INTEGER PRIMARY KEY,
    order_id         INTEGER NOT NULL,
    shipping_method  VARCHAR(50) NOT NULL,
    shipment_status  VARCHAR(50) NOT NULL,
    shipped_at       TIMESTAMP,
    delivered_at     TIMESTAMP,
    delivery_city    VARCHAR(100),
    delivery_state   VARCHAR(100),
    updated_at       TIMESTAMP,
    ingested_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 8. RETURNS
-- Grain: One row per return record.
-- An order item may have multiple return records.
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.returns (
    return_id        INTEGER PRIMARY KEY,
    order_item_id    INTEGER NOT NULL,
    return_date      TIMESTAMP NOT NULL,
    return_reason    VARCHAR(100) NOT NULL,
    return_quantity  INTEGER NOT NULL,
    refund_amount    NUMERIC(14, 2) NOT NULL,
    return_status    VARCHAR(50) NOT NULL,
    updated_at       TIMESTAMP,
    ingested_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 9. INDEXES
--
-- Primary-key and UNIQUE constraints already create indexes.
-- These additional indexes support common joins and filters.
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_orders_customer_id
    ON raw.orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_order_date
    ON raw.orders (order_date);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON raw.order_items (order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON raw.order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_payments_order_id
    ON raw.payments (order_id);

CREATE INDEX IF NOT EXISTS idx_payments_payment_date
    ON raw.payments (payment_date);

CREATE INDEX IF NOT EXISTS idx_shipments_order_id
    ON raw.shipments (order_id);

CREATE INDEX IF NOT EXISTS idx_returns_order_item_id
    ON raw.returns (order_item_id);

CREATE INDEX IF NOT EXISTS idx_returns_return_date
    ON raw.returns (return_date);


-- ============================================================
-- 10. SCHEMA VALIDATION
--
-- Display the expected RAW tables and whether each exists.
-- This validation does not modify data.
-- ============================================================

WITH expected_tables (table_name) AS (
    VALUES
        ('customers'),
        ('products'),
        ('orders'),
        ('order_items'),
        ('payments'),
        ('shipments'),
        ('returns')
)
SELECT
    'raw' AS table_schema,
    e.table_name,
    CASE
        WHEN t.table_name IS NOT NULL THEN 'PRESENT'
        ELSE 'MISSING'
    END AS validation_status
FROM expected_tables AS e
LEFT JOIN information_schema.tables AS t
    ON t.table_schema = 'raw'
   AND t.table_name = e.table_name
   AND t.table_type = 'BASE TABLE'
ORDER BY e.table_name;


-- ============================================================
-- 11. COLUMN VALIDATION
--
-- List the actual columns of all RAW tables.
-- Useful for checking the schema before dbt transformations.
-- ============================================================

SELECT
    table_schema,
    table_name,
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'raw'
ORDER BY
    table_name,
    ordinal_position;


-- ============================================================
-- END OF RAW TABLE CREATION
-- ============================================================