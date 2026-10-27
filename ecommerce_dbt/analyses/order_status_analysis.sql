
/*
    Analysis: Order Status Analysis

    Purpose:
      1. Summarize orders by order status.
      2. Calculate order counts and sales amounts.
      3. Analyze payment status and average order value.
      4. Show monthly order-status trends.
      5. Compare monthly order counts with the previous month.

    Sources:
      gold.fact_order_items
      gold.dim_date

    Grain:
      One row per month and order status.

    Note:
      Sales amounts are aggregated from order items.
      net_sales_amount includes tax in the current Gold model.
      Order status is taken from the Gold order-item fact.
*/

WITH order_level AS (

    /*
       Collapse order-item rows to one row per order before
       counting orders or aggregating order-level attributes.
    */
    SELECT
        foi.order_id,

        MIN(foi.order_date_key) AS order_date_key,

        MAX(foi.order_status) AS order_status,

        SUM(foi.quantity) AS total_units,

        SUM(foi.gross_sales_amount) AS gross_sales,

        SUM(foi.net_sales_amount) AS net_sales,

        COUNT(DISTINCT foi.order_item_id) AS order_item_count

    FROM gold.fact_order_items AS foi

    WHERE foi.order_id IS NOT NULL

    GROUP BY foi.order_id
),

monthly_status AS (

    SELECT
        DATE_TRUNC(
            'month',
            TO_DATE(ol.order_date_key::TEXT, 'YYYYMMDD')
        )::DATE AS order_month,

        COALESCE(
            NULLIF(TRIM(ol.order_status), ''),
            'Unknown'
        ) AS order_status,

        COUNT(*) AS order_count,

        SUM(ol.total_units) AS total_units,

        SUM(ol.order_item_count) AS order_item_count,

        SUM(ol.gross_sales) AS gross_sales,

        SUM(ol.net_sales) AS net_sales,

        AVG(ol.net_sales) AS average_order_value

    FROM order_level AS ol

    WHERE ol.order_date_key IS NOT NULL

    GROUP BY
        1,
        2
),

status_trends AS (

    SELECT
        order_month,
        order_status,
        order_count,
        total_units,
        order_item_count,
        gross_sales,
        net_sales,
        average_order_value,

        LAG(order_count) OVER (
            PARTITION BY order_status
            ORDER BY order_month
        ) AS previous_month_order_count,

        LAG(order_month) OVER (
            PARTITION BY order_status
            ORDER BY order_month
        ) AS previous_status_month

    FROM monthly_status
),

status_growth AS (

    SELECT
        order_month,
        order_status,
        order_count,
        total_units,
        order_item_count,
        gross_sales,
        net_sales,
        average_order_value,
        previous_month_order_count,

        CASE
            WHEN previous_status_month =
                 (order_month - INTERVAL '1 month')::DATE
            THEN order_count - previous_month_order_count
            ELSE NULL
        END AS mom_order_count_change,

        CASE
            WHEN previous_status_month =
                 (order_month - INTERVAL '1 month')::DATE
             AND previous_month_order_count <> 0
            THEN
                (
                    (order_count - previous_month_order_count)::NUMERIC
                    / NULLIF(previous_month_order_count, 0)
                ) * 100
            ELSE NULL
        END AS mom_order_count_growth_pct

    FROM status_trends
)

SELECT
    order_month,
    order_status,
    order_count,
    total_units,
    order_item_count,
    gross_sales,
    net_sales,
    average_order_value,
    previous_month_order_count,
    mom_order_count_change,
    mom_order_count_growth_pct,

    SUM(order_count) OVER (
        PARTITION BY order_month
    ) AS all_status_orders_for_month,

    ROUND(
        100.0 * order_count
        / NULLIF(
            SUM(order_count) OVER (
                PARTITION BY order_month
            ),
            0
        ),
        2
    ) AS monthly_order_status_pct

FROM status_growth

ORDER BY
    order_month,
    order_count DESC,
    order_status;
