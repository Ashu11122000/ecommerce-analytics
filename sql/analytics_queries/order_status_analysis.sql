
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: order_status_analysis.sql
-- Purpose:
--   Analyze order statuses, lifecycle trends, revenue,
--   fulfillment, payment consistency, and operational exceptions.
--
-- Target personas:
--   Operations analysts, business leadership, fulfillment teams.
--
-- Source tables:
--   raw.orders
--   raw.payments
--   raw.shipments
--   raw.order_items
--
-- Grain:
--   Each query documents its output grain.
--
-- All queries are read-only.
-- ============================================================


-- ============================================================
-- 1. OVERALL ORDER STATUS SUMMARY
-- Purpose:
--   Count orders and calculate their revenue by status.
-- Dashboard: status distribution chart and summary table.
-- Grain: one row per normalized order status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    ) AS order_status,

    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS order_percentage,

    ROUND(
        COALESCE(SUM(total_amount), 0)::NUMERIC,
        2
    ) AS associated_order_value,

    ROUND(
        AVG(total_amount)::NUMERIC,
        2
    ) AS average_order_value

FROM raw.orders
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    )
ORDER BY order_count DESC;


-- ============================================================
-- 2. STATUS SUMMARY WITH PAYMENT STATUS
-- Purpose:
--   Understand how order statuses relate to payment statuses.
-- Dashboard: stacked bar chart or cross-tab table.
-- Grain: one row per order status and payment status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    ) AS order_status,

    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    ) AS payment_status,

    COUNT(*) AS order_count,

    ROUND(
        COALESCE(SUM(total_amount), 0)::NUMERIC,
        2
    ) AS associated_order_value

FROM raw.orders
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    )
ORDER BY order_count DESC, order_status, payment_status;


-- ============================================================
-- 3. MONTHLY ORDER STATUS TRENDS
-- Purpose:
--   Track how order statuses change over time.
-- Dashboard: monthly stacked column chart.
-- Grain: one row per month and normalized order status.
-- ============================================================

SELECT
    DATE_TRUNC('month', order_date)::DATE AS month_start,

    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    ) AS order_status,

    COUNT(*) AS order_count,

    ROUND(
        COALESCE(SUM(total_amount), 0)::NUMERIC,
        2
    ) AS associated_order_value

FROM raw.orders
WHERE order_date IS NOT NULL
GROUP BY
    DATE_TRUNC('month', order_date)::DATE,
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    )
ORDER BY month_start, order_status;


-- ============================================================
-- 4. MONTH-OVER-MONTH ORDER VOLUME CHANGE
-- Purpose:
--   Compare total monthly orders with the previous observed
--   month, including all statuses.
-- Dashboard: line chart or KPI table.
-- Grain: one row per month present in the data.
--
-- Note:
--   LAG compares consecutive observed months. If a calendar
--   month has no orders, it will not appear in this query.
-- ============================================================

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        COUNT(*) AS total_orders,
        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'cancelled'
        ) AS cancelled_orders,
        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'delivered'
        ) AS delivered_orders,
        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'returned'
        ) AS returned_status_orders
    FROM raw.orders
    WHERE order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
monthly_comparison AS (
    SELECT
        month_start,
        total_orders,
        cancelled_orders,
        delivered_orders,
        returned_status_orders,

        LAG(total_orders) OVER (
            ORDER BY month_start
        ) AS previous_month_orders

    FROM monthly_orders
)
SELECT
    month_start,
    total_orders,
    previous_month_orders,

    total_orders - previous_month_orders AS order_count_change,

    ROUND(
        100.0 * (total_orders - previous_month_orders)
        / NULLIF(previous_month_orders, 0),
        2
    ) AS order_growth_pct,

    cancelled_orders,
    delivered_orders,
    returned_status_orders

FROM monthly_comparison
ORDER BY month_start;


-- ============================================================
-- 5. CANCELLATION RATE BY MONTH
-- Purpose:
--   Monitor the proportion of orders marked cancelled.
-- Dashboard: line chart.
-- Grain: one row per month.
-- ============================================================

SELECT
    DATE_TRUNC('month', order_date)::DATE AS month_start,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'cancelled'
    ) AS cancelled_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'cancelled'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS cancellation_rate_pct

FROM raw.orders
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)::DATE
ORDER BY month_start;


