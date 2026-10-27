
/*
File: dashboards/operations/dashboard_queries.sql
Purpose: Operational and analyst reporting.

Expected Gold models:
  gold.fact_order_items
  gold.fact_payments
  gold.fact_returns
  gold.fact_shipments
  gold.dim_date

Important:
  Verify exact column names against the existing Gold SQL files.
  Do not join multiple fact tables directly at their native grain,
  because that can multiply records and inflate totals.
*/


-- ============================================================
-- QUERY 1: Order Status Distribution
-- Grain: One row per order status
-- ============================================================

SELECT
    order_status,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS units_sold,
    SUM(net_sales_amount) AS net_sales
FROM gold.fact_order_items
GROUP BY
    order_status
ORDER BY
    total_orders DESC;


-- ============================================================
-- QUERY 2: Monthly Payment Performance
-- Grain: One row per month, payment method, and status
-- ============================================================

SELECT
    d.year,
    d.month_number,
    p.payment_method,
    p.payment_status,
    COUNT(*) AS payment_transactions,
    SUM(p.payment_amount) AS payment_amount,
    ROUND(AVG(p.payment_amount), 2) AS average_payment_amount,
    SUM(
        CASE
            WHEN p.successful_payment_indicator THEN 1
            ELSE 0
        END
    ) AS successful_transactions,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN p.successful_payment_indicator THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS payment_success_rate_pct
FROM gold.fact_payments AS p
LEFT JOIN gold.dim_date AS d
    ON p.payment_date_key = d.date_key
GROUP BY
    d.year,
    d.month_number,
    p.payment_method,
    p.payment_status
ORDER BY
    d.year,
    d.month_number,
    p.payment_method,
    p.payment_status;


-- ============================================================
-- QUERY 3: Return Analysis by Status and Reason
-- Grain: One row per return status and reason
-- ============================================================

SELECT
    return_status,
    return_reason,
    COUNT(*) AS return_records,
    SUM(return_quantity) AS returned_units,
    SUM(refund_amount) AS total_refunds,
    ROUND(AVG(refund_amount), 2) AS average_refund,
    SUM(
        CASE
            WHEN approved_return_indicator THEN 1
            ELSE 0
        END
    ) AS approved_returns,
    SUM(
        CASE
            WHEN invalid_return_quantity_indicator THEN 1
            ELSE 0
        END
    ) AS invalid_quantity_records
FROM gold.fact_returns
GROUP BY
    return_status,
    return_reason
ORDER BY
    return_records DESC;


-- ============================================================
-- QUERY 4: Monthly Shipping Performance
-- Grain: One row per month, shipping method, and status
-- ============================================================

SELECT
    d.year,
    d.month_number,
    s.shipping_method,
    s.shipment_status,
    COUNT(*) AS total_shipments,
    SUM(
        CASE
            WHEN s.delivered_indicator THEN 1
            ELSE 0
        END
    ) AS delivered_shipments,
    ROUND(
        AVG(s.delivery_days),
        2
    ) AS average_delivery_days,
    SUM(
        CASE
            WHEN s.delayed_shipment_indicator THEN 1
            ELSE 0
        END
    ) AS delayed_shipments,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN s.delayed_shipment_indicator THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS delayed_shipment_rate_pct
FROM gold.fact_shipments AS s
LEFT JOIN gold.dim_date AS d
    ON s.shipped_date_key = d.date_key
GROUP BY
    d.year,
    d.month_number,
    s.shipping_method,
    s.shipment_status
ORDER BY
    d.year,
    d.month_number,
    total_shipments DESC;


-- ============================================================
-- QUERY 5: Data Quality Issues in Order Items
-- Grain: One row per data-quality category
-- ============================================================

SELECT
    'Line Total Mismatch' AS issue_type,
    COUNT(*) AS affected_records
FROM gold.fact_order_items
WHERE line_total_mismatch_indicator

UNION ALL

SELECT
    'Negative Quantity' AS issue_type,
    COUNT(*) AS affected_records
FROM gold.fact_order_items
WHERE negative_quantity_indicator

UNION ALL

SELECT
    'Excess Returned Quantity' AS issue_type,
    COUNT(*) AS affected_records
FROM gold.fact_order_items
WHERE excess_returned_quantity_indicator

ORDER BY
    affected_records DESC;


-- ============================================================
-- QUERY 6: Payment Data Quality Issues
-- Grain: One row per issue category
-- ============================================================

SELECT
    'Negative Payment Amount' AS issue_type,
    COUNT(*) AS affected_records
FROM gold.fact_payments
WHERE payment_amount < 0

UNION ALL

SELECT
    'Missing Payment Amount' AS issue_type,
    COUNT(*) AS affected_records
FROM gold.fact_payments
WHERE payment_amount IS NULL

UNION ALL

SELECT
    'Missing Transaction Reference' AS issue_type,
    COUNT(*) AS affected_records
FROM gold.fact_payments
WHERE transaction_reference_indicator = FALSE

ORDER BY
    affected_records DESC;


-- ============================================================
-- QUERY 7: Delivery Speed Distribution
-- Grain: One row per delivery-speed category
-- ============================================================

SELECT
    delivery_speed,
    COUNT(*) AS total_shipments,
    SUM(
        CASE
            WHEN delivered_indicator THEN 1
            ELSE 0
        END
    ) AS delivered_shipments,
    ROUND(
        AVG(delivery_days),
        2
    ) AS average_delivery_days
FROM gold.fact_shipments
GROUP BY
    delivery_speed
ORDER BY
    total_shipments DESC;


-- ============================================================
-- QUERY 8: Monthly Return Trend
-- Grain: One row per month
-- ============================================================

SELECT
    d.year,
    d.month_number,
    COUNT(*) AS return_records,
    SUM(r.return_quantity) AS returned_units,
    SUM(r.refund_amount) AS total_refunds
FROM gold.fact_returns AS r
LEFT JOIN gold.dim_date AS d
    ON r.return_date_key = d.date_key
GROUP BY
    d.year,
    d.month_number
ORDER BY
    d.year,
    d.month_number;
