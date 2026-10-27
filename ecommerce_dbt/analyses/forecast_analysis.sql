
/*
    Analysis: Monthly Sales Forecast

    Purpose:
      1. Aggregate actual sales by month.
      2. Compare sales with the previous month.
      3. Calculate month-over-month growth.
      4. Forecast the next month using a three-month rolling average.
      5. Calculate forecast variance for historical months.

    Source:
      Gold fact_order_items

    Grain:
      One row per month, including one forecast row for the next month.

    Important:
      net_sales_amount includes tax in the current Gold model.
      The forecast is a simple baseline, not a production forecasting model.
*/

WITH monthly_sales AS (

    SELECT
        DATE_TRUNC(
            'month',
            TO_DATE(order_date_key::TEXT, 'YYYYMMDD')
        )::DATE AS sales_month,

        COUNT(DISTINCT order_id) AS order_count,

        COUNT(DISTINCT order_item_id) AS order_item_count,

        SUM(quantity) AS units_sold,

        SUM(gross_sales_amount) AS gross_sales,

        SUM(net_sales_amount) AS net_sales

    FROM gold.fact_order_items

    WHERE order_date_key IS NOT NULL

    GROUP BY 1
),

monthly_sales_with_previous AS (

    SELECT
        sales_month,
        order_count,
        order_item_count,
        units_sold,
        gross_sales,
        net_sales,

        LAG(net_sales) OVER (
            ORDER BY sales_month
        ) AS previous_month_sales,

        LAG(sales_month) OVER (
            ORDER BY sales_month
        ) AS previous_sales_month

    FROM monthly_sales
),

monthly_growth AS (

    SELECT
        sales_month,
        order_count,
        order_item_count,
        units_sold,
        gross_sales,
        net_sales,
        previous_month_sales,

        CASE
            WHEN previous_sales_month =
                 (sales_month - INTERVAL '1 month')::DATE
             AND previous_month_sales IS NOT NULL
             AND previous_month_sales <> 0
            THEN
                (
                    (net_sales - previous_month_sales)
                    / NULLIF(previous_month_sales, 0)
                ) * 100
            ELSE NULL
        END AS mom_growth_pct

    FROM monthly_sales_with_previous
),

historical_forecasts AS (

    SELECT
        sales_month,
        order_count,
        order_item_count,
        units_sold,
        gross_sales,
        net_sales,
        previous_month_sales,
        mom_growth_pct,

        CASE
            WHEN COUNT(net_sales) OVER (
                ORDER BY sales_month
                ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
            ) = 3
            THEN
                AVG(net_sales) OVER (
                    ORDER BY sales_month
                    ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
                )
            ELSE NULL
        END AS forecast_sales

    FROM monthly_growth
),

historical_results AS (

    SELECT
        sales_month,
        'ACTUAL'::TEXT AS record_type,

        order_count,
        order_item_count,
        units_sold,
        gross_sales,
        net_sales AS actual_sales,
        previous_month_sales,
        mom_growth_pct,
        forecast_sales,

        net_sales - forecast_sales AS forecast_variance,

        CASE
            WHEN forecast_sales IS NOT NULL
             AND forecast_sales <> 0
            THEN
                (
                    (net_sales - forecast_sales)
                    / NULLIF(forecast_sales, 0)
                ) * 100
            ELSE NULL
        END AS forecast_variance_pct

    FROM historical_forecasts
),

next_month_forecast AS (

    SELECT
        (
            MAX(sales_month) + INTERVAL '1 month'
        )::DATE AS sales_month,

        'FORECAST'::TEXT AS record_type,

        NULL::BIGINT AS order_count,
        NULL::BIGINT AS order_item_count,
        NULL::NUMERIC AS units_sold,
        NULL::NUMERIC AS gross_sales,
        NULL::NUMERIC AS actual_sales,

        (
            ARRAY_AGG(
                net_sales
                ORDER BY sales_month DESC
            )
        )[1]::NUMERIC AS previous_month_sales,

        NULL::NUMERIC AS mom_growth_pct,

        AVG(net_sales)::NUMERIC AS forecast_sales,

        NULL::NUMERIC AS forecast_variance,
        NULL::NUMERIC AS forecast_variance_pct

    FROM (
        SELECT
            sales_month,
            net_sales
        FROM monthly_sales
        ORDER BY sales_month DESC
        LIMIT 3
    ) AS last_three_months

    HAVING COUNT(net_sales) = 3
)

SELECT *
FROM historical_results

UNION ALL

SELECT *
FROM next_month_forecast

ORDER BY sales_month;
