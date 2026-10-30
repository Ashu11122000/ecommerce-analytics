
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: forecast_analysis.sql
-- Purpose:
--   1. Analyze monthly historical revenue.
--   2. Calculate month-over-month growth.
--   3. Calculate a 3-month rolling average.
--   4. Forecast revenue using a rolling-average method.
--   5. Forecast revenue using a linear trend.
--   6. Compare actual revenue with the rolling forecast.
--   7. Identify unusually high or low revenue months.
--
-- Source tables:
--   raw.orders
--   raw.order_items
--
-- Grain:
--   One row per calendar month, unless otherwise specified.
-- ============================================================


-- ============================================================
-- 1. MONTHLY HISTORICAL REVENUE
-- Purpose:
--   Establish the monthly time series used by later forecasts.
-- Output grain: one row per month.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        COUNT(*) AS order_count,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS average_order_value
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
      AND total_amount IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::DATE
)
SELECT
    month_start,
    order_count,
    ROUND(total_revenue::NUMERIC, 2) AS total_revenue,
    ROUND(average_order_value::NUMERIC, 2) AS average_order_value
FROM monthly_revenue
ORDER BY month_start;


-- ============================================================
-- 2. MONTH-OVER-MONTH REVENUE GROWTH
-- Purpose:
--   Measure monthly revenue changes and growth percentages.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS total_revenue
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
      AND total_amount IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
monthly_comparison AS (
    SELECT
        month_start,
        total_revenue,
        LAG(total_revenue) OVER (
            ORDER BY month_start
        ) AS previous_observed_month_revenue
    FROM monthly_revenue
)
SELECT
    month_start,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(previous_observed_month_revenue, 2)
        AS previous_observed_month_revenue,
    ROUND(
        total_revenue - previous_observed_month_revenue,
        2
    ) AS revenue_change,
    ROUND(
        100.0 * (
            total_revenue - previous_observed_month_revenue
        ) / NULLIF(previous_observed_month_revenue, 0),
        2
    ) AS revenue_growth_pct
FROM monthly_comparison
ORDER BY month_start;


-- ============================================================
-- 3. COMPLETE MONTHLY SERIES WITH A 3-MONTH ROLLING AVERAGE
-- Purpose:
--   Fill missing calendar months with zero and smooth short-term
--   fluctuations using the current month and previous two months.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS total_revenue
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
        COALESCE(m.total_revenue, 0)::NUMERIC AS total_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue m
        ON c.month_start = m.month_start
),
rolling_metrics AS (
    SELECT
        month_start,
        total_revenue,
        AVG(total_revenue) OVER (
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_month_average,
        COUNT(*) OVER (
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS months_in_rolling_window
    FROM complete_series
)
SELECT
    month_start,
    ROUND(total_revenue, 2) AS actual_revenue,
    ROUND(rolling_3_month_average, 2)
        AS rolling_3_month_average,
    months_in_rolling_window
FROM rolling_metrics
ORDER BY month_start;


-- ============================================================
-- 4. NEXT 3 MONTHS: ROLLING-AVERAGE FORECAST
-- Purpose:
--   Forecast each of the next three months using the average
--   revenue from the latest three observed calendar months.
--
-- Important:
--   This is a baseline forecast. It does not model seasonality
--   or future changes in customer demand.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS total_revenue
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
        COALESCE(m.total_revenue, 0)::NUMERIC AS total_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue m
        ON c.month_start = m.month_start
),
latest_months AS (
    SELECT
        month_start,
        total_revenue
    FROM complete_series
    ORDER BY month_start DESC
    LIMIT 3
),
forecast_baseline AS (
    SELECT
        AVG(total_revenue) AS forecast_revenue,
        COUNT(*) AS months_used,
        MAX(month_start) AS last_actual_month
    FROM latest_months
)
SELECT
    (
        last_actual_month
        + (forecast_offset * INTERVAL '1 month')
    )::DATE AS forecast_month,
    forecast_offset AS forecast_horizon_month,
    ROUND(forecast_revenue, 2) AS forecast_revenue,
    months_used AS historical_months_used,
    last_actual_month
FROM forecast_baseline
CROSS JOIN GENERATE_SERIES(1, 3) AS forecast_offset
WHERE months_used > 0
ORDER BY forecast_month;


-- ============================================================
-- 5. NEXT 3 MONTHS: LINEAR TREND FORECAST
-- Purpose:
--   Fit a simple linear trend to monthly revenue.
--   The model uses the calendar-month index as X and revenue
--   as Y, then extrapolates three months forward.
--
-- Limitations:
--   - Sensitive to outliers.
--   - Does not model seasonality.
--   - More useful with a longer history of monthly data.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS total_revenue
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
        COALESCE(m.total_revenue, 0)::NUMERIC AS total_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue m
        ON c.month_start = m.month_start
),
indexed_series AS (
    SELECT
        month_start,
        total_revenue,
        ROW_NUMBER() OVER (
            ORDER BY month_start
        )::NUMERIC AS month_index
    FROM complete_series
),
trend_parameters AS (
    SELECT
        REGR_SLOPE(total_revenue, month_index) AS slope,
        REGR_INTERCEPT(total_revenue, month_index) AS intercept,
        MAX(month_index) AS last_month_index,
        MAX(month_start) AS last_actual_month,
        COUNT(*) AS historical_months
    FROM indexed_series
),
forecast_months AS (
    SELECT
        forecast_offset,
        last_actual_month,
        last_month_index + forecast_offset AS forecast_index,
        slope,
        intercept,
        historical_months
    FROM trend_parameters
    CROSS JOIN GENERATE_SERIES(1, 3) AS forecast_offset
    WHERE historical_months >= 2
      AND slope IS NOT NULL
      AND intercept IS NOT NULL
)
SELECT
    (
        last_actual_month
        + (forecast_offset * INTERVAL '1 month')
    )::DATE AS forecast_month,
    forecast_offset AS forecast_horizon_month,
    ROUND(
        (intercept + slope * forecast_index)::NUMERIC,
        2
    ) AS linear_trend_forecast,
    ROUND(slope::NUMERIC, 2) AS estimated_monthly_trend,
    historical_months
