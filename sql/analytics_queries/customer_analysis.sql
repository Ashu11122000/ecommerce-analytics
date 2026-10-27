-- ============================================================
-- E-COMMERCE ANALYTICS ENGINEERING
-- File: custom_analysis.sql
-- Purpose: Customer behavior and purchasing analysis.
-- Database: ecommerce_analytics
-- Schema: raw
--
-- Analyses:
--   1. Customer purchase summary
--   2. Customer lifetime revenue
--   3. Repeat customer analysis
--   4. Customer revenue segmentation
--   5. Top customers by revenue
--   6. Customer purchase frequency
--   7. Inactive customers
--   8. Monthly customer acquisition
--   9. Customer retention proxy
--  10. Customer revenue concentration
--
-- IMPORTANT:
--   - Read-only queries.
--   - Revenue uses order-level total_amount.
--   - Cancelled orders are excluded from purchasing metrics.
--   - Returned orders are not automatically excluded because
--     return status does not necessarily indicate a full refund.
--   - Customer lifetime revenue is observed revenue, not
--     profit or a predictive lifetime-value estimate.
-- ============================================================


-- ============================================================
-- 1. CUSTOMER PURCHASE SUMMARY
-- Grain: One row per customer.
--
-- Includes customers who have never placed an order.
-- ============================================================

WITH customer_orders AS (
    SELECT
        o.customer_id,
        COUNT(*) AS total_orders,
        COUNT(*) FILTER (
            WHERE LOWER(TRIM(o.order_status)) = 'delivered'
        ) AS delivered_orders,
        COUNT(*) FILTER (
            WHERE LOWER(TRIM(o.order_status)) = 'returned'
        ) AS returned_orders,
        COUNT(*) FILTER (
            WHERE LOWER(TRIM(o.order_status)) = 'cancelled'
        ) AS cancelled_orders,
        SUM(o.total_amount) FILTER (
            WHERE LOWER(TRIM(o.order_status)) <> 'cancelled'
        ) AS observed_order_revenue,
        AVG(o.total_amount) FILTER (
            WHERE LOWER(TRIM(o.order_status)) <> 'cancelled'
        ) AS average_order_value,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date
    FROM raw.orders AS o
    GROUP BY o.customer_id
)
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.customer_status,
    c.signup_date,
    COALESCE(co.total_orders, 0) AS total_orders,
    COALESCE(co.delivered_orders, 0) AS delivered_orders,
    COALESCE(co.returned_orders, 0) AS returned_orders,
    COALESCE(co.cancelled_orders, 0) AS cancelled_orders,
    COALESCE(co.observed_order_revenue, 0) AS observed_order_revenue,
    ROUND(co.average_order_value, 2) AS average_order_value,
    co.first_order_date,
    co.last_order_date
FROM raw.customers AS c
LEFT JOIN customer_orders AS co
    ON c.customer_id = co.customer_id
ORDER BY observed_order_revenue DESC, c.customer_id;


-- ============================================================
-- 2. CUSTOMER LIFETIME REVENUE
--
-- Definition:
-- Sum of order totals for non-cancelled orders associated
-- with each customer across the available dataset.
--
-- This is observed lifetime revenue, not predictive CLV.
-- ============================================================

SELECT
    c.customer_id,
    c.customer_name,
    COUNT(o.order_id) AS qualifying_orders,
    COALESCE(SUM(o.total_amount), 0) AS customer_lifetime_revenue,
    ROUND(
        COALESCE(AVG(o.total_amount), 0),
        2
    ) AS average_order_value,
    MIN(o.order_date) AS first_purchase_date,
    MAX(o.order_date) AS most_recent_purchase_date
FROM raw.customers AS c
LEFT JOIN raw.orders AS o
    ON c.customer_id = o.customer_id
   AND LOWER(TRIM(o.order_status)) <> 'cancelled'
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY customer_lifetime_revenue DESC, c.customer_id;


-- ============================================================
-- 3. REPEAT CUSTOMER ANALYSIS
--
-- Definition:
-- A repeat customer has placed at least two non-cancelled
-- orders during the observed dataset period.
--
-- This is a customer-level repeat-purchase measure, not a
-- cohort-based retention metric.
-- ============================================================

