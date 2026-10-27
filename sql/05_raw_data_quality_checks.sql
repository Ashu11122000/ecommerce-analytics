-- ============================================================
-- E-COMMERCE ANALYTICS ENGINEERING
-- Script: 05_raw_data_quality_checks.sql
-- Database: ecommerce_analytics
-- Schema: raw
--
-- Purpose:
--   Validate raw data quality before dbt transformations.
--
-- Checks:
--   1. Row counts
--   2. Duplicate primary keys
--   3. Missing relationships
--   4. Invalid order-item values
--   5. Invalid product values
--   6. Invalid payment and return values
--   7. Date consistency
--   8. Missing or blank business fields
--   9. Order-total reconciliation
--  10. Status distributions
--  11. Multiple payments and shipments
--  12. Ingestion timestamp coverage
--  13. Missing financial values
--  14. Duplicate customer emails
--  15. Return reconciliation
--
-- IMPORTANT:
--   - Read-only: this script does not modify data.
--   - Review diagnostic results before treating them as errors.
--   - Synthetic data may intentionally contain anomalies.
--   - Raw anomalies should be handled explicitly in dbt.
-- ============================================================


-- ============================================================
-- 1. ROW COUNTS
-- ============================================================

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM raw.customers

UNION ALL

SELECT 'products', COUNT(*)
FROM raw.products

UNION ALL

SELECT 'orders', COUNT(*)
FROM raw.orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM raw.order_items

UNION ALL

SELECT 'payments', COUNT(*)
FROM raw.payments

UNION ALL

SELECT 'shipments', COUNT(*)
FROM raw.shipments

UNION ALL

SELECT 'returns', COUNT(*)
FROM raw.returns

ORDER BY table_name;


-- ============================================================
-- 2. DUPLICATE PRIMARY KEYS
-- Expected: zero rows for each query.
-- Primary-key constraints should also prevent these duplicates.
-- ============================================================

SELECT customer_id, COUNT(*) AS occurrences
FROM raw.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT product_id, COUNT(*) AS occurrences
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1;

SELECT order_id, COUNT(*) AS occurrences
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT order_item_id, COUNT(*) AS occurrences
FROM raw.order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;

SELECT payment_id, COUNT(*) AS occurrences
FROM raw.payments
GROUP BY payment_id
HAVING COUNT(*) > 1;

SELECT shipment_id, COUNT(*) AS occurrences
FROM raw.shipments
GROUP BY shipment_id
HAVING COUNT(*) > 1;

SELECT return_id, COUNT(*) AS occurrences
FROM raw.returns
GROUP BY return_id
HAVING COUNT(*) > 1;


-- ============================================================
-- 3. MISSING RELATIONSHIPS
-- Expected: zero rows for valid relationships.
-- These checks do not require physical foreign-key constraints.
-- ============================================================

-- Orders without a matching customer
SELECT
    o.order_id,
    o.customer_id,
    'MISSING_CUSTOMER' AS issue
FROM raw.orders AS o
LEFT JOIN raw.customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items without a matching order
SELECT
    oi.order_item_id,
    oi.order_id,
    'MISSING_ORDER' AS issue
FROM raw.order_items AS oi
LEFT JOIN raw.orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items without a matching product
SELECT
    oi.order_item_id,
    oi.product_id,
    'MISSING_PRODUCT' AS issue
FROM raw.order_items AS oi
LEFT JOIN raw.products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Payments without a matching order
SELECT
    p.payment_id,
    p.order_id,
    'MISSING_ORDER' AS issue
FROM raw.payments AS p
LEFT JOIN raw.orders AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Shipments without a matching order
SELECT
    s.shipment_id,
    s.order_id,
    'MISSING_ORDER' AS issue
FROM raw.shipments AS s
LEFT JOIN raw.orders AS o
    ON s.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Returns without a matching order item
SELECT
    r.return_id,
    r.order_item_id,
    'MISSING_ORDER_ITEM' AS issue
FROM raw.returns AS r
LEFT JOIN raw.order_items AS oi
    ON r.order_item_id = oi.order_item_id
WHERE oi.order_item_id IS NULL;


-- ============================================================
-- 4. INVALID ORDER-ITEM VALUES
-- Review all returned records.
-- ============================================================

