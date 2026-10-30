
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: sales_performance_analysis.sql
-- Purpose:
--   Analyze sales performance across time, products, categories,
--   sales channels, and customers.
--
-- Target personas:
--   Business leadership, sales analysts, e-commerce managers.
--
-- Source tables:
--   raw.orders
--   raw.order_items
--   raw.products
--   raw.customers
--
-- Business questions:
--   1. What are total sales and average order value?
--   2. How do revenue and order volumes change over time?
--   3. Which products and categories drive sales?
--   4. Which sales channels generate the most revenue?
--   5. Which customers contribute most to revenue?
--   6. How concentrated is sales revenue?
--   7. What are the trends in units sold and discounts?
--
-- All queries are read-only.
-- ============================================================


-- ============================================================
-- 1. OVERALL SALES KPI SUMMARY
-- Dashboard visualization:
--   KPI cards: sales revenue, orders, AOV, customers, units.
-- Grain: one row for the entire observed dataset.
-- ============================================================

WITH eligible_orders AS (
    SELECT
        order_id,
        customer_id,
        total_amount
    FROM raw.orders
    WHERE LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
),
eligible_order_items AS (
    SELECT
        oi.order_item_id,
        oi.order_id,
        oi.quantity,
        oi.line_total
    FROM raw.order_items oi
    INNER JOIN eligible_orders eo
        ON eo.order_id = oi.order_id
)
SELECT
    (SELECT COUNT(*) FROM eligible_orders) AS eligible_order_count,

    (
        SELECT COUNT(DISTINCT customer_id)
        FROM eligible_orders
    ) AS purchasing_customer_count,

    (
        SELECT ROUND(
            COALESCE(SUM(total_amount), 0)::NUMERIC,
            2
        )
        FROM eligible_orders
    ) AS total_order_revenue,

    (
        SELECT ROUND(
            AVG(total_amount)::NUMERIC,
            2
        )
        FROM eligible_orders
    ) AS average_order_value,

    (
        SELECT COALESCE(SUM(quantity), 0)
        FROM eligible_order_items
    ) AS total_units_ordered,

    (
        SELECT ROUND(
            COALESCE(SUM(line_total), 0)::NUMERIC,
            2
        )
        FROM eligible_order_items
    ) AS total_merchandise_revenue;


-- ============================================================
-- 2. MONTHLY SALES PERFORMANCE
-- Dashboard visualization:
--   Combo chart: monthly revenue, order count, and units sold.
-- Grain: one row per calendar month.
-- ============================================================

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        COUNT(*) AS order_count,
        COUNT(DISTINCT customer_id) AS unique_customers,
        SUM(total_amount)::NUMERIC AS order_revenue
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
monthly_items AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE AS month_start,
        SUM(oi.quantity) AS units_ordered,
        SUM(oi.line_total)::NUMERIC AS merchandise_revenue
    FROM raw.orders o
    INNER JOIN raw.order_items oi
        ON oi.order_id = o.order_id
    WHERE o.order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
    GROUP BY DATE_TRUNC('month', o.order_date)::DATE
)
SELECT
    mo.month_start,
    mo.order_count,
    mo.unique_customers,
    ROUND(mo.order_revenue, 2) AS order_revenue,
    ROUND(
        mo.order_revenue / NULLIF(mo.order_count, 0),
        2
    ) AS average_order_value,
    COALESCE(mi.units_ordered, 0) AS units_ordered,
    ROUND(
        COALESCE(mi.merchandise_revenue, 0),
        2
    ) AS merchandise_revenue
FROM monthly_orders mo
LEFT JOIN monthly_items mi
    ON mi.month_start = mo.month_start
ORDER BY mo.month_start;


