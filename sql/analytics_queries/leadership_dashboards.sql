
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: leadership_dashboards.sql
-- Purpose:
--   SQL queries powering the Business / Leadership Dashboard.
--
-- Target persona:
--   CEO, business leadership, e-commerce manager.
--
-- Business questions:
--   1. What are the overall revenue and order KPIs?
--   2. How are revenue and orders trending over time?
--   3. Which order statuses need attention?
--   4. Which product categories generate the most revenue?
--   5. Which sales channels perform best?
--   6. What percentage of orders are returned?
--   7. How much revenue is associated with returned orders?
--   8. How concentrated is revenue among customers?
--
-- Source tables:
--   raw.orders
--   raw.order_items
--   raw.products
--   raw.customers
--   raw.returns
--
-- Important assumptions:
--   - Cancelled orders are excluded from revenue and order KPIs.
--   - Revenue uses raw.orders.total_amount.
--   - Returned orders are not automatically excluded from revenue.
--   - Return rate uses distinct orders with return records divided
--     by non-cancelled orders. It is an order-level proxy.
--   - Refund amounts are reported separately from order revenue.
--   - Synthetic data may not represent real business behavior.
--
-- Grain:
--   Depends on the individual query; documented per section.
--
-- All queries are read-only.
-- ============================================================


-- ============================================================
-- 1. EXECUTIVE KPI SUMMARY
-- Dashboard visualization:
--   KPI cards for revenue, orders, average order value,
--   unique purchasing customers, and return rate.
-- Grain: one row for the entire observed dataset.
-- ============================================================

WITH eligible_orders AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        order_status,
        total_amount
    FROM raw.orders
    WHERE LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
),
order_return_flags AS (
    SELECT DISTINCT
        oi.order_id
    FROM raw.returns r
    INNER JOIN raw.order_items oi
        ON oi.order_item_id = r.order_item_id
)
SELECT
    COUNT(*) AS eligible_order_count,

    COUNT(DISTINCT customer_id) AS purchasing_customer_count,

    ROUND(
        COALESCE(SUM(total_amount), 0)::NUMERIC,
        2
    ) AS total_order_revenue,

    ROUND(
        AVG(total_amount)::NUMERIC,
        2
    ) AS average_order_value,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'delivered'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS delivered_order_pct,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'returned'
    ) AS returned_status_order_count,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'returned'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS returned_status_order_pct,

    COUNT(*) FILTER (
        WHERE erf.order_id IS NOT NULL
    ) AS orders_with_return_records,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE erf.order_id IS NOT NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS order_return_record_rate_pct

FROM eligible_orders eo
LEFT JOIN order_return_flags erf
    ON erf.order_id = eo.order_id;


-- ============================================================
-- 2. MONTHLY REVENUE AND ORDER TREND
-- Dashboard visualization:
--   Combo chart: monthly revenue columns and order-count line.
-- Grain: one row per calendar month containing eligible orders.
-- ============================================================

SELECT
    DATE_TRUNC('month', order_date)::DATE AS month_start,

    COUNT(*) AS order_count,

    ROUND(
        SUM(total_amount)::NUMERIC,
        2
    ) AS total_revenue,

    ROUND(
        AVG(total_amount)::NUMERIC,
        2
    ) AS average_order_value,

    COUNT(DISTINCT customer_id) AS unique_customers

FROM raw.orders
WHERE order_date IS NOT NULL
  AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
GROUP BY DATE_TRUNC('month', order_date)::DATE
ORDER BY month_start;


-- ============================================================
-- 3. MONTH-OVER-MONTH REVENUE GROWTH
-- Dashboard visualization:
--   KPI or table showing revenue change and growth percentage.
-- Grain: one row per month present in the source data.
--
-- Note:
--   LAG compares against the previous observed month. For a
--   complete calendar-month comparison, use a date spine.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS total_revenue
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
revenue_comparison AS (
    SELECT
        month_start,
        total_revenue,
        LAG(total_revenue) OVER (
            ORDER BY month_start
        ) AS previous_month_revenue
    FROM monthly_revenue
)
SELECT
    month_start,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,

    ROUND(
        total_revenue - previous_month_revenue,
        2
    ) AS revenue_change,

    ROUND(
        100.0 * (
            total_revenue - previous_month_revenue
        ) / NULLIF(previous_month_revenue, 0),
        2
    ) AS revenue_growth_pct

FROM revenue_comparison
ORDER BY month_start;


-- ============================================================
-- 4. ORDER STATUS OVERVIEW
-- Dashboard visualization:
--   Donut chart or horizontal bar chart by order status.
-- Grain: one row per normalized order status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    ) AS order_status,

    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS percentage_of_all_orders,

    ROUND(
        COALESCE(SUM(total_amount), 0)::NUMERIC,
        2
    ) AS associated_order_value

FROM raw.orders
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    )
ORDER BY order_count DESC;


