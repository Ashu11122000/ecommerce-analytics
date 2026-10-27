
-- Test: No duplicate order items should exist in the Gold fact table.
-- Expected result: Zero rows returned.

SELECT
    order_item_id,
    COUNT(*) AS duplicate_count
FROM {{ ref('fact_order_items') }}
GROUP BY order_item_id
HAVING COUNT(*) > 1
