{{
    config(
        materialized='incremental',
        unique_key='order_item_id'
    )
}}

SELECT
    oi.order_item_id,
    oi.order_id,
    o.customer_id,
    oi.product_id,
    o.order_date,
    oi.quantity,
    oi.unit_price,

    oi.quantity * oi.unit_price AS total_amount,

    -- Data lineage timestamps
    oi.ingested_at,
    oi.loaded_at,
    oi.transformed_at,

    {{ modeled_timestamp() }} AS modeled_at

FROM {{ ref('silver_order_items') }} AS oi

INNER JOIN {{ ref('silver_orders') }} AS o
    ON oi.order_id = o.order_id

{% if is_incremental() %}

WHERE oi.ingested_at > (
    SELECT COALESCE(
        MAX(ingested_at),
        '1900-01-01'::timestamp
    )
    FROM {{ this }}
)

{% endif %}