WITH customer_order_counts AS (
    SELECT
        c.customer_id,
        COUNT(o.order_id) FILTER (
            WHERE LOWER(TRIM(o.order_status)) <> 'cancelled'
        ) AS qualifying_orders
    FROM raw.customers AS c
    LEFT JOIN raw.orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (
        WHERE qualifying_orders >= 1
    ) AS customers_with_orders,
    COUNT(*) FILTER (
        WHERE qualifying_orders >= 2
    ) AS repeat_customers,
    COUNT(*) FILTER (
        WHERE qualifying_orders = 1
    ) AS one_time_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE qualifying_orders >= 2
        ) / NULLIF(
            COUNT(*) FILTER (
                WHERE qualifying_orders >= 1
            ),
            0
        ),
        2
    ) AS repeat_customer_rate_pct
FROM customer_order_counts;


-- ============================================================
-- 4. CUSTOMER REVENUE SEGMENTATION
--
-- Segments are derived from observed customer revenue.
-- Thresholds are illustrative and can be adjusted.
--
-- High Value:  revenue >= 10000
-- Medium Value: revenue >= 3000 and < 10000
-- Low Value:   revenue < 3000
--
-- Customers without qualifying orders have zero revenue.
-- ============================================================

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.customer_name,
        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE LOWER(TRIM(o.order_status)) <> 'cancelled'
            ),
            0
        ) AS lifetime_revenue
    FROM raw.customers AS c
    LEFT JOIN raw.orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
),
segmented_customers AS (
    SELECT
        customer_id,
        customer_name,
        lifetime_revenue,
        CASE
            WHEN lifetime_revenue >= 10000 THEN 'High Value'
            WHEN lifetime_revenue >= 3000 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS revenue_segment
    FROM customer_revenue
)
SELECT
    revenue_segment,
    COUNT(*) AS customer_count,
    ROUND(
        SUM(lifetime_revenue),
        2
    ) AS total_customer_revenue,
    ROUND(
        AVG(lifetime_revenue),
        2
    ) AS average_revenue_per_customer,
    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS customer_share_pct
FROM segmented_customers
GROUP BY revenue_segment
ORDER BY
    CASE revenue_segment
        WHEN 'High Value' THEN 1
        WHEN 'Medium Value' THEN 2
        ELSE 3
    END;


-- ============================================================
-- 5. TOP 10 CUSTOMERS BY OBSERVED REVENUE
-- ============================================================

SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    COUNT(o.order_id) AS qualifying_orders,
    ROUND(
        SUM(o.total_amount),
        2
    ) AS observed_revenue,
    ROUND(
        AVG(o.total_amount),
        2
    ) AS average_order_value,
    MAX(o.order_date) AS most_recent_order_date
FROM raw.customers AS c
JOIN raw.orders AS o
    ON c.customer_id = o.customer_id
WHERE LOWER(TRIM(o.order_status)) <> 'cancelled'
GROUP BY
    c.customer_id,
    c.customer_name,
    c.customer_segment
ORDER BY observed_revenue DESC, c.customer_id
LIMIT 10;


-- ============================================================
-- 6. CUSTOMER PURCHASE FREQUENCY
--
-- Average number of days between consecutive qualifying
-- orders for each customer.
--
-- Customers with fewer than two qualifying orders will have
-- a NULL average interval.
-- ============================================================

WITH qualifying_orders AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        LAG(order_date) OVER (
            PARTITION BY customer_id
            ORDER BY order_date, order_id
        ) AS previous_order_date
    FROM raw.orders
    WHERE LOWER(TRIM(order_status)) <> 'cancelled'
)
SELECT
    customer_id,
    COUNT(*) AS qualifying_orders,
    COUNT(previous_order_date) AS repeat_purchase_intervals,
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (order_date - previous_order_date)
            ) / 86400.0
        )::NUMERIC,
        2
    ) AS average_days_between_orders
FROM qualifying_orders
GROUP BY customer_id
ORDER BY average_days_between_orders NULLS LAST, customer_id;


-- ============================================================
-- 7. INACTIVE CUSTOMERS
--
-- Definition:
-- Customers who have not placed a qualifying order during
-- the previous 90 days relative to the latest observed order
-- date in the database.
--
-- This uses the dataset's maximum order date instead of
-- CURRENT_DATE, making results reproducible for synthetic data.
--
-- Customers who have never ordered are included separately.
-- ============================================================