-- ============================================================
-- 3. MONTH-OVER-MONTH SALES GROWTH
-- Dashboard visualization:
--   Line chart for revenue and revenue growth percentage.
-- Grain: one row per observed order month.
-- ============================================================

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month_start,
        SUM(total_amount)::NUMERIC AS revenue,
        COUNT(*) AS order_count
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
comparison AS (
    SELECT
        month_start,
        revenue,
        order_count,
        LAG(revenue) OVER (
            ORDER BY month_start
        ) AS previous_month_revenue,
        LAG(order_count) OVER (
            ORDER BY month_start
        ) AS previous_month_order_count
    FROM monthly_sales
)
SELECT
    month_start,
    ROUND(revenue, 2) AS revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,

    ROUND(
        revenue - previous_month_revenue,
        2
    ) AS revenue_change,

    ROUND(
        100.0 * (revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0),
        2
    ) AS revenue_growth_pct,

    order_count,
    previous_month_order_count,

    ROUND(
        100.0 * (order_count - previous_month_order_count)
        / NULLIF(previous_month_order_count, 0),
        2
    ) AS order_growth_pct

FROM comparison
ORDER BY month_start;


-- ============================================================
-- 4. SALES BY PRODUCT CATEGORY
-- Dashboard visualization:
--   Bar chart ranked by merchandise revenue.
-- Grain: one row per category.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(p.category), ''),
        'Unknown'
    ) AS product_category,

    COUNT(DISTINCT o.order_id) AS order_count,

    COUNT(DISTINCT oi.product_id) AS distinct_products_sold,

    COALESCE(SUM(oi.quantity), 0) AS units_ordered,

    ROUND(
        COALESCE(SUM(oi.line_total), 0)::NUMERIC,
        2
    ) AS merchandise_revenue,

    ROUND(
        SUM(oi.line_total)::NUMERIC
        / NULLIF(SUM(oi.quantity), 0),
        2
    ) AS average_revenue_per_unit

FROM raw.order_items oi
INNER JOIN raw.orders o
    ON o.order_id = oi.order_id
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
WHERE LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
GROUP BY
    COALESCE(
        NULLIF(TRIM(p.category), ''),
        'Unknown'
    )
ORDER BY merchandise_revenue DESC NULLS LAST;


-- ============================================================
-- 5. TOP 20 PRODUCTS BY SALES
-- Dashboard visualization:
--   Horizontal bar chart.
-- Grain: one row per product.
-- ============================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,

    COUNT(DISTINCT o.order_id) AS order_count,

    SUM(oi.quantity) AS units_ordered,

    ROUND(
        SUM(oi.line_total)::NUMERIC,
        2
    ) AS merchandise_revenue,

    ROUND(
        AVG(oi.unit_price)::NUMERIC,
        2
    ) AS average_unit_price

FROM raw.order_items oi
INNER JOIN raw.orders o
    ON o.order_id = oi.order_id
INNER JOIN raw.products p
    ON p.product_id = oi.product_id
WHERE LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
GROUP BY
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand
ORDER BY merchandise_revenue DESC NULLS LAST
LIMIT 20;


-- ============================================================
-- 6. SALES CHANNEL PERFORMANCE
-- Dashboard visualization:
--   Bar chart or table ranked by order revenue.
-- Grain: one row per sales channel.
-- ============================================================

WITH channel_sales AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sales_channel), ''),
            'Unknown'
        ) AS sales_channel,
        COUNT(*) AS order_count,
        COUNT(DISTINCT customer_id) AS unique_customers,
        SUM(total_amount)::NUMERIC AS revenue
    FROM raw.orders
    WHERE LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
    GROUP BY
        COALESCE(
            NULLIF(TRIM(sales_channel), ''),
            'Unknown'
        )
)
SELECT
    sales_channel,
    order_count,
    unique_customers,
    ROUND(revenue, 2) AS revenue,

    ROUND(
        revenue / NULLIF(order_count, 0),
        2
    ) AS average_order_value,

    ROUND(
        100.0 * revenue
        / NULLIF(SUM(revenue) OVER (), 0),
        2
    ) AS revenue_share_pct

