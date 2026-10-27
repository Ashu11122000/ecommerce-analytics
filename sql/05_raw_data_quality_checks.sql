
-- ============================================================
-- E-COMMERCE ANALYTICS ENGINEERING
-- RAW DATA QUALITY CHECKS
-- Database: ecommerce_analytics
-- Schema: raw
--
-- Purpose:
--   Check duplicates, missing relationships, invalid values,
--   financial reconciliation, and date inconsistencies.
--
-- Read-only: these queries do not modify data.
-- ============================================================


-- ============================================================
-- 1. ROW COUNTS
-- ============================================================

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM raw.customers
UNION ALL
SELECT 'products', COUNT(*) FROM raw.products
UNION ALL
SELECT 'orders', COUNT(*) FROM raw.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM raw.payments
UNION ALL
SELECT 'shipments', COUNT(*) FROM raw.shipments
UNION ALL
SELECT 'returns', COUNT(*) FROM raw.returns;


-- ============================================================
-- 2. DUPLICATE PRIMARY KEYS
-- Expected: zero rows for every query.
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
-- 3. MISSING FOREIGN-KEY RELATIONSHIPS
-- Expected: zero rows for each query.
-- ============================================================

-- Orders with missing customers
SELECT o.order_id, o.customer_id
FROM raw.orders AS o
LEFT JOIN raw.customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items with missing orders
SELECT oi.order_item_id, oi.order_id
FROM raw.order_items AS oi
LEFT JOIN raw.orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items with missing products
SELECT oi.order_item_id, oi.product_id
FROM raw.order_items AS oi
LEFT JOIN raw.products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Payments with missing orders
SELECT p.payment_id, p.order_id
FROM raw.payments AS p
LEFT JOIN raw.orders AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Shipments with missing orders
SELECT s.shipment_id, s.order_id
FROM raw.shipments AS s
LEFT JOIN raw.orders AS o
    ON s.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Returns with missing order items
SELECT r.return_id, r.order_item_id
FROM raw.returns AS r
LEFT JOIN raw.order_items AS oi
    ON r.order_item_id = oi.order_item_id
WHERE oi.order_item_id IS NULL;


-- ============================================================
-- 4. INVALID ORDER-ITEM VALUES
-- Review any returned rows.
-- ============================================================

SELECT *
FROM raw.order_items
WHERE quantity <= 0
   OR unit_price < 0
   OR COALESCE(discount_amount, 0) < 0
   OR COALESCE(tax_amount, 0) < 0
   OR COALESCE(line_total, 0) < 0
   OR COALESCE(returned_quantity, 0) < 0;


-- Returned quantity greater than ordered quantity
SELECT
    order_item_id,
    quantity,
    returned_quantity
FROM raw.order_items
WHERE COALESCE(returned_quantity, 0) > quantity;


-- ============================================================
-- 5. INVALID PRODUCT VALUES
-- ============================================================

SELECT *
FROM raw.products
WHERE cost_price < 0
   OR selling_price < 0
   OR stock_quantity < 0
   OR reorder_level < 0;


-- Products whose cost exceeds their selling price.
-- This is a business review, not necessarily a data error.
SELECT
    product_id,
    product_name,
    cost_price,
    selling_price
FROM raw.products
WHERE cost_price > selling_price;


-- ============================================================
-- 6. INVALID PAYMENT AND RETURN VALUES
-- ============================================================

SELECT *
FROM raw.payments
WHERE amount < 0;

SELECT *
FROM raw.returns
WHERE return_quantity <= 0
   OR refund_amount < 0;


-- Return quantities exceeding the order-item quantity
SELECT
    r.return_id,
    r.order_item_id,
    r.return_quantity,
    oi.quantity AS ordered_quantity
FROM raw.returns AS r
JOIN raw.order_items AS oi
    ON r.order_item_id = oi.order_item_id
WHERE r.return_quantity > oi.quantity;


-- ============================================================
-- 7. DATE CONSISTENCY
-- Review results; not all cases are automatically errors.
-- ============================================================

-- Orders dated after their latest update timestamp
SELECT order_id, order_date, updated_at
FROM raw.orders
WHERE updated_at IS NOT NULL
  AND updated_at < order_date;

-- Customers whose signup date is after their update timestamp
SELECT customer_id, signup_date, updated_at
FROM raw.customers
WHERE updated_at IS NOT NULL
  AND updated_at::date < signup_date;