FROM forecast_months
ORDER BY forecast_month;


-- ============================================================
-- 6. ACTUAL REVENUE VS. PREVIOUS 3-MONTH AVERAGE
-- Purpose:
--   Compare each month's actual revenue with the average of
--   the three preceding months, excluding the current month.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS total_revenue
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
        COALESCE(m.total_revenue, 0)::NUMERIC AS total_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue m
        ON c.month_start = m.month_start
),
comparisons AS (
    SELECT
        month_start,
        total_revenue,
        AVG(total_revenue) OVER (
            ORDER BY month_start
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS previous_3_month_average,
        COUNT(*) OVER (
            ORDER BY month_start
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS prior_months_available
    FROM complete_series
)
SELECT
    month_start,
    ROUND(total_revenue, 2) AS actual_revenue,
    ROUND(previous_3_month_average, 2)
        AS previous_3_month_average,
    ROUND(
        total_revenue - previous_3_month_average,
        2
    ) AS variance_from_baseline,
    ROUND(
        100.0 * (
            total_revenue - previous_3_month_average
        ) / NULLIF(previous_3_month_average, 0),
        2
    ) AS variance_pct,
    CASE
        WHEN prior_months_available < 3
            THEN 'INSUFFICIENT HISTORY'
        WHEN total_revenue > previous_3_month_average
            THEN 'ABOVE BASELINE'
        WHEN total_revenue < previous_3_month_average
            THEN 'BELOW BASELINE'
        ELSE 'AT BASELINE'
    END AS revenue_signal
FROM comparisons
ORDER BY month_start;


-- ============================================================
-- 7. MONTHLY REVENUE ANOMALY DETECTION
-- Purpose:
--   Flag months whose revenue is more than two standard
--   deviations away from the historical monthly mean.
--
-- Important:
--   This is a simple statistical screening rule, not proof
--   that the month contains a business or data-quality error.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS total_revenue
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
        COALESCE(m.total_revenue, 0)::NUMERIC AS total_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue m
        ON c.month_start = m.month_start
),
statistics AS (
    SELECT
        month_start,
        total_revenue,
        AVG(total_revenue) OVER () AS mean_revenue,
        STDDEV_SAMP(total_revenue) OVER () AS revenue_stddev
    FROM complete_series
)
SELECT
    month_start,
    ROUND(total_revenue, 2) AS actual_revenue,
    ROUND(mean_revenue, 2) AS historical_mean,
    ROUND(revenue_stddev, 2) AS historical_stddev,
    CASE
        WHEN revenue_stddev IS NULL OR revenue_stddev = 0
            THEN 'NOT ENOUGH VARIATION'
        WHEN total_revenue > mean_revenue + (2 * revenue_stddev)
            THEN 'HIGH REVENUE ANOMALY'
        WHEN total_revenue < mean_revenue - (2 * revenue_stddev)
            THEN 'LOW REVENUE ANOMALY'
        ELSE 'NORMAL RANGE'
    END AS anomaly_status
FROM statistics
ORDER BY month_start;


-- ============================================================
-- 8. FORECAST READINESS CHECK
-- Purpose:
--   Check whether enough monthly history exists to support
--   a basic forecast.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS total_revenue
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
        COALESCE(m.total_revenue, 0)::NUMERIC AS total_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue m
        ON c.month_start = m.month_start
)
SELECT
    COUNT(*) AS historical_calendar_months,
    MIN(month_start) AS first_month,
    MAX(month_start) AS last_month,
    ROUND(AVG(total_revenue), 2) AS average_monthly_revenue,
    CASE
        WHEN COUNT(*) < 3
            THEN 'LIMITED HISTORY: USE FORECASTS WITH CAUTION'
        WHEN COUNT(*) < 6
            THEN 'BASIC FORECASTING POSSIBLE'
        ELSE 'SUFFICIENT FOR BASIC TREND EXPLORATION'
    END AS forecast_readiness
FROM complete_series;


-- ============================================================
-- END OF forecast_analysis.sql
-- ============================================================
