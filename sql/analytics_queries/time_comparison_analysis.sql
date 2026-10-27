
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: time_comparison_analysis.sql
-- Purpose:
--   Compare sales, order volume, and customer activity across
--   different time periods.
--
-- Target personas:
--   Business leadership, finance analysts, sales analysts.
--
-- Source tables:
--   raw.orders
--   raw.order_items
--
-- Metrics:
--   - Revenue: SUM(raw.orders.total_amount)
--   - Orders: COUNT(DISTINCT order_id)
--   - Average order value: revenue / order count
--   - Units ordered: SUM(raw.order_items.quantity)
--   - Merchandise revenue: SUM(raw.order_items.line_total)
--
-- Assumptions:
--   - Cancelled orders are excluded from commercial sales metrics.
--   - Returned orders remain included unless separately excluded.
--   - Weeks begin on Monday, following PostgreSQL DATE_TRUNC.
--   - Comparisons use order_date as the reporting date.
--   - Revenue is not equivalent to profit or cash collected.
--   - Missing calendar periods are filled with zero for the
--     calendar-based comparisons in this file.
--   - Zero-filled periods are valid only within the observed
--     minimum and maximum order-date range.
--
-- All queries are read-only.
-- ============================================================


-- ============================================================
-- 1. MONTH-OVER-MONTH (MoM) REVENUE COMPARISON
-- Dashboard visualization:
--   Line chart or table with monthly revenue and growth.
-- Grain: one row per calendar month.
-- ============================================================

WITH eligible_orders AS (
    SELECT
        order_id,
        order_date,
        total_amount
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
),
monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS revenue
    FROM eligible_orders
    WHERE total_amount IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
date_bounds AS (
    SELECT
        MIN(month_start) AS first_month,
        MAX(month_start) AS last_month
    FROM monthly_revenue
),
calendar AS (
    SELECT
        GENERATE_SERIES(
            first_month,
            last_month,
            INTERVAL '1 month'
        )::DATE AS month_start
    FROM date_bounds
    WHERE first_month IS NOT NULL
),
complete_series AS (
    SELECT
        c.month_start,
        COALESCE(mr.revenue, 0)::NUMERIC AS revenue
    FROM calendar c
    LEFT JOIN monthly_revenue mr
        ON mr.month_start = c.month_start
),
comparison AS (
    SELECT
        month_start,
        revenue,
        LAG(revenue) OVER (
            ORDER BY month_start
        ) AS previous_month_revenue
    FROM complete_series
)
SELECT
    month_start,
    ROUND(revenue, 2) AS revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,

    ROUND(
        revenue - previous_month_revenue,
        2
    ) AS revenue_change,

    ROUND(
        100.0 * (revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0),
        2
    ) AS revenue_growth_pct

FROM comparison
ORDER BY month_start;


-- ============================================================
-- 2. MONTH-OVER-MONTH (MoM) ORDER VOLUME COMPARISON
-- Dashboard visualization:
--   Line chart for order count and monthly change.
-- Grain: one row per calendar month.
-- ============================================================

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        COUNT(*) AS order_count
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
date_bounds AS (
    SELECT
        MIN(month_start) AS first_month,
        MAX(month_start) AS last_month
    FROM monthly_orders
),
calendar AS (
    SELECT
        GENERATE_SERIES(
            first_month,
            last_month,
            INTERVAL '1 month'
        )::DATE AS month_start
    FROM date_bounds
    WHERE first_month IS NOT NULL
),
complete_series AS (
    SELECT
        c.month_start,
        COALESCE(mo.order_count, 0) AS order_count
    FROM calendar c
    LEFT JOIN monthly_orders mo
        ON mo.month_start = c.month_start
),
comparison AS (
    SELECT
        month_start,
        order_count,
        LAG(order_count) OVER (
            ORDER BY month_start
        ) AS previous_month_order_count
    FROM complete_series
)
SELECT
    month_start,
    order_count,
    previous_month_order_count,

    order_count - previous_month_order_count
        AS order_count_change,

    ROUND(
        100.0 * (order_count - previous_month_order_count)
        / NULLIF(previous_month_order_count, 0),
        2
    ) AS order_growth_pct

FROM comparison
ORDER BY month_start;


-- ============================================================
-- 3. WEEK-OVER-WEEK (WoW) REVENUE COMPARISON
-- Dashboard visualization:
--   Weekly revenue trend chart.
--
-- Week definition:
--   Monday through Sunday.
-- Grain: one row per calendar week.
-- ============================================================

