SELECT
    order_id,
    customer_id,
    order_date,
    LOWER(TRIM(order_status)) AS order_status,
    ingested_at,
    loaded_at,
    CURRENT_TIMESTAMP AS transformed_at

FROM {{ ref('bronze_orders') }}