FROM channel_sales
ORDER BY revenue DESC NULLS LAST;


-- ============================================================
-- 7. TOP 20 CUSTOMERS BY ORDER REVENUE
-- Dashboard visualization:
--   Ranked customer table or bar chart.
-- Grain: one row per customer with eligible orders.
-- ============================================================

SELECT
    o.customer_id,
    c.customer_name,
    c.customer_segment,

    COUNT(*) AS order_count,

    COUNT(DISTINCT DATE_TRUNC('month', o.order_date))
        AS active_order_months,

    ROUND(
        SUM(o.total_amount)::NUMERIC,
        2
    ) AS total_order_revenue,

    ROUND(
        AVG(o.total_amount)::NUMERIC,
        2
    ) AS average_order_value,

    MAX(o.order_date) AS latest_order_date

FROM raw.orders o
LEFT JOIN raw.customers c
    ON c.customer_id = o.customer_id
WHERE LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
GROUP BY
    o.customer_id,
    c.customer_name,
    c.customer_segment
ORDER BY total_order_revenue DESC NULLS LAST
LIMIT 20;


-- ============================================================
-- 8. CUSTOMER REVENUE CONCENTRATION
-- Dashboard visualization:
--   Pareto chart or cumulative revenue contribution table.
-- Grain: one row per purchasing customer.
-- ============================================================

WITH customer_sales AS (
    SELECT
        customer_id,
        SUM(total_amount)::NUMERIC AS customer_revenue
    FROM raw.orders
    WHERE LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
      AND customer_id IS NOT NULL
      AND total_amount IS NOT NULL
    GROUP BY customer_id
),
ranked_customers AS (
    SELECT
        customer_id,
        customer_revenue,

        ROW_NUMBER() OVER (
            ORDER BY customer_revenue DESC, customer_id
        ) AS customer_rank,

        SUM(customer_revenue) OVER (
            ORDER BY customer_revenue DESC, customer_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,

        SUM(customer_revenue) OVER () AS total_revenue,

        COUNT(*) OVER () AS customer_count

    FROM customer_sales
)
SELECT
    customer_id,
    customer_rank,
    customer_count,
    ROUND(customer_revenue, 2) AS customer_revenue,

    ROUND(
        100.0 * customer_revenue
        / NULLIF(total_revenue, 0),
        2
    ) AS customer_revenue_share_pct,

    ROUND(
        100.0 * cumulative_revenue
        / NULLIF(total_revenue, 0),
        2
    ) AS cumulative_revenue_share_pct,

    CASE
        WHEN customer_rank <= CEIL(customer_count * 0.10)
            THEN 'Top 10% of customers'
        WHEN customer_rank <= CEIL(customer_count * 0.25)
            THEN 'Next 15% of customers'
        ELSE 'Remaining customers'
    END AS customer_contribution_group

FROM ranked_customers
ORDER BY customer_rank;


-- ============================================================
-- 9. DISCOUNT PERFORMANCE BY MONTH
-- Dashboard visualization:
--   Line chart for discounts and discounted order-item revenue.
-- Grain: one row per order month.
--
-- Note:
--   The discount amount is summed from order-item records.
--   This query does not add order-level discounts again, which
--   could double-count discounts if both fields overlap.
-- ============================================================

SELECT
    DATE_TRUNC('month', o.order_date)::DATE AS month_start,

    COUNT(DISTINCT o.order_id) AS order_count,

    ROUND(
        COALESCE(SUM(oi.discount_amount), 0)::NUMERIC,
        2
    ) AS item_discount_amount,

    ROUND(
        COALESCE(SUM(oi.line_total), 0)::NUMERIC,
        2
    ) AS merchandise_revenue,

    ROUND(
        100.0 * SUM(oi.discount_amount)
        / NULLIF(
            SUM(
                oi.quantity * oi.unit_price
            ),
            0
        ),
        2
    ) AS item_discount_pct_of_gross_item_value

FROM raw.orders o
INNER JOIN raw.order_items oi
    ON oi.order_id = o.order_id
WHERE o.order_date IS NOT NULL
  AND LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
GROUP BY DATE_TRUNC('month', o.order_date)::DATE
ORDER BY month_start;


-- ============================================================
-- 10. SALES BY ORDER STATUS
-- Dashboard visualization:
--   Bar chart or status comparison table.
-- Grain: one row per normalized order status.
--
-- Cancelled orders are included here for status analysis,
-- unlike most commercial sales metrics above.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    ) AS order_status,

    COUNT(*) AS order_count,

    ROUND(
        COALESCE(SUM(total_amount), 0)::NUMERIC,
        2
    ) AS associated_order_value,

    ROUND(
        AVG(total_amount)::NUMERIC,
        2
    ) AS average_order_value

