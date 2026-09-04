SELECT
    order_id,
    customer_id,
    order_date,
    LOWER(TRIM(order_status)) AS order_status,
    loaded_at
FROM {{ ref('bronze_orders') }}
WHERE order_id IS NOT NULL
  AND customer_id IS NOT NULL
  AND order_date IS NOT NULL