-- ============================================================
-- 5. CATEGORY PERFORMANCE
-- Dashboard visualization:
--   Bar chart of revenue by product category.
-- Grain: one row per product category.
--
-- Revenue basis:
--   Sum of order-item line_total for non-cancelled orders.
--   This is line-level merchandise value, not necessarily
--   identical to raw.orders.total_amount.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(p.category), ''),
        'Unknown'
    ) AS product_category,

    COUNT(DISTINCT o.order_id) AS order_count,

    COUNT(DISTINCT oi.product_id) AS distinct_products_sold,

    SUM(oi.quantity) AS units_ordered,

    ROUND(
        SUM(oi.line_total)::NUMERIC,
        2
    ) AS merchandise_revenue,

    ROUND(
        SUM(oi.line_total)::NUMERIC
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS merchandise_revenue_per_order

FROM raw.order_items oi
INNER JOIN raw.orders o
    ON o.order_id = oi.order_id
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
WHERE LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
  AND oi.line_total IS NOT NULL
GROUP BY
    COALESCE(
        NULLIF(TRIM(p.category), ''),
        'Unknown'
    )
ORDER BY merchandise_revenue DESC NULLS LAST;


-- ============================================================
-- 6. SALES CHANNEL PERFORMANCE
-- Dashboard visualization:
--   Bar chart ranking sales channels by revenue.
-- Grain: one row per sales channel.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(sales_channel), ''),
        'Unknown'
    ) AS sales_channel,

    COUNT(*) AS order_count,

    COUNT(DISTINCT customer_id) AS unique_customers,

    ROUND(
        SUM(total_amount)::NUMERIC,
        2
    ) AS total_revenue,

    ROUND(
        AVG(total_amount)::NUMERIC,
        2
    ) AS average_order_value,

    ROUND(
        100.0 * SUM(total_amount)
        / NULLIF(SUM(SUM(total_amount)) OVER (), 0),
        2
    ) AS revenue_share_pct

FROM raw.orders
WHERE LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
GROUP BY
    COALESCE(
        NULLIF(TRIM(sales_channel), ''),
        'Unknown'
    )
ORDER BY total_revenue DESC NULLS LAST;


-- ============================================================
-- 7. TOP 10 PRODUCTS BY MERCHANDISE REVENUE
-- Dashboard visualization:
--   Horizontal bar chart.
-- Grain: one row per product.
-- ============================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,

    SUM(oi.quantity) AS units_ordered,

    COUNT(DISTINCT o.order_id) AS order_count,

    ROUND(
        SUM(oi.line_total)::NUMERIC,
        2
    ) AS merchandise_revenue

FROM raw.order_items oi
INNER JOIN raw.orders o
    ON o.order_id = oi.order_id
INNER JOIN raw.products p
    ON p.product_id = oi.product_id
WHERE LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
  AND oi.line_total IS NOT NULL
GROUP BY
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory
ORDER BY merchandise_revenue DESC NULLS LAST
LIMIT 10;


-- ============================================================
-- 8. CUSTOMER REVENUE CONCENTRATION
-- Dashboard visualization:
--   Ranked customer table or cumulative revenue Pareto chart.
-- Grain: one row per customer with at least one eligible order.
-- ============================================================

WITH customer_revenue AS (
    SELECT
        o.customer_id,
        COUNT(*) AS order_count,
        SUM(o.total_amount)::NUMERIC AS customer_revenue
    FROM raw.orders o
    WHERE LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
      AND o.customer_id IS NOT NULL
      AND o.total_amount IS NOT NULL
    GROUP BY o.customer_id
),
ranked_customers AS (
    SELECT
        customer_id,
        order_count,
        customer_revenue,

        ROW_NUMBER() OVER (
            ORDER BY customer_revenue DESC, customer_id
        ) AS customer_rank,

        SUM(customer_revenue) OVER (
            ORDER BY customer_revenue DESC, customer_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,

        SUM(customer_revenue) OVER () AS total_revenue,

        COUNT(*) OVER () AS customer_count

    FROM customer_revenue
)
SELECT
    rc.customer_id,
    c.customer_name,
    rc.order_count,
    ROUND(rc.customer_revenue, 2) AS customer_revenue,
    rc.customer_rank,

    ROUND(
        100.0 * rc.customer_revenue
        / NULLIF(rc.total_revenue, 0),
        2
    ) AS individual_revenue_share_pct,

    ROUND(
        100.0 * rc.cumulative_revenue
        / NULLIF(rc.total_revenue, 0),
        2
    ) AS cumulative_revenue_share_pct,

    rc.customer_count

FROM ranked_customers rc
LEFT JOIN raw.customers c
    ON c.customer_id = rc.customer_id
ORDER BY rc.customer_rank
LIMIT 20;


-- ============================================================
-- 9. RETURN AND REFUND OVERVIEW
-- Dashboard visualization:
--   KPI cards for return records and refund amounts;
--   bar chart by return reason or return status.
-- Grain: one row per return status and reason combination.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(r.return_status)), ''),
        'Unknown'
    ) AS return_status,

    COALESCE(
        NULLIF(INITCAP(TRIM(r.return_reason)), ''),
        'Unknown'
    ) AS return_reason,

    COUNT(*) AS return_record_count,

    SUM(r.return_quantity) AS returned_units,

    ROUND(
        COALESCE(SUM(r.refund_amount), 0)::NUMERIC,
        2
    ) AS total_refund_amount