SELECT
    oi.*,
    CASE
        WHEN quantity <= 0
            THEN 'INVALID_QUANTITY'
        WHEN unit_price < 0
            THEN 'NEGATIVE_UNIT_PRICE'
        WHEN discount_amount < 0
            THEN 'NEGATIVE_DISCOUNT'
        WHEN tax_amount < 0
            THEN 'NEGATIVE_TAX'
        WHEN line_total < 0
            THEN 'NEGATIVE_LINE_TOTAL'
        WHEN returned_quantity < 0
            THEN 'NEGATIVE_RETURNED_QUANTITY'
    END AS issue
FROM raw.order_items AS oi
WHERE quantity <= 0
   OR unit_price < 0
   OR discount_amount < 0
   OR tax_amount < 0
   OR line_total < 0
   OR returned_quantity < 0
ORDER BY order_item_id;


-- Returned quantity greater than ordered quantity.
-- Invalid negative quantities are also reported by this check.
SELECT
    order_item_id,
    quantity,
    returned_quantity,
    'RETURNED_QUANTITY_EXCEEDS_ORDERED_QUANTITY' AS issue
FROM raw.order_items
WHERE returned_quantity > quantity
ORDER BY order_item_id;


-- Missing financial or quantity values that are allowed by
-- the current table definition.
SELECT
    order_item_id,
    quantity,
    unit_price,
    discount_amount,
    tax_amount,
    line_total,
    returned_quantity
FROM raw.order_items
WHERE unit_price IS NULL
   OR discount_amount IS NULL
   OR tax_amount IS NULL
   OR line_total IS NULL
   OR returned_quantity IS NULL
ORDER BY order_item_id;


-- ============================================================
-- 5. INVALID PRODUCT VALUES
-- ============================================================

SELECT
    product_id,
    product_name,
    cost_price,
    selling_price,
    stock_quantity,
    reorder_level
FROM raw.products
WHERE cost_price < 0
   OR selling_price < 0
   OR stock_quantity < 0
   OR reorder_level < 0
ORDER BY product_id;


-- Products whose cost exceeds their selling price.
-- This is a business review, not necessarily a data error.
SELECT
    product_id,
    product_name,
    category,
    cost_price,
    selling_price,
    selling_price - cost_price AS unit_margin
FROM raw.products
WHERE cost_price > selling_price
ORDER BY unit_margin;


-- Missing product financial or inventory values.
SELECT
    product_id,
    product_name,
    cost_price,
    selling_price,
    stock_quantity,
    reorder_level
FROM raw.products
WHERE cost_price IS NULL
   OR selling_price IS NULL
   OR stock_quantity IS NULL
   OR reorder_level IS NULL
ORDER BY product_id;


-- ============================================================
-- 6. INVALID PAYMENT VALUES
-- ============================================================

SELECT
    payment_id,
    order_id,
    payment_date,
    payment_status,
    amount,
    CASE
        WHEN amount < 0 THEN 'NEGATIVE_PAYMENT_AMOUNT'
        WHEN amount = 0 THEN 'ZERO_PAYMENT_AMOUNT'
    END AS issue
FROM raw.payments
WHERE amount <= 0
ORDER BY payment_id;


-- Payments with missing transaction references.
-- References may be optional depending on the payment method.
SELECT
    payment_id,
    order_id,
    payment_method,
    payment_status,
    transaction_reference
FROM raw.payments
WHERE transaction_reference IS NULL
   OR NULLIF(TRIM(transaction_reference), '') IS NULL
ORDER BY payment_id;


-- ============================================================
-- 7. INVALID RETURN VALUES
-- ============================================================

SELECT
    return_id,
    order_item_id,
    return_quantity,
    refund_amount,
    return_status,
    CASE
        WHEN return_quantity <= 0
            THEN 'INVALID_RETURN_QUANTITY'
        WHEN refund_amount < 0
            THEN 'NEGATIVE_REFUND_AMOUNT'
        WHEN refund_amount = 0
            THEN 'ZERO_REFUND_AMOUNT'
    END AS issue
FROM raw.returns
WHERE return_quantity <= 0
   OR refund_amount <= 0
ORDER BY return_id;


