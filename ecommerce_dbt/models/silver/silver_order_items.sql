SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    ingested_at,
    loaded_at,
    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_order_items') }}