FROM raw.orders
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(order_status)), ''),
        'Unknown'
    )
ORDER BY associated_order_value DESC NULLS LAST;


-- ============================================================
-- 11. PRODUCT PROFITABILITY INDICATORS
-- Dashboard visualization:
--   Bar chart of estimated gross profit by product.
--
-- Calculation:
--   Estimated unit margin = selling_price - cost_price.
--   Estimated sales margin uses the recorded order-item unit
--   price minus current product cost_price.
--
-- Limitations:
--   - Current cost_price may differ from historical costs.
--   - Discounts, returns, shipping, overhead, and tax treatment
--     are not fully accounted for.
--   - This is an indicative margin, not audited profit.
-- Grain: one row per product.
-- ============================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,

    SUM(oi.quantity) AS units_ordered,

    ROUND(
        SUM(oi.line_total)::NUMERIC,
        2
    ) AS merchandise_revenue,

    ROUND(
        p.cost_price::NUMERIC,
        2
    ) AS current_unit_cost,

    ROUND(
        p.selling_price::NUMERIC,
        2
    ) AS current_list_price,

    ROUND(
        (p.selling_price - p.cost_price)::NUMERIC,
        2
    ) AS current_list_unit_margin,

    ROUND(
        SUM(
            oi.quantity * (oi.unit_price - p.cost_price)
        )::NUMERIC,
        2
    ) AS estimated_item_margin_before_other_costs,

    ROUND(
        100.0 * (p.selling_price - p.cost_price)
        / NULLIF(p.selling_price, 0),
        2
    ) AS current_list_margin_pct

FROM raw.order_items oi
INNER JOIN raw.orders o
    ON o.order_id = oi.order_id
INNER JOIN raw.products p
    ON p.product_id = oi.product_id
WHERE LOWER(TRIM(COALESCE(o.order_status, ''))) <> 'cancelled'
GROUP BY
    p.product_id,
    p.product_name,
    p.category,
    p.cost_price,
    p.selling_price
ORDER BY estimated_item_margin_before_other_costs DESC NULLS LAST;


-- ============================================================
-- 12. SALES DATA QUALITY SUMMARY
-- Dashboard visualization:
--   Data-quality KPI cards.
-- Grain: one row for the entire dataset.
-- ============================================================

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_date IS NULL
    ) AS orders_missing_order_date,

    COUNT(*) FILTER (
        WHERE total_amount IS NULL
    ) AS orders_missing_total_amount,

    COUNT(*) FILTER (
        WHERE total_amount < 0
    ) AS orders_with_negative_total_amount,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(sales_channel), '') IS NULL
    ) AS orders_missing_sales_channel,

    (
        SELECT COUNT(*)
        FROM raw.order_items
        WHERE quantity IS NULL OR quantity <= 0
    ) AS order_items_with_invalid_quantity,

    (
        SELECT COUNT(*)
        FROM raw.order_items
        WHERE line_total IS NULL OR line_total < 0
    ) AS order_items_with_invalid_line_total

FROM raw.orders;


-- ============================================================
-- END OF sales_performance_analysis.sql
-- ============================================================