WITH dataset_reference AS (
    SELECT MAX(order_date) AS reference_date
    FROM raw.orders
),
customer_activity AS (
    SELECT
        c.customer_id,
        c.customer_name,
        MAX(o.order_date) FILTER (
            WHERE LOWER(TRIM(o.order_status)) <> 'cancelled'
        ) AS last_qualifying_order_date
    FROM raw.customers AS c
    LEFT JOIN raw.orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
)
SELECT
    ca.customer_id,
    ca.customer_name,
    ca.last_qualifying_order_date,
    dr.reference_date,
    CASE
        WHEN ca.last_qualifying_order_date IS NULL
            THEN 'NEVER_PURCHASED'
        WHEN ca.last_qualifying_order_date
             < dr.reference_date - INTERVAL '90 days'
            THEN 'INACTIVE_OVER_90_DAYS'
        ELSE 'RECENTLY_ACTIVE'
    END AS customer_activity_status
FROM customer_activity AS ca
CROSS JOIN dataset_reference AS dr
WHERE ca.last_qualifying_order_date IS NULL
   OR ca.last_qualifying_order_date
      < dr.reference_date - INTERVAL '90 days'
ORDER BY ca.last_qualifying_order_date NULLS FIRST;


-- ============================================================
-- 8. MONTHLY CUSTOMER ACQUISITION
--
-- Grain: One row per signup month.
-- ============================================================

SELECT
    DATE_TRUNC('month', signup_date)::DATE AS signup_month,
    COUNT(*) AS new_customers,
    COUNT(*) FILTER (
        WHERE customer_status IS NOT NULL
    ) AS customers_with_status
FROM raw.customers
WHERE signup_date IS NOT NULL
GROUP BY DATE_TRUNC('month', signup_date)::DATE
ORDER BY signup_month;


-- ============================================================
-- 9. MONTHLY REPEAT-PURCHASE RETENTION PROXY
--
-- Definition:
-- For each first-purchase month, measure the percentage of
-- customers who also purchased in a later calendar month.
--
-- This is a simple observed repeat-purchase proxy, not a full
-- cohort-retention matrix.
-- ============================================================

WITH qualifying_orders AS (
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', order_date)::DATE AS order_month
    FROM raw.orders
    WHERE LOWER(TRIM(order_status)) <> 'cancelled'
),
first_purchase AS (
    SELECT
        customer_id,
        MIN(order_month) AS first_purchase_month
    FROM qualifying_orders
    GROUP BY customer_id
),
customer_repeat_status AS (
    SELECT
        fp.first_purchase_month,
        fp.customer_id,
        BOOL_OR(
            qo.order_month > fp.first_purchase_month
        ) AS purchased_in_a_later_month
    FROM first_purchase AS fp
    JOIN qualifying_orders AS qo
        ON fp.customer_id = qo.customer_id
    GROUP BY
        fp.first_purchase_month,
        fp.customer_id
)
SELECT
    first_purchase_month,
    COUNT(*) AS cohort_customers,
    COUNT(*) FILTER (
        WHERE purchased_in_a_later_month
    ) AS customers_who_purchased_again,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE purchased_in_a_later_month
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_purchase_rate_pct
FROM customer_repeat_status
GROUP BY first_purchase_month
ORDER BY first_purchase_month;


-- ============================================================
-- 10. CUSTOMER REVENUE CONCENTRATION
--
-- Shows the percentage of observed customer revenue generated
-- by the top 10% of customers ranked by revenue.
--
-- Uses order-level total_amount and excludes cancelled orders.
-- ============================================================

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE LOWER(TRIM(o.order_status)) <> 'cancelled'
            ),
            0
        ) AS lifetime_revenue
    FROM raw.customers AS c
    LEFT JOIN raw.orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
),
ranked_customers AS (
    SELECT
        customer_id,
        lifetime_revenue,
        ROW_NUMBER() OVER (
            ORDER BY lifetime_revenue DESC, customer_id
        ) AS customer_rank,
        COUNT(*) OVER () AS total_customers
    FROM customer_revenue
),
revenue_summary AS (
    SELECT
        SUM(lifetime_revenue) AS total_revenue,
        SUM(lifetime_revenue) FILTER (
            WHERE customer_rank <= CEIL(total_customers * 0.10)
        ) AS top_10_pct_revenue
    FROM ranked_customers
)
SELECT
    total_revenue,
    COALESCE(top_10_pct_revenue, 0) AS top_10_pct_revenue,
    ROUND(
        100.0 * top_10_pct_revenue
        / NULLIF(total_revenue, 0),
        2
    ) AS top_10_pct_revenue_share
FROM revenue_summary;


-- ============================================================
-- END OF CUSTOMER ANALYSIS
-- ============================================================