-- Return quantities exceeding the ordered quantity.
-- This check is at individual return-record grain.
SELECT
    r.return_id,
    r.order_item_id,
    r.return_quantity,
    oi.quantity AS ordered_quantity
FROM raw.returns AS r
JOIN raw.order_items AS oi
    ON r.order_item_id = oi.order_item_id
WHERE r.return_quantity > oi.quantity
ORDER BY r.return_id;


-- Total quantity across return records exceeding ordered quantity.
-- Important when an order item has multiple return records.
SELECT
    oi.order_item_id,
    oi.quantity AS ordered_quantity,
    SUM(r.return_quantity) AS total_returned_quantity
FROM raw.order_items AS oi
JOIN raw.returns AS r
    ON r.order_item_id = oi.order_item_id
GROUP BY
    oi.order_item_id,
    oi.quantity
HAVING SUM(r.return_quantity) > oi.quantity
ORDER BY oi.order_item_id;


-- ============================================================
-- 8. DATE CONSISTENCY
-- Review results; some cases may be legitimate.
-- ============================================================

-- Orders updated before their order date.
SELECT
    order_id,
    order_date,
    updated_at
FROM raw.orders
WHERE updated_at IS NOT NULL
  AND updated_at < order_date
ORDER BY order_id;


-- Customers updated before signup date.
SELECT
    customer_id,
    signup_date,
    updated_at
FROM raw.customers
WHERE updated_at IS NOT NULL
  AND updated_at::date < signup_date
ORDER BY customer_id;


-- Products launched after their update timestamp.
SELECT
    product_id,
    launch_date,
    updated_at
FROM raw.products
WHERE launch_date IS NOT NULL
  AND updated_at IS NOT NULL
  AND updated_at::date < launch_date
ORDER BY product_id;


-- Shipments delivered before they were shipped.
SELECT
    shipment_id,
    shipped_at,
    delivered_at
FROM raw.shipments
WHERE shipped_at IS NOT NULL
  AND delivered_at IS NOT NULL
  AND delivered_at < shipped_at
ORDER BY shipment_id;


-- Delivered timestamps without a shipment timestamp.
SELECT
    shipment_id,
    shipment_status,
    shipped_at,
    delivered_at
FROM raw.shipments
WHERE delivered_at IS NOT NULL
  AND shipped_at IS NULL
ORDER BY shipment_id;


-- Returns dated before the associated order.
SELECT
    r.return_id,
    r.return_date,
    o.order_date
FROM raw.returns AS r
JOIN raw.order_items AS oi
    ON r.order_item_id = oi.order_item_id
JOIN raw.orders AS o
    ON oi.order_id = o.order_id
WHERE r.return_date < o.order_date
ORDER BY r.return_id;


-- Events occurring after their ingestion timestamp.
-- Review only; source and warehouse clocks may differ.
SELECT
    'orders' AS table_name,
    order_id::TEXT AS record_id,
    order_date AS event_timestamp,
    ingested_at
FROM raw.orders
WHERE order_date > ingested_at

UNION ALL

SELECT
    'payments',
    payment_id::TEXT,
    payment_date,
    ingested_at
FROM raw.payments
WHERE payment_date > ingested_at

UNION ALL

SELECT
    'returns',
    return_id::TEXT,
    return_date,
    ingested_at
FROM raw.returns
WHERE return_date > ingested_at
ORDER BY table_name, record_id;


-- ============================================================
-- 9. NULL OR BLANK REQUIRED BUSINESS FIELDS
-- ============================================================

SELECT
    customer_id,
    customer_name,
    email
FROM raw.customers
WHERE NULLIF(TRIM(customer_name), '') IS NULL
   OR NULLIF(TRIM(email), '') IS NULL;


SELECT
    product_id,
    product_name,
    category
FROM raw.products
WHERE NULLIF(TRIM(product_name), '') IS NULL
   OR NULLIF(TRIM(category), '') IS NULL;


SELECT
    order_id,
    order_status,
    order_date
FROM raw.orders
WHERE NULLIF(TRIM(order_status), '') IS NULL
   OR order_date IS NULL;


SELECT
    payment_id,
    payment_method,
    payment_status,
    payment_date
FROM raw.payments
WHERE NULLIF(TRIM(payment_method), '') IS NULL
   OR NULLIF(TRIM(payment_status), '') IS NULL
   OR payment_date IS NULL;


