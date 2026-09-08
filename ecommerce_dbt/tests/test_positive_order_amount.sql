-- Custom data quality test:
-- Returns rows only when an order item has a non-positive total amount.

SELECT
    order_item_id,
    order_id,
    total_amount
FROM {{ ref('fact_order_items') }}
WHERE total_amount <= 0