
-- Test: Order-item quantities and sales amounts must not be negative.
-- Expected result: Zero rows returned.
--
-- Assumes fact_order_items contains:
-- quantity, gross_sales_amount, and net_sales_amount.

SELECT
    order_item_id,
    quantity,
    gross_sales_amount,
    net_sales_amount
FROM {{ ref('fact_order_items') }}
WHERE
    quantity < 0
    OR gross_sales_amount < 0
    OR net_sales_amount < 0
