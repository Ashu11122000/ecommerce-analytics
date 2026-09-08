SELECT
    return_id,
    order_item_id,
    return_date,
    INITCAP(TRIM(return_reason)) AS return_reason,
    return_quantity,
    refund_amount,
    INITCAP(TRIM(return_status)) AS return_status,
    updated_at,
    ingested_at,

    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'returns') }}