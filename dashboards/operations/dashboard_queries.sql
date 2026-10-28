
-- ============================================================
-- OPERATIONS DASHBOARD QUERIES
-- Database: ecommerce_analytics
-- Schema: gold
-- ============================================================


-- ============================================================
-- QUERY 1: Order Status Distribution
-- Purpose: Analyze order volumes, units sold, and net sales
-- by order status.
-- ============================================================

SELECT
    order_status,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS units_sold,
    SUM(net_sales_amount) AS net_sales
FROM gold.fact_order_items
GROUP BY
    order_status
ORDER BY
    total_orders DESC;


-- ============================================================
-- QUERY 2: Monthly Payment Performance
-- Purpose: Analyze payment volumes by month, payment method,
-- and payment status.
-- ============================================================

SELECT
    EXTRACT(YEAR FROM d.full_date)::INT AS year,
    EXTRACT(MONTH FROM d.full_date)::INT AS month_number,
    p.payment_method,
    p.payment_status,
    COUNT(*) AS total_payments
FROM gold.fact_payments AS p
JOIN gold.dim_date AS d
    ON p.payment_date_key = d.date_key
GROUP BY
    EXTRACT(YEAR FROM d.full_date)::INT,
    EXTRACT(MONTH FROM d.full_date)::INT,
    p.payment_method,
    p.payment_status
ORDER BY
    year,
    month_number,
    p.payment_method,
    p.payment_status;
