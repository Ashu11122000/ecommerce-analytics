
-- Test: Order-item line totals should reconcile with quantity * unit price.
-- Expected result: Zero rows returned.
--
-- Assumption: fact_order_items contains quantity, unit_price,
-- and line_total. Adjust column names and calculation to match
-- your actual Gold model.

SELECT
    order_item_id,
    quantity,
    unit_price,
    line_total,
    quantity * unit_price AS expected_line_total
FROM {{ ref('fact_order_items') }}
WHERE
    quantity IS NOT NULL
    AND unit_price IS NOT NULL
    AND line_total IS NOT NULL
    AND ABS(line_total - (quantity * unit_price)) > 0.01