-- ============================================================
-- 6. DELIVERY AND RETURNED-STATUS RATES
-- Purpose:
--   Measure the share of orders marked delivered or returned.
-- Dashboard: KPI cards or monthly line chart.
-- Grain: one row per month.
--
-- Note:
--   "Returned" here means order_status = 'Returned'.
--   It is not the same as counting raw.returns records.
-- ============================================================

SELECT
    DATE_TRUNC('month', order_date)::DATE AS month_start,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'delivered'
    ) AS delivered_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'delivered'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS delivered_order_rate_pct,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'returned'
    ) AS returned_status_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(order_status, ''))) = 'returned'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS returned_status_order_rate_pct

FROM raw.orders
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)::DATE
ORDER BY month_start;


-- ============================================================
-- 7. ORDERS WITH UNUSUAL OR UNRECOGNIZED STATUS VALUES
-- Purpose:
--   Find blank statuses and values outside the current
--   expected status list.
-- Dashboard: data-quality exception table.
-- Grain: one row per affected order.
--
-- Update the expected list if the business defines additional
-- legitimate order statuses.
-- ============================================================

SELECT
    order_id,
    customer_id,
    order_date,
    order_status,
    payment_status,
    total_amount,

    CASE
        WHEN NULLIF(TRIM(order_status), '') IS NULL
            THEN 'Missing order status'
        WHEN LOWER(TRIM(order_status)) NOT IN (
            'pending',
            'confirmed',
            'processing',
            'shipped',
            'delivered',
            'cancelled',
            'returned'
        )
            THEN 'Unrecognized order status'
        ELSE 'Review'
    END AS status_issue

FROM raw.orders
WHERE NULLIF(TRIM(order_status), '') IS NULL
   OR LOWER(TRIM(order_status)) NOT IN (
        'pending',
        'confirmed',
        'processing',
        'shipped',
        'delivered',
        'cancelled',
        'returned'
   )
ORDER BY order_date DESC NULLS LAST, order_id;


-- ============================================================
-- 8. ORDER VS. SHIPMENT STATUS CONSISTENCY
-- Purpose:
--   Identify potentially inconsistent order and shipment states.
-- Dashboard: exception table.
-- Grain: one row per order-shipment pair.
--
-- These rules are diagnostic examples, not an enforced
-- business state machine.
-- ============================================================

SELECT
    o.order_id,
    o.order_status,
    s.shipment_id,
    s.shipment_status,
    s.shipped_at,
    s.delivered_at,

    CASE
        WHEN s.shipment_id IS NULL
         AND LOWER(TRIM(COALESCE(o.order_status, '')))
             IN ('shipped', 'delivered')
            THEN 'Shipped/delivered order without shipment record'

        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'delivered'
         AND LOWER(TRIM(COALESCE(s.shipment_status, '')))
             NOT IN ('delivered')
            THEN 'Delivered order with non-delivered shipment status'

        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'cancelled'
         AND LOWER(TRIM(COALESCE(s.shipment_status, '')))
             IN ('shipped', 'in transit', 'in_transit', 'delivered')
            THEN 'Cancelled order with shipment in transit or delivered'

        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'shipped'
         AND s.shipped_at IS NULL
            THEN 'Shipped order without shipped timestamp'

        WHEN LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delivered'
         AND s.delivered_at IS NULL
            THEN 'Delivered shipment without delivered timestamp'

        ELSE 'Review'
    END AS consistency_issue

FROM raw.orders o
LEFT JOIN raw.shipments s
    ON s.order_id = o.order_id
WHERE (
        s.shipment_id IS NULL
        AND LOWER(TRIM(COALESCE(o.order_status, '')))
            IN ('shipped', 'delivered')
      )
   OR (
        LOWER(TRIM(COALESCE(o.order_status, ''))) = 'delivered'
        AND LOWER(TRIM(COALESCE(s.shipment_status, '')))
            NOT IN ('delivered')
      )
   OR (
        LOWER(TRIM(COALESCE(o.order_status, ''))) = 'cancelled'
        AND LOWER(TRIM(COALESCE(s.shipment_status, '')))
            IN ('shipped', 'in transit', 'in_transit', 'delivered')
      )
   OR (
        LOWER(TRIM(COALESCE(o.order_status, ''))) = 'shipped'
        AND s.shipped_at IS NULL
      )
   OR (
        LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delivered'
        AND s.delivered_at IS NULL
      )
ORDER BY o.order_id, s.shipment_id;


