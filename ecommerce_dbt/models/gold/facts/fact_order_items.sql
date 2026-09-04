SELECT
    oi.order_item_id,
    oi.order_id,
    o.customer_id,
    oi.product_id,
    o.order_date,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price AS total_amount
FROM {{ ref('silver_order_items') }} AS oi
INNER JOIN {{ ref('silver_orders') }} AS o
    ON oi.order_id = o.order_id