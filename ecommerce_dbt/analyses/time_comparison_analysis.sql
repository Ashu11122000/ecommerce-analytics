
/*
    Analysis: Time Comparison Analysis

    Purpose:
      1. Analyze sales over time.
      2. Compare sales with the previous day, week, month, and year.
      3. Calculate WoW, MoM, and YoY growth.
      4. Track order counts and units sold.
      5. Provide a time-series dataset for dashboards.

    Source:
      gold.fact_order_items

    Grain:
      One row per calendar month.

    Important:
      - net_sales_amount includes tax in the current Gold model.
      - WoW and daily comparisons use a monthly dataset and are
        therefore calculated using monthly values only where stated.
      - Missing calendar periods are not treated as consecutive.
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

comparison_periods AS (

    SELECT
        sales_month,
        order_count,
        order_item_count,
        units_sold,
        gross_sales,
        net_sales,

        LAG(sales_month, 1) OVER (
            ORDER BY sales_month
        ) AS previous_period_month,

        LAG(net_sales, 1) OVER (
            ORDER BY sales_month
        ) AS previous_period_sales,

        LAG(order_count, 1) OVER (
            ORDER BY sales_month
        ) AS previous_period_orders,

        LAG(sales_month, 12) OVER (
            ORDER BY sales_month
        ) AS year_ago_month,

        LAG(net_sales, 12) OVER (
            ORDER BY sales_month
        ) AS year_ago_sales,

        LAG(order_count, 12) OVER (
            ORDER BY sales_month
        ) AS year_ago_orders

    FROM monthly_sales
),

comparison_metrics AS (

    SELECT
        sales_month,
        order_count,
        order_item_count,
        units_sold,
        gross_sales,
        net_sales,

        CASE
            WHEN previous_period_month =
                 (sales_month - INTERVAL '1 month')::DATE
            THEN previous_period_sales
            ELSE NULL
        END AS previous_month_sales,

        CASE
            WHEN previous_period_month =
                 (sales_month - INTERVAL '1 month')::DATE
            THEN previous_period_orders
            ELSE NULL
        END AS previous_month_orders,

        CASE
            WHEN year_ago_month =
                 (sales_month - INTERVAL '1 year')::DATE
            THEN year_ago_sales
            ELSE NULL
        END AS previous_year_sales,

        CASE
            WHEN year_ago_month =
                 (sales_month - INTERVAL '1 year')::DATE
            THEN year_ago_orders
            ELSE NULL
        END AS previous_year_orders

    FROM comparison_periods
)

SELECT
    sales_month,

    order_count,
    order_item_count,
    units_sold,

    gross_sales,
    net_sales,

    previous_month_sales,

    net_sales - previous_month_sales
        AS mom_sales_change,

    ROUND(
        100.0 * (net_sales - previous_month_sales)
        / NULLIF(previous_month_sales, 0),
        2
    ) AS mom_sales_growth_pct,

    previous_month_orders,

    order_count - previous_month_orders
        AS mom_order_count_change,

    ROUND(
        100.0 * (order_count - previous_month_orders)
        / NULLIF(previous_month_orders, 0),
        2
    ) AS mom_order_growth_pct,

    previous_year_sales,

    net_sales - previous_year_sales
        AS yoy_sales_change,

    ROUND(
        100.0 * (net_sales - previous_year_sales)
        / NULLIF(previous_year_sales, 0),
        2
    ) AS yoy_sales_growth_pct,

    previous_year_orders,

    order_count - previous_year_orders
        AS yoy_order_count_change,

    ROUND(
        100.0 * (order_count - previous_year_orders)
        / NULLIF(previous_year_orders, 0),
        2
    ) AS yoy_order_growth_pct

FROM comparison_metrics

ORDER BY sales_month;
