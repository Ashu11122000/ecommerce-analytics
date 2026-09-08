SELECT
    payment_id,
    order_id,
    payment_date,
    INITCAP(TRIM(payment_method)) AS payment_method,
    INITCAP(TRIM(payment_status)) AS payment_status,
    amount,
    NULLIF(TRIM(transaction_reference), '') AS transaction_reference,
    updated_at,
    ingested_at,

    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'payments') }}