WITH weekly_revenue AS (
    SELECT
        DATE_TRUNC('week', order_date)::DATE AS week_start,
        SUM(total_amount)::NUMERIC AS revenue
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
      AND total_amount IS NOT NULL
    GROUP BY DATE_TRUNC('week', order_date)::DATE
),
date_bounds AS (
    SELECT
        MIN(week_start) AS first_week,
        MAX(week_start) AS last_week
    FROM weekly_revenue
),
calendar AS (
    SELECT
        GENERATE_SERIES(
            first_week,
            last_week,
            INTERVAL '1 week'
        )::DATE AS week_start
    FROM date_bounds
    WHERE first_week IS NOT NULL
),
complete_series AS (
    SELECT
        c.week_start,
        COALESCE(wr.revenue, 0)::NUMERIC AS revenue
    FROM calendar c
    LEFT JOIN weekly_revenue wr
        ON wr.week_start = c.week_start
),
comparison AS (
    SELECT
        week_start,
        revenue,
        LAG(revenue) OVER (
            ORDER BY week_start
        ) AS previous_week_revenue
    FROM complete_series
)
SELECT
    week_start,
    ROUND(revenue, 2) AS revenue,
    ROUND(previous_week_revenue, 2) AS previous_week_revenue,

    ROUND(
        revenue - previous_week_revenue,
        2
    ) AS revenue_change,

    ROUND(
        100.0 * (revenue - previous_week_revenue)
        / NULLIF(previous_week_revenue, 0),
        2
    ) AS revenue_growth_pct

FROM comparison
ORDER BY week_start;


-- ============================================================
-- 4. YEAR-OVER-YEAR (YoY) MONTHLY REVENUE COMPARISON
-- Dashboard visualization:
--   Multi-series line chart comparing calendar years.
--
-- Important:
--   A meaningful YoY comparison requires data from at least
--   two different years for matching months.
-- Grain: one row per calendar month.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS revenue
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
      AND total_amount IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
date_bounds AS (
    SELECT
        MIN(month_start) AS first_month,
        MAX(month_start) AS last_month
    FROM monthly_revenue
),
calendar AS (
    SELECT
        GENERATE_SERIES(
            first_month,
            last_month,
            INTERVAL '1 month'
        )::DATE AS month_start
    FROM date_bounds
    WHERE first_month IS NOT NULL
),
complete_series AS (
    SELECT
        c.month_start,
        COALESCE(mr.revenue, 0)::NUMERIC AS revenue
    FROM calendar c
    LEFT JOIN monthly_revenue mr
        ON mr.month_start = c.month_start
),
comparison AS (
    SELECT
        month_start,
        revenue,
        LAG(revenue, 12) OVER (
            ORDER BY month_start
        ) AS same_month_previous_year_revenue
    FROM complete_series
)
SELECT
    month_start,
    ROUND(revenue, 2) AS revenue,

    ROUND(
        same_month_previous_year_revenue,
        2
    ) AS same_month_previous_year_revenue,

    ROUND(
        revenue - same_month_previous_year_revenue,
        2
    ) AS yoy_revenue_change,

    ROUND(
        100.0 * (
            revenue - same_month_previous_year_revenue
        ) / NULLIF(same_month_previous_year_revenue, 0),
        2
    ) AS yoy_revenue_growth_pct

FROM comparison
ORDER BY month_start;


-- ============================================================
-- 5. YEAR-OVER-YEAR (YoY) MONTHLY ORDER COMPARISON
-- Dashboard visualization:
--   Multi-series chart comparing monthly order counts by year.
-- Grain: one row per calendar month.
-- ============================================================

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        COUNT(*) AS order_count
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
date_bounds AS (
    SELECT
        MIN(month_start) AS first_month,
        MAX(month_start) AS last_month
    FROM monthly_orders
),
calendar AS (
    SELECT
        GENERATE_SERIES(
            first_month,
            last_month,
            INTERVAL '1 month'
        )::DATE AS month_start
    FROM date_bounds
    WHERE first_month IS NOT NULL
),
complete_series AS (
    SELECT
        c.month_start,
        COALESCE(mo.order_count, 0) AS order_count
    FROM calendar c
    LEFT JOIN monthly_orders mo
        ON mo.month_start = c.month_start
),
comparison AS (
    SELECT
        month_start,
        order_count,
        LAG(order_count, 12) OVER (
            ORDER BY month_start
        ) AS same_month_previous_year_orders
    FROM complete_series
)
SELECT
    month_start,
    order_count,
    same_month_previous_year_orders,

    order_count - same_month_previous_year_orders
        AS yoy_order_count_change,

    ROUND(
        100.0 * (
            order_count - same_month_previous_year_orders
        ) / NULLIF(same_month_previous_year_orders, 0),
        2
    ) AS yoy_order_growth_pct