SELECT
    shipment_id,
    shipping_method,
    shipment_status
FROM raw.shipments
WHERE NULLIF(TRIM(shipping_method), '') IS NULL
   OR NULLIF(TRIM(shipment_status), '') IS NULL;


SELECT
    return_id,
    return_reason,
    return_status
FROM raw.returns
WHERE NULLIF(TRIM(return_reason), '') IS NULL
   OR NULLIF(TRIM(return_status), '') IS NULL;


-- ============================================================
-- 10. CUSTOMER EMAIL DUPLICATES
-- Case-insensitive diagnostic.
-- The table's UNIQUE constraint may be case-sensitive.
-- ============================================================

SELECT
    LOWER(TRIM(email)) AS normalized_email,
    COUNT(*) AS occurrences,
    ARRAY_AGG(customer_id ORDER BY customer_id) AS customer_ids
FROM raw.customers
WHERE NULLIF(TRIM(email), '') IS NOT NULL
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;


-- ============================================================
-- 11. ORDER-TOTAL RECONCILIATION
--
-- Assumed formula:
--   calculated total =
--       sum(line_total)
--       + shipping_cost
--       + order-level tax
--       - order-level discount
--
-- IMPORTANT:
--   Confirm how line_total is generated before treating
--   differences as errors. This formula assumes line_total
--   does not already include the same order-level adjustments.
-- ============================================================

WITH item_totals AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(line_total) AS nonnull_line_total_count,
        SUM(line_total) AS sum_line_totals
    FROM raw.order_items
    GROUP BY order_id
),
reconciliation AS (
    SELECT
        o.order_id,
        o.total_amount AS recorded_order_total,
        COALESCE(it.item_count, 0) AS item_count,
        COALESCE(it.nonnull_line_total_count, 0)
            AS nonnull_line_total_count,
        it.sum_line_totals,
        o.shipping_cost,
        o.tax_amount AS order_tax,
        o.discount_amount AS order_discount,
        CASE
            WHEN o.total_amount IS NULL
                OR it.item_count IS NULL
                OR it.nonnull_line_total_count <> it.item_count
                OR o.shipping_cost IS NULL
                OR o.tax_amount IS NULL
                OR o.discount_amount IS NULL
            THEN NULL
            ELSE
                it.sum_line_totals
                + o.shipping_cost
                + o.tax_amount
                - o.discount_amount
        END AS calculated_order_total
    FROM raw.orders AS o
    LEFT JOIN item_totals AS it
        ON o.order_id = it.order_id
)
SELECT
    order_id,
    recorded_order_total,
    item_count,
    sum_line_totals,
    shipping_cost,
    order_tax,
    order_discount,
    calculated_order_total,
    CASE
        WHEN calculated_order_total IS NULL
            THEN NULL
        ELSE calculated_order_total - recorded_order_total
    END AS reconciliation_difference,
    CASE
        WHEN recorded_order_total IS NULL
            THEN 'MISSING_RECORDED_TOTAL'
        WHEN item_count = 0
            THEN 'NO_ORDER_ITEMS'
        WHEN nonnull_line_total_count <> item_count
            THEN 'MISSING_LINE_TOTAL'
        WHEN shipping_cost IS NULL
          OR order_tax IS NULL
          OR order_discount IS NULL
            THEN 'MISSING_ORDER_ADJUSTMENT'
        WHEN ABS(calculated_order_total - recorded_order_total) <= 0.01
            THEN 'PASS'
        ELSE 'MISMATCH'
    END AS reconciliation_status
FROM reconciliation
ORDER BY order_id;


-- ============================================================
-- 12. MISSING ORDER FINANCIAL VALUES
-- ============================================================

SELECT
    order_id,
    shipping_cost,
    discount_amount,
    tax_amount,
    total_amount
FROM raw.orders
WHERE shipping_cost IS NULL
   OR discount_amount IS NULL
   OR tax_amount IS NULL
   OR total_amount IS NULL
ORDER BY order_id;


-- ============================================================
-- 13. STATUS DISTRIBUTIONS
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS order_count
FROM raw.orders
GROUP BY order_status
ORDER BY order_count DESC, order_status;


SELECT
    payment_status,
    COUNT(*) AS payment_count
