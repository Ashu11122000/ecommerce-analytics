-- These queries use the analytics-ready Gold layer.
--
-- Tables:
--   analytics_gold.fact_order_items
--   analytics_gold.dim_customers
--   analytics_gold.dim_products

-- 1. OVERALL BUSINESS METRICS
-- Demonstrates: Aggregations
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(quantity) AS total_items_sold,
    SUM(total_amount) AS total_revenue,
    ROUND(SUM(total_amount) / COUNT(DISTINCT order_id), 2)
        AS average_order_value
FROM analytics_gold.fact_order_items;

-- 2. MONTHLY REVENUE TREND
-- Demonstrates: Aggregations + Analytical time-series use case
SELECT
    DATE_TRUNC('month', order_date)::date AS order_month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_amount) AS monthly_revenue
FROM analytics_gold.fact_order_items
GROUP BY 1
ORDER BY 1;

-- 3. TOP 5 CUSTOMERS BY REVENUE
-- Demonstrates: JOIN + Aggregation + Analytical ranking
SELECT
    c.customer_id,
    c.customer_name,
    c.city,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.total_amount) AS total_spent
FROM analytics_gold.fact_order_items AS f
JOIN analytics_gold.dim_customers AS c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.city
ORDER BY total_spent DESC
LIMIT 5;

-- 4. TOP 5 PRODUCTS BY REVENUE
-- Demonstrates: JOIN + Aggregation + Analytical use case
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(f.quantity) AS total_quantity_sold,
    SUM(f.total_amount) AS total_revenue
FROM analytics_gold.fact_order_items AS f
JOIN analytics_gold.dim_products AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY total_revenue DESC
LIMIT 5;

-- 5. REVENUE BY PRODUCT CATEGORY
-- Demonstrates: JOIN + Aggregation
SELECT
    p.category,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.quantity) AS total_items_sold,
    SUM(f.total_amount) AS total_revenue
FROM analytics_gold.fact_order_items AS f
JOIN analytics_gold.dim_products AS p
    ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;

-- 6. CUSTOMER PURCHASE SUMMARY
-- Demonstrates: JOIN + Analytical customer behavior
SELECT
    c.customer_id,
    c.customer_name,
    c.city,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.total_amount) AS lifetime_value,
    ROUND(
        SUM(f.total_amount)
        / COUNT(DISTINCT f.order_id),
        2
    ) AS average_order_value
FROM analytics_gold.dim_customers AS c
JOIN analytics_gold.fact_order_items AS f
    ON c.customer_id = f.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.city
ORDER BY lifetime_value DESC;

-- 7. SALES BY CITY
-- Demonstrates: JOIN + Aggregation + Geographic analysis
SELECT
    c.city,
    COUNT(DISTINCT f.customer_id) AS unique_customers,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.total_amount) AS total_revenue
FROM analytics_gold.fact_order_items AS f
JOIN analytics_gold.dim_customers AS c
    ON f.customer_id = c.customer_id
GROUP BY c.city
ORDER BY total_revenue DESC;

-- 8. DAILY SALES TREND
-- Demonstrates: Time-based aggregation + Analytical use case
SELECT
    order_date::date AS order_day,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS total_items_sold,
    SUM(total_amount) AS daily_revenue
FROM analytics_gold.fact_order_items
GROUP BY order_date::date
ORDER BY order_day;