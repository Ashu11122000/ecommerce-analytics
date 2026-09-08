-- Custom data quality test:
-- Returns rows when an order item has a non-positive
-- quantity or unit price.

SELECT
    order_item_id,
    order_id,
    quantity,
    unit_price
FROM {{ ref('fact_order_items') }}
WHERE quantity <= 0
OR unit_price <= 0
