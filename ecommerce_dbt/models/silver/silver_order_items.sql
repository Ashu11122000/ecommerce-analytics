SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    loaded_at
FROM {{ ref('bronze_order_items') }}
WHERE order_item_id IS NOT NULL
  AND order_id IS NOT NULL
  AND product_id IS NOT NULL
  AND quantity > 0
  AND unit_price > 0