
-- Test: Each row in fact_order_items must have a unique order_item_id.
-- Expected result: Zero rows returned.

SELECT
    order_item_id,
    COUNT(*) AS duplicate_count
FROM {{ ref('fact_order_items') }}
GROUP BY order_item_id
HAVING COUNT(*) > 1
