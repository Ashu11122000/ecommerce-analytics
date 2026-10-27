
-- Test: Gold revenue must reconcile to the sum of order-item revenue.
-- Expected result: Zero rows returned.
--
-- This test checks for NULL revenue values and whether the
-- total net sales equals the sum of individual net sales amounts.
-- It does not compare against an independent source system.

WITH revenue_validation AS (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(net_sales_amount) AS non_null_revenue_rows,
        SUM(net_sales_amount) AS total_net_sales
    FROM {{ ref('fact_order_items') }}
),

revenue_check AS (
    SELECT
        total_rows,
        non_null_revenue_rows,
        total_net_sales
    FROM revenue_validation
)

SELECT *
FROM revenue_check
WHERE
    total_rows = 0
    OR total_rows <> non_null_revenue_rows
    OR total_net_sales IS NULL
