SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    COALESCE(discount_amount, 0.00) AS discount_amount,
    COALESCE(tax_amount, 0.00) AS tax_amount,
    line_total,
    COALESCE(returned_quantity, 0) AS returned_quantity,
    updated_at,
    ingested_at,

    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'order_items') }}