SELECT
    return_id,
    order_item_id,
    return_date,
    return_reason,
    return_quantity,
    refund_amount,
    return_status,

    -- Classify return status into business-friendly groups
    CASE
        WHEN LOWER(return_status) IN ('approved', 'completed', 'processed')
            THEN 'Approved'
        WHEN LOWER(return_status) IN ('pending', 'requested', 'under review')
            THEN 'Pending'
        WHEN LOWER(return_status) IN ('rejected', 'denied', 'cancelled', 'canceled')
            THEN 'Rejected'
        ELSE 'Other'
    END AS return_status_group,

    -- Identify successfully processed returns
    CASE
        WHEN LOWER(return_status) IN ('approved', 'completed', 'processed')
            THEN TRUE
        ELSE FALSE
    END AS is_return_approved,

    -- Calculate refund amount per returned unit
    CASE
        WHEN return_quantity > 0
        THEN ROUND(
            refund_amount / return_quantity,
            2
        )
        ELSE NULL
    END AS refund_per_unit,

    -- Identify returns that have a refund
    CASE
        WHEN refund_amount > 0
            THEN TRUE
        ELSE FALSE
    END AS has_refund,

    -- Identify potentially invalid return quantities
    CASE
        WHEN return_quantity <= 0
            THEN TRUE
        ELSE FALSE
    END AS has_invalid_return_quantity,

    -- Number of days between return and source update
    CASE
        WHEN updated_at IS NOT NULL
        THEN EXTRACT(
            DAY FROM (updated_at - return_date)
        )::INTEGER
        ELSE NULL
    END AS return_update_delay_days,

    updated_at,
    ingested_at,
    loaded_at,

    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_returns') }}
