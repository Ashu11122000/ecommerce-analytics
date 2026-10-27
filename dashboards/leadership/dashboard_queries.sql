
/*
File: dashboards/leadership/dashboard_queries.sql
Purpose: Leadership and business performance reporting.

Expected Gold models:
  gold.fact_order_items
  gold.dim_date
  gold.dim_products

Important:
  Verify the exact schema and column names against your dbt models.
  Financial measures must follow the definitions in the metrics catalog.
*/


-- ============================================================
-- QUERY 1: Executive KPI Summary
-- Grain: One row for the reporting period
-- ============================================================

SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS purchasing_customers,
    SUM(quantity) AS units_sold,
    SUM(gross_sales_amount) AS gross_sales,
    SUM(net_sales_amount) AS net_sales,
    ROUND(
        SUM(net_sales_amount)
        / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS average_order_value
FROM gold.fact_order_items;


-- ============================================================
-- QUERY 2: Monthly Sales Trend
-- Grain: One row per calendar month
-- ============================================================

SELECT
    d.year,
    d.month_number,
    d.month_name,
    SUM(f.gross_sales_amount) AS gross_sales,
    SUM(f.net_sales_amount) AS net_sales,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.quantity) AS units_sold
FROM gold.fact_order_items AS f
JOIN gold.dim_date AS d
    ON f.order_date_key = d.date_key
GROUP BY
    d.year,
    d.month_number,
    d.month_name
ORDER BY
    d.year,
    d.month_number;


-- ============================================================
-- QUERY 3: Sales by Product Category
-- Grain: One row per product category
-- ============================================================

SELECT
    p.category,
    SUM(f.net_sales_amount) AS net_sales,
    SUM(f.quantity) AS units_sold,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_id) AS unique_customers
FROM gold.fact_order_items AS f
JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    p.category
ORDER BY
    net_sales DESC;


-- ============================================================
-- QUERY 4: Top 10 Products by Net Sales
-- Grain: One row per product
-- ============================================================

SELECT
    p.product_key,
    p.product_name,
    p.category,
    SUM(f.net_sales_amount) AS net_sales,
    SUM(f.quantity) AS units_sold,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM gold.fact_order_items AS f
JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    p.product_key,
    p.product_name,
    p.category
ORDER BY
    net_sales DESC
LIMIT 10;


-- ============================================================
-- QUERY 5: Month-over-Month and Year-over-Year Sales Growth
-- Grain: One row per month
-- Note: Requires comparable historical periods.
-- ============================================================

WITH monthly_sales AS (
    SELECT
        d.year,
        d.month_number,
        SUM(f.net_sales_amount) AS net_sales,
        COUNT(DISTINCT f.order_id) AS total_orders
    FROM gold.fact_order_items AS f
    JOIN gold.dim_date AS d
        ON f.order_date_key = d.date_key
    GROUP BY
        d.year,
        d.month_number
),
comparisons AS (
    SELECT
        year,
        month_number,
        net_sales,
        total_orders,
        LAG(net_sales) OVER (
            ORDER BY year, month_number
        ) AS previous_month_sales,
        LAG(total_orders) OVER (
            ORDER BY year, month_number
        ) AS previous_month_orders,
        LAG(net_sales, 12) OVER (
            ORDER BY year, month_number
        ) AS previous_year_sales,
        LAG(total_orders, 12) OVER (
            ORDER BY year, month_number
        ) AS previous_year_orders
    FROM monthly_sales
)
SELECT
    year,
    month_number,
    net_sales,
    total_orders,
    ROUND(
        100.0 * (net_sales - previous_month_sales)
        / NULLIF(previous_month_sales, 0),
        2
    ) AS mom_sales_growth_pct,
    ROUND(
        100.0 * (net_sales - previous_year_sales)
        / NULLIF(previous_year_sales, 0),
        2
    ) AS yoy_sales_growth_pct,
    previous_month_orders,
    previous_year_orders
FROM comparisons
ORDER BY
    year,
    month_number;


-- ============================================================
-- QUERY 6: Three-Month Rolling Average of Monthly Sales
-- Grain: One row per month
-- This is a historical smoothing measure, not a forecast by itself.
-- ============================================================

WITH monthly_sales AS (
    SELECT
        d.year,
        d.month_number,
        SUM(f.net_sales_amount) AS net_sales
    FROM gold.fact_order_items AS f
    JOIN gold.dim_date AS d
        ON f.order_date_key = d.date_key
    GROUP BY
        d.year,
        d.month_number
)
SELECT
    year,
    month_number,
    net_sales,
    ROUND(
        AVG(net_sales) OVER (
            ORDER BY year, month_number
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS rolling_3_month_average
FROM monthly_sales
ORDER BY
    year,
    month_number;