-- Shipments delivered before they were shipped
SELECT
    shipment_id,
    shipped_at,
    delivered_at
FROM raw.shipments
WHERE shipped_at IS NOT NULL
  AND delivered_at IS NOT NULL
  AND delivered_at < shipped_at;

-- Returns dated before their associated order
SELECT
    r.return_id,
    r.return_date,
    o.order_date
FROM raw.returns AS r
JOIN raw.order_items AS oi
    ON r.order_item_id = oi.order_item_id
JOIN raw.orders AS o
    ON oi.order_id = o.order_id
WHERE r.return_date < o.order_date;


-- ============================================================
-- 8. NULL OR BLANK REQUIRED BUSINESS FIELDS
-- ============================================================

SELECT customer_id, customer_name, email
FROM raw.customers
WHERE NULLIF(TRIM(customer_name), '') IS NULL
   OR NULLIF(TRIM(email), '') IS NULL;

SELECT product_id, product_name, category
FROM raw.products
WHERE NULLIF(TRIM(product_name), '') IS NULL
   OR NULLIF(TRIM(category), '') IS NULL;

SELECT order_id, order_status, order_date
FROM raw.orders
WHERE NULLIF(TRIM(order_status), '') IS NULL
   OR order_date IS NULL;


-- ============================================================
-- 9. ORDER TOTAL RECONCILIATION
--
-- This compares order.total_amount with the sum of its
-- line_total values plus order-level shipping, tax, and discount.
--
-- IMPORTANT:
-- This formula is only a diagnostic assumption. Confirm the
-- generator's business formula before treating differences
-- as errors. Tax/discount may already be included in line_total.
-- ============================================================

SELECT
    o.order_id,
    o.total_amount AS recorded_order_total,
    SUM(COALESCE(oi.line_total, 0)) AS sum_line_totals,
    COALESCE(o.shipping_cost, 0) AS shipping_cost,
    COALESCE(o.tax_amount, 0) AS order_tax,
    COALESCE(o.discount_amount, 0) AS order_discount
FROM raw.orders AS o
LEFT JOIN raw.order_items AS oi
    ON o.order_id = oi.order_id
GROUP BY
    o.order_id,
    o.total_amount,
    o.shipping_cost,
    o.tax_amount,
    o.discount_amount
ORDER BY o.order_id;


-- ============================================================
-- 10. ORDER, PAYMENT, SHIPMENT, AND RETURN STATUS DISTRIBUTIONS
-- ============================================================

SELECT order_status, COUNT(*) AS order_count
FROM raw.orders
GROUP BY order_status
ORDER BY order_count DESC;

SELECT payment_status, COUNT(*) AS payment_count
FROM raw.payments
GROUP BY payment_status
ORDER BY payment_count DESC;

SELECT shipment_status, COUNT(*) AS shipment_count
FROM raw.shipments
GROUP BY shipment_status
ORDER BY shipment_count DESC;

SELECT return_status, COUNT(*) AS return_count
FROM raw.returns
GROUP BY return_status
ORDER BY return_count DESC;


-- ============================================================
-- 11. MULTIPLE PAYMENTS OR SHIPMENTS PER ORDER
-- These are informational checks, not automatic failures.
-- ============================================================

SELECT order_id, COUNT(*) AS payment_count
FROM raw.payments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY payment_count DESC;

SELECT order_id, COUNT(*) AS shipment_count
FROM raw.shipments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY shipment_count DESC;


-- ============================================================
-- 12. INGESTION TIMESTAMP COVERAGE
-- Expected: zero rows for each query because ingested_at
-- is declared NOT NULL in your table definitions.
-- ============================================================

SELECT 'customers' AS table_name, COUNT(*) AS missing_ingested_at
FROM raw.customers
WHERE ingested_at IS NULL
UNION ALL
SELECT 'products', COUNT(*)
FROM raw.products
WHERE ingested_at IS NULL
UNION ALL
SELECT 'orders', COUNT(*)
FROM raw.orders
WHERE ingested_at IS NULL
UNION ALL
SELECT 'order_items', COUNT(*)
FROM raw.order_items
WHERE ingested_at IS NULL
UNION ALL
SELECT 'payments', COUNT(*)
FROM raw.payments
WHERE ingested_at IS NULL
UNION ALL
SELECT 'shipments', COUNT(*)
FROM raw.shipments
WHERE ingested_at IS NULL
UNION ALL
SELECT 'returns', COUNT(*)
FROM raw.returns
WHERE ingested_at IS NULL;