FROM comparison
ORDER BY month_start;


-- ============================================================
-- 6. THREE-MONTH ROLLING REVENUE AVERAGE
-- Dashboard visualization:
--   Line chart with actual revenue and smoothed revenue.
-- Grain: one row per calendar month.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS revenue
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
      AND total_amount IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
date_bounds AS (
    SELECT
        MIN(month_start) AS first_month,
        MAX(month_start) AS last_month
    FROM monthly_revenue
),
calendar AS (
    SELECT
        GENERATE_SERIES(
            first_month,
            last_month,
            INTERVAL '1 month'
        )::DATE AS month_start
    FROM date_bounds
    WHERE first_month IS NOT NULL
),
complete_series AS (
    SELECT
        c.month_start,
        COALESCE(mr.revenue, 0)::NUMERIC AS revenue
    FROM calendar c
    LEFT JOIN monthly_revenue mr
        ON mr.month_start = c.month_start
)
SELECT
    month_start,
    ROUND(revenue, 2) AS monthly_revenue,

    ROUND(
        AVG(revenue) OVER (
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS rolling_3_month_average,

    COUNT(*) OVER (
        ORDER BY month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS months_in_rolling_window

FROM complete_series
ORDER BY month_start;


-- ============================================================
-- 7. YEAR-TO-DATE (YTD) REVENUE
-- Dashboard visualization:
--   KPI cards or cumulative line chart.
-- Grain: one row per calendar month.
--
-- Note:
--   Each calendar year's cumulative total resets in January.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS revenue
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
      AND total_amount IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::DATE
)
SELECT
    month_start,
    ROUND(revenue, 2) AS monthly_revenue,

    ROUND(
        SUM(revenue) OVER (
            PARTITION BY EXTRACT(YEAR FROM month_start)
            ORDER BY month_start
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS year_to_date_revenue

FROM monthly_revenue
ORDER BY month_start;


-- ============================================================
-- 8. YEAR-TO-DATE ORDER COUNT
-- Dashboard visualization:
--   Cumulative order count line chart.
-- Grain: one row per calendar month.
-- ============================================================

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        COUNT(*) AS order_count
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
    GROUP BY DATE_TRUNC('month', order_date)::DATE
)
SELECT
    month_start,
    order_count,

    SUM(order_count) OVER (
        PARTITION BY EXTRACT(YEAR FROM month_start)
        ORDER BY month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS year_to_date_orders

FROM monthly_orders
ORDER BY month_start;


-- ============================================================
-- 9. AVERAGE ORDER VALUE TREND
-- Dashboard visualization:
--   Line chart showing monthly average order value.
-- Grain: one row per calendar month.
-- ============================================================

SELECT
    DATE_TRUNC('month', order_date)::DATE AS month_start,

    COUNT(*) AS order_count,

    ROUND(
        SUM(total_amount)::NUMERIC,
        2
    ) AS monthly_revenue,

    ROUND(
        AVG(total_amount)::NUMERIC,
        2
    ) AS average_order_value

FROM raw.orders
WHERE order_date IS NOT NULL
  AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
  AND total_amount IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)::DATE
ORDER BY month_start;


-- ============================================================
-- 10. PERIOD COMPARISON READINESS
-- Purpose:
--   Check the date range and number of months and years
--   available for time-based comparisons.
-- Dashboard visualization:
--   Data-readiness KPI table.
-- Grain: one row for the dataset.
-- ============================================================

WITH monthly_data AS (
    SELECT DISTINCT
        DATE_TRUNC('month', order_date)::DATE AS month_start
    FROM raw.orders
    WHERE order_date IS NOT NULL
)
SELECT
    MIN(month_start) AS first_observed_month,
    MAX(month_start) AS last_observed_month,
    COUNT(*) AS observed_month_count,
    COUNT(DISTINCT EXTRACT(YEAR FROM month_start))
        AS observed_year_count,

    CASE
        WHEN COUNT(*) < 2
            THEN 'Insufficient history for monthly growth'
        WHEN COUNT(DISTINCT EXTRACT(YEAR FROM month_start)) < 2
            THEN 'MoM possible; YoY needs multiple years'
        ELSE 'MoM and potential YoY comparisons available'
    END AS comparison_readiness

FROM monthly_data;


-- ============================================================
-- END OF time_comparison_analysis.sql
-- ============================================================
