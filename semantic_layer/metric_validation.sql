
/*
File: semantic_layer/metric_validation.sql

Purpose:
    Validate key business metrics against the Gold reporting layer.

Expected models:
    gold.fact_order_items
    gold.fact_payments
    gold.fact_returns
    gold.fact_shipments

Validation areas:
    1. Order-item grain and key uniqueness
    2. Sales and order-level reconciliation
    3. Payment metrics
    4. Return and refund metrics
    5. Shipping metrics
    6. Data-quality indicators

Important:
    Run each section independently.
    Adapt column names to the actual Gold models.
    These queries identify discrepancies; they do not
    automatically repair data.
*/


-- ============================================================
-- 1. ORDER-ITEM GRAIN VALIDATION
-- Expected grain: One row per order item
-- ============================================================

SELECT
    COUNT(*) AS total_order_item_rows,
    COUNT(DISTINCT order_item_id) AS distinct_order_items,
    COUNT(*) - COUNT(DISTINCT order_item_id)
        AS duplicate_order_item_rows,
    COUNT(*) FILTER (
        WHERE order_item_id IS NULL
    ) AS missing_order_item_ids
FROM gold.fact_order_items;


-- ============================================================
-- 2. SALES METRIC VALIDATION
-- Compare line-level sales with aggregate sales.
-- ============================================================

SELECT
    COUNT(*) AS order_item_rows,
    SUM(quantity) AS total_units,
    SUM(gross_sales_amount) AS gross_sales,
    SUM(net_sales_amount) AS net_sales,
    SUM(
        CASE
            WHEN line_total_mismatch_indicator THEN 1
            ELSE 0
        END
    ) AS line_total_mismatch_rows,
    SUM(
        CASE
            WHEN negative_quantity_indicator THEN 1
            ELSE 0
        END
    ) AS negative_quantity_rows
FROM gold.fact_order_items;


-- ============================================================
-- 3. ORDER-LEVEL RECONCILIATION
-- Expected grain: One row per order
-- Do not sum order totals across order-item rows.
-- ============================================================

WITH order_totals AS (
    SELECT
        order_id,
        COUNT(*) AS order_item_count,
        SUM(gross_sales_amount) AS gross_sales,
        SUM(net_sales_amount) AS net_sales,
        SUM(quantity) AS units
    FROM gold.fact_order_items
    WHERE order_id IS NOT NULL
    GROUP BY order_id
)
SELECT
    COUNT(*) AS distinct_orders,
    SUM(order_item_count) AS total_order_items,
    SUM(units) AS total_units,
    SUM(gross_sales) AS total_gross_sales,
    SUM(net_sales) AS total_net_sales,
    ROUND(
        SUM(net_sales) /
        NULLIF(COUNT(*), 0),
        2
    ) AS average_net_sales_per_order
FROM order_totals;


-- ============================================================
-- 4. PAYMENT METRIC VALIDATION
-- Expected grain: One row per payment transaction
-- ============================================================

SELECT
    COUNT(*) AS payment_transactions,
    COUNT(DISTINCT payment_id) AS distinct_payment_ids,
    COUNT(*) FILTER (
        WHERE payment_id IS NULL
    ) AS missing_payment_ids,
    COUNT(*) FILTER (
        WHERE payment_amount IS NULL
    ) AS missing_payment_amounts,
    COUNT(*) FILTER (
        WHERE payment_amount < 0
    ) AS negative_payment_amounts,
    SUM(payment_amount) AS total_payment_amount,
    SUM(
        CASE
            WHEN successful_payment_indicator THEN 1
            ELSE 0
        END
    ) AS successful_transactions,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN successful_payment_indicator THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS payment_success_rate_pct
FROM gold.fact_payments;


-- ============================================================
-- 5. RETURN AND REFUND VALIDATION
-- Expected grain: One row per return record
-- ============================================================

