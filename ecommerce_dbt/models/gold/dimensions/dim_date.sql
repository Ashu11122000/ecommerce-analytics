WITH date_range AS (

    SELECT
        MIN(order_date::DATE) AS min_date,
        MAX(order_date::DATE) AS max_date

    FROM {{ ref('silver_orders') }}

),

date_series AS (

    SELECT
        GENERATE_SERIES(
            min_date,
            max_date,
            INTERVAL '1 day'
        )::DATE AS date_day

    FROM date_range

)

SELECT
    -- Surrogate date key in YYYYMMDD format
    TO_CHAR(date_day, 'YYYYMMDD')::INTEGER AS date_key,

    date_day AS full_date,

    -- Calendar attributes
    EXTRACT(YEAR FROM date_day)::INTEGER AS year,
    EXTRACT(QUARTER FROM date_day)::INTEGER AS quarter,
    EXTRACT(MONTH FROM date_day)::INTEGER AS month,
    TO_CHAR(date_day, 'Month') AS month_name,
    
    EXTRACT(WEEK FROM date_day)::INTEGER AS week_of_year,
    EXTRACT(DAY FROM date_day)::INTEGER AS day_of_month,
    EXTRACT(DOW FROM date_day)::INTEGER AS day_of_week,
    TO_CHAR(date_day, 'Day') AS day_name,

    -- Weekend indicator
    CASE
        WHEN EXTRACT(ISODOW FROM date_day) IN (6, 7)
            THEN TRUE
        ELSE FALSE
    END AS is_weekend,

    -- Month-end indicator
    CASE
        WHEN date_day = (
            DATE_TRUNC('month', date_day)
            + INTERVAL '1 month'
            - INTERVAL '1 day'
        )::DATE
            THEN TRUE
        ELSE FALSE
    END AS is_month_end,

    -- Quarter label
    'Q'
    || EXTRACT(QUARTER FROM date_day)::INTEGER
    || '-'
    || EXTRACT(YEAR FROM date_day)::INTEGER AS quarter_label,

    -- Month label
    TO_CHAR(date_day, 'YYYY-MM') AS month_label,

    {{ modeled_timestamp() }} AS modeled_at

FROM date_series