FROM raw.payments
GROUP BY payment_status
ORDER BY payment_count DESC, payment_status;


SELECT
    shipment_status,
    COUNT(*) AS shipment_count
FROM raw.shipments
GROUP BY shipment_status
ORDER BY shipment_count DESC, shipment_status;


SELECT
    return_status,
    COUNT(*) AS return_count
FROM raw.returns
GROUP BY return_status
ORDER BY return_count DESC, return_status;


-- ============================================================
-- 14. MULTIPLE PAYMENTS OR SHIPMENTS PER ORDER
-- Informational checks, not automatic failures.
-- ============================================================

SELECT
    order_id,
    COUNT(*) AS payment_count
FROM raw.payments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY payment_count DESC, order_id;


SELECT
    order_id,
    COUNT(*) AS shipment_count
FROM raw.shipments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY shipment_count DESC, order_id;


-- ============================================================
-- 15. INGESTION TIMESTAMP COVERAGE
-- Expected: zero missing timestamps.
-- ============================================================

SELECT
    table_name,
    total_records,
    missing_ingested_at,
    CASE
        WHEN missing_ingested_at = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM (
    SELECT
        'customers' AS table_name,
        COUNT(*) AS total_records,
        COUNT(*) FILTER (
            WHERE ingested_at IS NULL
        ) AS missing_ingested_at
    FROM raw.customers

    UNION ALL

    SELECT
        'products',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE ingested_at IS NULL
        )
    FROM raw.products

    UNION ALL

    SELECT
        'orders',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE ingested_at IS NULL
        )
    FROM raw.orders

    UNION ALL

    SELECT
        'order_items',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE ingested_at IS NULL
        )
    FROM raw.order_items

    UNION ALL

    SELECT
        'payments',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE ingested_at IS NULL
        )
    FROM raw.payments

    UNION ALL

    SELECT
        'shipments',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE ingested_at IS NULL
        )
    FROM raw.shipments

    UNION ALL

    SELECT
        'returns',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE ingested_at IS NULL
        )
    FROM raw.returns
) AS ingestion_validation
ORDER BY table_name;


-- ============================================================
-- 16. RAW TABLE SCHEMA VALIDATION
-- Verify required columns exist before downstream modelling.
-- ============================================================

WITH expected_columns (table_name, column_name) AS (
    VALUES
        ('customers', 'customer_id'),
        ('customers', 'customer_name'),
        ('customers', 'email'),
        ('customers', 'signup_date'),
        ('customers', 'ingested_at'),

        ('products', 'product_id'),
        ('products', 'product_name'),
        ('products', 'category'),
        ('products', 'cost_price'),
        ('products', 'selling_price'),
        ('products', 'ingested_at'),

        ('orders', 'order_id'),
        ('orders', 'customer_id'),
        ('orders', 'order_date'),
        ('orders', 'order_status'),
        ('orders', 'total_amount'),
        ('orders', 'ingested_at'),

        ('order_items', 'order_item_id'),
        ('order_items', 'order_id'),
        ('order_items', 'product_id'),
        ('order_items', 'quantity'),
        ('order_items', 'line_total'),
        ('order_items', 'ingested_at'),

        ('payments', 'payment_id'),
        ('payments', 'order_id'),
        ('payments', 'payment_date'),
        ('payments', 'amount'),
        ('payments', 'ingested_at'),

        ('shipments', 'shipment_id'),
        ('shipments', 'order_id'),
        ('shipments', 'shipment_status'),
        ('shipments', 'ingested_at'),

        ('returns', 'return_id'),
        ('returns', 'order_item_id'),
        ('returns', 'return_date'),
        ('returns', 'return_quantity'),
        ('returns', 'refund_amount'),
        ('returns', 'ingested_at')
)
SELECT
    e.table_name,
    e.column_name,
    CASE
        WHEN c.column_name IS NOT NULL THEN 'PRESENT'
        ELSE 'MISSING'
    END AS validation_status
FROM expected_columns AS e
LEFT JOIN information_schema.columns AS c
    ON c.table_schema = 'raw'
   AND c.table_name = e.table_name
   AND c.column_name = e.column_name
ORDER BY e.table_name, e.column_name;


-- ============================================================
-- END OF RAW DATA QUALITY CHECKS
-- ============================================================