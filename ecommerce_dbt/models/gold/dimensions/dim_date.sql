
-- ============================================================
-- Model: dim_date
-- Layer: Gold
-- Grain: One row per calendar date (full_date)
--
-- Purpose:
--   Create a reusable date dimension for time-based analytics.
--   Support filtering, grouping, period comparisons, and
--   time-series reporting across business metrics.
--
-- Source:
--   silver_orders
--
-- Transformations:
--   1. Derive date boundaries from available order dates.
--   2. Generate every calendar date between those boundaries.
--   3. Create a YYYYMMDD integer date key.
--   4. Add calendar, week, month, quarter, and weekend attributes.
--   5. Add a Gold modeling timestamp.
--
-- Important assumptions:
--   - The date range is based on order dates currently available.
--   - The calendar includes both boundary dates.
--   - Week numbering follows PostgreSQL's EXTRACT(WEEK) convention,
--     which uses ISO week numbering.
--   - day_of_week follows PostgreSQL DOW:
--     Sunday = 0, Monday = 1, ..., Saturday = 6.
--   - is_weekend identifies Saturday and Sunday.
--   - This model does not generate dates when no valid order dates
--     are available.
-- ============================================================

WITH date_range AS (

    -- Step 1: Find the earliest and latest available order dates.
    -- Casting to DATE removes the time portion of timestamps.
    SELECT
        MIN(order_date::DATE) AS min_date,
        MAX(order_date::DATE) AS max_date

    FROM {{ ref('silver_orders') }}

),

date_series AS (

    -- Step 2: Generate one row per calendar day, inclusive
    -- of the minimum and maximum order dates.
    SELECT
        GENERATE_SERIES(
            min_date,
            max_date,
            INTERVAL '1 day'
        )::DATE AS date_day

    FROM date_range

    -- Guard against empty source data or missing order dates.
    WHERE min_date IS NOT NULL
      AND max_date IS NOT NULL
      AND min_date <= max_date

)

-- Step 3: Add reusable calendar attributes to each date.
SELECT

    -- Integer date key in YYYYMMDD format.
    -- Example: 20261027 represents October 27, 2026.
    TO_CHAR(date_day, 'YYYYMMDD')::INTEGER AS date_key,

    -- Full date for joins and time-based analysis.
    date_day AS full_date,

    -- Calendar year.
    EXTRACT(YEAR FROM date_day)::INTEGER AS year,

    -- Calendar quarter: 1, 2, 3, or 4.
    EXTRACT(QUARTER FROM date_day)::INTEGER AS quarter,

    -- Calendar month: 1 through 12.
    EXTRACT(MONTH FROM date_day)::INTEGER AS month,

    -- Month name without PostgreSQL's trailing padding.
    TRIM(TO_CHAR(date_day, 'Month')) AS month_name,

    -- ISO week number (1 through 53).
    -- The ISO week-year can differ from the calendar year
    -- near the beginning and end of a calendar year.
    EXTRACT(WEEK FROM date_day)::INTEGER AS week_of_year,

    -- Day of the calendar month: 1 through 31.
    EXTRACT(DAY FROM date_day)::INTEGER AS day_of_month,

    -- PostgreSQL DOW numbering:
    -- Sunday = 0, Monday = 1, ..., Saturday = 6.
    EXTRACT(DOW FROM date_day)::INTEGER AS day_of_week,

    -- Day name without trailing padding.
    TRIM(TO_CHAR(date_day, 'Day')) AS day_name,

    -- Saturday and Sunday are classified as weekends.
    CASE
        WHEN EXTRACT(ISODOW FROM date_day) IN (6, 7)
            THEN TRUE
        ELSE FALSE
    END AS is_weekend,

    -- True for the final calendar date of each month.
    CASE
        WHEN date_day = (
            DATE_TRUNC('month', date_day)
            + INTERVAL '1 month'
            - INTERVAL '1 day'
        )::DATE
            THEN TRUE
        ELSE FALSE
    END AS is_month_end,

    -- Readable quarter label, such as Q3-2026.
    'Q'
        || EXTRACT(QUARTER FROM date_day)::INTEGER
        || '-'
        || EXTRACT(YEAR FROM date_day)::INTEGER
        AS quarter_label,

    -- Sortable month label, such as 2026-10.
    TO_CHAR(date_day, 'YYYY-MM') AS month_label,

    -- Gold modeling timestamp.
    -- Persistence depends on the macro and materialization.
    {{ modeled_timestamp() }} AS modeled_at

FROM date_series
