SELECT
    shipment_id,
    order_id,
    INITCAP(TRIM(shipping_method)) AS shipping_method,
    INITCAP(TRIM(shipment_status)) AS shipment_status,
    shipped_at,
    delivered_at,
    INITCAP(TRIM(delivery_city)) AS delivery_city,
    INITCAP(TRIM(delivery_state)) AS delivery_state,
    updated_at,
    ingested_at,

    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'shipments') }}