-- ============================================================
-- 9. ORDER VS. PAYMENT STATUS CONSISTENCY
-- Purpose:
--   Identify potentially inconsistent order and payment states.
-- Dashboard: payment exception table.
-- Grain: one row per order-payment pair.
--
-- Multiple payment rows per order may produce multiple results.
-- ============================================================

SELECT
    o.order_id,
    o.order_status,
    o.payment_status AS order_payment_status,
    p.payment_id,
    p.payment_status AS transaction_payment_status,
    p.amount,
    p.payment_date,

    CASE
        WHEN p.payment_id IS NULL
         AND LOWER(TRIM(COALESCE(o.payment_status, '')))
             IN ('paid', 'completed', 'successful')
            THEN 'Order marked paid without payment record'

        WHEN LOWER(TRIM(COALESCE(o.payment_status, '')))
             IN ('paid', 'completed', 'successful')
         AND LOWER(TRIM(COALESCE(p.payment_status, '')))
             IN ('failed', 'pending')
            THEN 'Order payment status conflicts with transaction'

        WHEN LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'failed'
         AND LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'paid'
            THEN 'Order marked failed but payment is paid'

        WHEN LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'pending'
         AND LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'paid'
            THEN 'Order payment status is pending but transaction is paid'

        ELSE 'Review'
    END AS consistency_issue

FROM raw.orders o
LEFT JOIN raw.payments p
    ON p.order_id = o.order_id
WHERE (
        p.payment_id IS NULL
        AND LOWER(TRIM(COALESCE(o.payment_status, '')))
            IN ('paid', 'completed', 'successful')
      )
   OR (
        LOWER(TRIM(COALESCE(o.payment_status, '')))
            IN ('paid', 'completed', 'successful')
        AND LOWER(TRIM(COALESCE(p.payment_status, '')))
            IN ('failed', 'pending')
      )
   OR (
        LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'failed'
        AND LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'paid'
      )
   OR (
        LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'pending'
        AND LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'paid'
      )
ORDER BY o.order_id, p.payment_id;


-- ============================================================
-- 10. ORDER STATUS BY SALES CHANNEL
-- Purpose:
--   Compare lifecycle outcomes across sales channels.
-- Dashboard: stacked bar chart or pivot table.
-- Grain: one row per sales channel and order status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(sales_channel), ''),
        'Unknown'
    ) AS sales_channel,

    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    ) AS order_status,

    COUNT(*) AS order_count,

    ROUND(
        COALESCE(SUM(total_amount), 0)::NUMERIC,
        2
    ) AS associated_order_value

FROM raw.orders
GROUP BY
    COALESCE(
        NULLIF(TRIM(sales_channel), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    )
ORDER BY sales_channel, order_count DESC;


-- ============================================================
-- 11. ORDER STATUS BY SHIPPING METHOD
-- Purpose:
--   Compare order outcomes by shipping method.
-- Dashboard: stacked bar chart or summary table.
-- Grain: one row per shipping method and order status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(shipping_method), ''),
        'Unknown'
    ) AS shipping_method,

    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    ) AS order_status,

    COUNT(*) AS order_count,

    ROUND(
        AVG(total_amount)::NUMERIC,
        2
    ) AS average_order_value

FROM raw.orders
GROUP BY
    COALESCE(
        NULLIF(TRIM(shipping_method), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    )
ORDER BY shipping_method, order_count DESC;


-- ============================================================
-- 12. ORDER STATUS DATA QUALITY SUMMARY
-- Purpose:
--   Return a compact set of data-quality counts related to
--   order lifecycle information.
-- Dashboard: data-quality KPI cards.
-- Grain: one row for the dataset.
-- ============================================================

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_date IS NULL
    ) AS orders_missing_order_date,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_status), '') IS NULL
    ) AS orders_missing_order_status,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_status), '') IS NULL
    ) AS orders_missing_payment_status,

    COUNT(*) FILTER (
        WHERE total_amount IS NULL
    ) AS orders_missing_total_amount,

    COUNT(*) FILTER (
        WHERE total_amount < 0
    ) AS orders_with_negative_total_amount,

    COUNT(*) FILTER (
        WHERE updated_at IS NOT NULL
          AND order_date IS NOT NULL
          AND updated_at < order_date
    ) AS orders_updated_before_order_date

FROM raw.orders;


-- ============================================================
-- END OF order_status_analysis.sql
-- ============================================================
