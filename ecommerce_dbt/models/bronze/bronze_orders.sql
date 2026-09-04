SELECT
    order_id,
    customer_id,
    order_date,
    order_status,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at
FROM {{ source('raw', 'orders') }}