FROM raw.returns r
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(r.return_status)), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(r.return_reason)), ''),
        'Unknown'
    )
ORDER BY total_refund_amount DESC NULLS LAST;


-- ============================================================
-- 10. INVENTORY REORDER WATCHLIST
-- Dashboard visualization:
--   Table of products at or below reorder level.
-- Grain: one row per product requiring inventory attention.
-- ============================================================

SELECT
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    stock_quantity,
    reorder_level,

    reorder_level - stock_quantity AS units_below_reorder_level,

    cost_price,
    selling_price,

    CASE
        WHEN stock_quantity < 0
            THEN 'INVALID NEGATIVE STOCK'
        WHEN stock_quantity = 0
            THEN 'OUT OF STOCK'
        WHEN stock_quantity <= reorder_level
            THEN 'REORDER REQUIRED'
        ELSE 'STOCK AVAILABLE'
    END AS inventory_status

FROM raw.products
WHERE stock_quantity IS NOT NULL
  AND reorder_level IS NOT NULL
  AND stock_quantity <= reorder_level
ORDER BY
    (reorder_level - stock_quantity) DESC,
    product_name;


-- ============================================================
-- 11. LEADERSHIP ACTION SUMMARY
-- Dashboard visualization:
--   Compact table of key operational indicators.
-- Grain: one row per indicator.
-- ============================================================

WITH order_metrics AS (
    SELECT
        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'pending'
        ) AS pending_orders,

        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'shipped'
        ) AS shipped_orders,

        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'returned'
        ) AS returned_status_orders

    FROM raw.orders
),
shipment_metrics AS (
    SELECT
        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(shipment_status, '')))
                IN ('delayed', 'processing')
        ) AS delayed_or_processing_shipments
    FROM raw.shipments
),
inventory_metrics AS (
    SELECT
        COUNT(*) FILTER (
            WHERE stock_quantity <= reorder_level
        ) AS products_at_or_below_reorder
    FROM raw.products
    WHERE stock_quantity IS NOT NULL
      AND reorder_level IS NOT NULL
),
return_metrics AS (
    SELECT
        COUNT(*) AS return_records,
        ROUND(
            COALESCE(SUM(refund_amount), 0)::NUMERIC,
            2
        ) AS refund_amount
    FROM raw.returns
)
SELECT
    'Pending orders' AS indicator,
    pending_orders::NUMERIC AS indicator_value,
    'Review orders awaiting processing' AS suggested_action
FROM order_metrics

UNION ALL

SELECT
    'Shipped orders',
    shipped_orders::NUMERIC,
    'Monitor shipments through delivery'
FROM order_metrics

UNION ALL

SELECT
    'Orders with returned status',
    returned_status_orders::NUMERIC,
    'Review return causes and recovery opportunities'
FROM order_metrics

UNION ALL

SELECT
    'Delayed or processing shipments',
    delayed_or_processing_shipments::NUMERIC,
    'Investigate fulfillment delays'
FROM shipment_metrics

UNION ALL

SELECT
    'Products at or below reorder level',
    products_at_or_below_reorder::NUMERIC,
    'Review replenishment priorities'
FROM inventory_metrics

UNION ALL

SELECT
    'Return records',
    return_records::NUMERIC,
    'Review return reasons and return-status outcomes'
FROM return_metrics

UNION ALL

SELECT
    'Recorded refund amount',
    refund_amount,
    'Reconcile refunds against payment and order records'
FROM return_metrics;


-- ============================================================
-- 12. DASHBOARD DATA COVERAGE
-- Dashboard visualization:
--   Optional data-quality/coverage KPI cards.
-- Grain: one row for the entire dataset.
-- ============================================================

SELECT
    (SELECT COUNT(*) FROM raw.orders) AS total_source_orders,

    (SELECT COUNT(*)
     FROM raw.orders
     WHERE order_date IS NULL) AS orders_missing_order_date,

    (SELECT COUNT(*)
     FROM raw.orders
     WHERE total_amount IS NULL) AS orders_missing_total_amount,

    (SELECT COUNT(*)
     FROM raw.order_items
     WHERE quantity IS NULL OR quantity <= 0) AS invalid_order_item_quantities,

    (SELECT COUNT(*)
     FROM raw.returns
     WHERE refund_amount IS NULL OR refund_amount < 0)
        AS returns_with_missing_or_negative_refund,

    (SELECT COUNT(*)
     FROM raw.products
     WHERE stock_quantity IS NULL OR reorder_level IS NULL)
        AS products_missing_inventory_values;


-- ============================================================
-- END OF leadership_dashboards.sql
-- ============================================================
