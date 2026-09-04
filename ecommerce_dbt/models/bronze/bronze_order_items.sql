SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    CURRENT_TIMESTAMP AS loaded_at
FROM {{ source('raw', 'order_items') }}