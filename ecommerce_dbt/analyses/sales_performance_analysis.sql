
/*
    Analysis: Sales Performance Analysis

    Purpose:
      1. Calculate monthly gross and net sales.
      2. Measure order volume, units sold, and average order value.
      3. Compare monthly sales with the previous month.
      4. Identify top-performing products and customers.
      5. Highlight sales data-quality issues.

    Sources:
      gold.fact_order_items
      gold.dim_products
      gold.dim_customers

    Grain:
      One row per month and product.

    Notes:
      - Orders are aggregated to order level before calculating AOV.
      - Product performance is calculated from order-item facts.
      - net_sales_amount currently includes tax.
      - Sales figures assume all included records use a comparable currency.
*/

WITH order_item_base AS (

    SELECT
        order_item_id,
        order_id,
        order_date_key,
        customer_id,
        product_id,
        quantity,
        gross_sales_amount,
        net_sales_amount,
        has_line_total_mismatch,
        has_negative_quantity

    FROM gold.fact_order_items
),

monthly_product_sales AS (

    SELECT
        DATE_TRUNC(
            'month',
            TO_DATE(order_date_key::TEXT, 'YYYYMMDD')
        )::DATE AS sales_month,

        product_id,

        COUNT(DISTINCT order_id) AS order_count,

        COUNT(DISTINCT customer_id) AS customer_count,

        COUNT(DISTINCT order_item_id) AS order_item_count,

        SUM(quantity) AS units_sold,

        SUM(gross_sales_amount) AS gross_sales,

        SUM(net_sales_amount) AS net_sales,

        COUNT(*) FILTER (
            WHERE has_line_total_mismatch IS TRUE
        ) AS line_total_mismatch_count,

        COUNT(*) FILTER (
            WHERE has_negative_quantity IS TRUE
        ) AS negative_quantity_count

    FROM order_item_base

    WHERE order_date_key IS NOT NULL

    GROUP BY
        1,
        2
),

monthly_product_trends AS (

    SELECT
        sales_month,
        product_id,
        order_count,
        customer_count,
        order_item_count,
        units_sold,
        gross_sales,
        net_sales,
        line_total_mismatch_count,
        negative_quantity_count,

        LAG(net_sales) OVER (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS previous_month_net_sales,

        LAG(sales_month) OVER (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS previous_sales_month

    FROM monthly_product_sales
),

sales_metrics AS (

    SELECT
        sales_month,
        product_id,
        order_count,
        customer_count,
        order_item_count,
        units_sold,
        gross_sales,
        net_sales,
        line_total_mismatch_count,
        negative_quantity_count,
        previous_month_net_sales,

        CASE
            WHEN previous_sales_month =
                 (sales_month - INTERVAL '1 month')::DATE
            THEN net_sales - previous_month_net_sales
            ELSE NULL
        END AS mom_sales_change,

        CASE
            WHEN previous_sales_month =
                 (sales_month - INTERVAL '1 month')::DATE
             AND previous_month_net_sales <> 0
            THEN
                (
                    (net_sales - previous_month_net_sales)
                    / NULLIF(previous_month_net_sales, 0)
                ) * 100
            ELSE NULL
        END AS mom_sales_growth_pct

    FROM monthly_product_trends
),

ranked_products AS (

    SELECT
        sales_month,
        product_id,
        net_sales,

        DENSE_RANK() OVER (
            PARTITION BY sales_month
            ORDER BY net_sales DESC NULLS LAST
        ) AS monthly_product_sales_rank

    FROM sales_metrics
),

order_level_sales AS (

    /*
       Aggregate line items to one row per order before calculating
       average order value.
    */
    SELECT
        order_id,

        MIN(order_date_key) AS order_date_key,

        SUM(gross_sales_amount) AS order_gross_sales,

        SUM(net_sales_amount) AS order_net_sales,

        COUNT(DISTINCT customer_id) AS customer_id_count

    FROM order_item_base

    WHERE order_id IS NOT NULL

    GROUP BY order_id
),

monthly_order_metrics AS (

    SELECT
        DATE_TRUNC(
            'month',
            TO_DATE(order_date_key::TEXT, 'YYYYMMDD')
        )::DATE AS sales_month,

        COUNT(*) AS total_orders,

        AVG(order_net_sales) AS average_order_value,

        SUM(order_gross_sales) AS total_gross_sales,

        SUM(order_net_sales) AS total_net_sales

    FROM order_level_sales

    WHERE order_date_key IS NOT NULL

    GROUP BY 1
),

monthly_customer_sales AS (

    SELECT
        DATE_TRUNC(
            'month',
            TO_DATE(order_date_key::TEXT, 'YYYYMMDD')
        )::DATE AS sales_month,

        customer_id,

        SUM(net_sales_amount) AS customer_net_sales

    FROM order_item_base

    WHERE order_date_key IS NOT NULL
      AND customer_id IS NOT NULL

    GROUP BY
        1,
        2
),

ranked_customers AS (

    SELECT
        sales_month,
        customer_id,
        customer_net_sales,

        DENSE_RANK() OVER (
            PARTITION BY sales_month
            ORDER BY customer_net_sales DESC NULLS LAST
        ) AS monthly_customer_sales_rank

    FROM monthly_customer_sales
),

top_customer_summary AS (

    SELECT
        sales_month,

        MAX(customer_net_sales) AS highest_customer_sales,

        COUNT(*) FILTER (
            WHERE monthly_customer_sales_rank = 1
        ) AS top_customer_tie_count

    FROM ranked_customers

    GROUP BY sales_month
)

SELECT
    sm.sales_month,
    sm.product_id,

    dp.product_name,
    dp.category,
    dp.subcategory,
    dp.brand,

    sm.order_count,
    sm.customer_count,
    sm.order_item_count,
    sm.units_sold,

    sm.gross_sales,
    sm.net_sales,

    om.total_orders,
    om.average_order_value,
    om.total_gross_sales,
    om.total_net_sales,

    sm.previous_month_net_sales,
    sm.mom_sales_change,
    sm.mom_sales_growth_pct,

    rp.monthly_product_sales_rank,

    tcs.highest_customer_sales,
    tcs.top_customer_tie_count,

    sm.line_total_mismatch_count,
    sm.negative_quantity_count

FROM sales_metrics AS sm

LEFT JOIN gold.dim_products AS dp
    ON sm.product_id = dp.product_id

LEFT JOIN ranked_products AS rp
    ON sm.sales_month = rp.sales_month
   AND sm.product_id = rp.product_id

LEFT JOIN monthly_order_metrics AS om
    ON sm.sales_month = om.sales_month

LEFT JOIN top_customer_summary AS tcs
    ON sm.sales_month = tcs.sales_month

ORDER BY
    sm.sales_month,
    sm.net_sales DESC NULLS LAST,
    sm.product_id;