SELECT
    COUNT(*) AS return_records,
    COUNT(DISTINCT return_id) AS distinct_return_ids,
    COUNT(*) FILTER (
        WHERE return_id IS NULL
    ) AS missing_return_ids,
    SUM(return_quantity) AS total_returned_units,
    SUM(refund_amount) AS total_refunds,
    COUNT(*) FILTER (
        WHERE refund_amount < 0
    ) AS negative_refund_records,
    COUNT(*) FILTER (
        WHERE refund_amount IS NULL
    ) AS missing_refund_records,
    COUNT(*) FILTER (
        WHERE invalid_return_quantity_indicator
    ) AS invalid_return_quantity_records
FROM gold.fact_returns;


-- ============================================================
-- 6. SHIPPING METRIC VALIDATION
-- Expected grain: One row per shipment
-- ============================================================

SELECT
    COUNT(*) AS total_shipments,
    COUNT(DISTINCT shipment_id) AS distinct_shipment_ids,
    COUNT(*) FILTER (
        WHERE shipment_id IS NULL
    ) AS missing_shipment_ids,
    COUNT(*) FILTER (
        WHERE delivered_indicator
    ) AS delivered_shipments,
    COUNT(*) FILTER (
        WHERE delayed_shipment_indicator
    ) AS delayed_shipments,
    COUNT(*) FILTER (
        WHERE delivery_days IS NULL
    ) AS missing_delivery_durations,
    COUNT(*) FILTER (
        WHERE delivery_days < 0
    ) AS negative_delivery_durations,
    ROUND(
        AVG(delivery_days),
        2
    ) AS average_delivery_days,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delayed_shipment_indicator
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS delayed_shipment_rate_pct
FROM gold.fact_shipments;


-- ============================================================
-- 7. ORDER-ITEM KEY COMPLETENESS
-- Check missing business keys in the reporting fact.
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS missing_order_ids,
    COUNT(*) FILTER (
        WHERE customer_key IS NULL
    ) AS missing_customer_keys,
    COUNT(*) FILTER (
        WHERE product_key IS NULL
    ) AS missing_product_keys,
    COUNT(*) FILTER (
        WHERE order_date_key IS NULL
    ) AS missing_order_date_keys
FROM gold.fact_order_items;


-- ============================================================
-- 8. METRIC RECONCILIATION SUMMARY
-- Independently aggregate each fact before combining metrics.
-- This prevents cross-fact join fan-out.
-- ============================================================

WITH sales_metrics AS (
    SELECT
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(gross_sales_amount) AS gross_sales,
        SUM(net_sales_amount) AS net_sales,
        SUM(quantity) AS units_sold
    FROM gold.fact_order_items
),
payment_metrics AS (
    SELECT
        COUNT(*) AS payment_transactions,
        SUM(payment_amount) AS payment_amount,
        SUM(
            CASE
                WHEN successful_payment_indicator THEN 1
                ELSE 0
            END
        ) AS successful_payments
    FROM gold.fact_payments
),
return_metrics AS (
    SELECT
        COUNT(*) AS return_records,
        SUM(refund_amount) AS refund_amount,
        SUM(return_quantity) AS returned_units
    FROM gold.fact_returns
),
shipping_metrics AS (
    SELECT
        COUNT(*) AS total_shipments,
        SUM(
            CASE
                WHEN delivered_indicator THEN 1
                ELSE 0
            END
        ) AS delivered_shipments
    FROM gold.fact_shipments
)
SELECT
    s.total_orders,
    s.gross_sales,
    s.net_sales,
    s.units_sold,
    p.payment_transactions,
    p.payment_amount,
    p.successful_payments,
    r.return_records,
    r.refund_amount,
    r.returned_units,
    sh.total_shipments,
    sh.delivered_shipments
FROM sales_metrics AS s
CROSS JOIN payment_metrics AS p
CROSS JOIN return_metrics AS r
CROSS JOIN shipping_metrics AS sh;
