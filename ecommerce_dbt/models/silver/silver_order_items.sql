SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    ingested_at,
    loaded_at,
    CURRENT_TIMESTAMP AS transformed_at

FROM {{ ref('bronze_order_items') }}