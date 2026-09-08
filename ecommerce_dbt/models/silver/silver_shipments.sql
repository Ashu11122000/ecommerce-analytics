SELECT
    shipment_id,
    order_id,
    shipping_method,
    shipment_status,
    shipped_at,
    delivered_at,
    delivery_city,
    delivery_state,

    -- Calculate delivery duration in days
    CASE
        WHEN shipped_at IS NOT NULL
            AND delivered_at IS NOT NULL
        THEN EXTRACT(
            DAY FROM (delivered_at - shipped_at)
        )::INTEGER
        ELSE NULL
    END AS delivery_days,

    -- Identify whether the shipment has been delivered
    CASE
        WHEN delivered_at IS NOT NULL
            THEN TRUE
        ELSE FALSE
    END AS is_delivered,

    -- Classify shipment status into business-friendly groups
    CASE
        WHEN LOWER(shipment_status) IN ('delivered', 'completed')
            THEN 'Delivered'

        WHEN LOWER(shipment_status) IN ('shipped', 'in transit', 'out for delivery')
            THEN 'In Transit'

        WHEN LOWER(shipment_status) IN ('pending', 'processing')
            THEN 'Pending'

        WHEN LOWER(shipment_status) IN ('cancelled', 'canceled')
            THEN 'Cancelled'

        ELSE 'Other'
    END AS shipment_status_group,

    -- Classify delivery speed
    CASE
        WHEN shipped_at IS NULL
             OR delivered_at IS NULL
            THEN 'Unknown'

        WHEN delivered_at - shipped_at <= INTERVAL '2 days'
            THEN 'Fast'

        WHEN delivered_at - shipped_at <= INTERVAL '5 days'
            THEN 'Standard'

        ELSE 'Slow'
    END AS delivery_speed,

    -- Identify shipments taking more than 5 days
    CASE
        WHEN shipped_at IS NOT NULL
            AND delivered_at IS NOT NULL
            AND delivered_at - shipped_at > INTERVAL '5 days'
            THEN TRUE
        ELSE FALSE
    END AS is_delivery_delayed,

    updated_at,
    ingested_at,
    loaded_at,

    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_shipments') }}