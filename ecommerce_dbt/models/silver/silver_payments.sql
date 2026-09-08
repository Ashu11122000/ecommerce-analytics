SELECT
    payment_id,
    order_id,
    payment_date,
    payment_method,
    payment_status,
    amount,
    transaction_reference,

    -- Group payment statuses into business categories
    CASE
        WHEN LOWER(payment_status) IN ('paid', 'completed', 'success', 'successful')
            THEN 'Successful'
        WHEN LOWER(payment_status) IN ('failed', 'failure', 'declined')
            THEN 'Failed'
        WHEN LOWER(payment_status) IN ('pending', 'processing')
            THEN 'Pending'
        WHEN LOWER(payment_status) IN ('refunded', 'refund')
            THEN 'Refunded'
        ELSE 'Other'
    END AS payment_status_group,

    -- Identify successful payments
    CASE
        WHEN LOWER(payment_status) IN ('paid', 'completed', 'success', 'successful')
            THEN TRUE
        ELSE FALSE
    END AS is_successful_payment,

    -- Classify payment amount
    CASE
        WHEN amount < 500 THEN 'Small'
        WHEN amount < 2000 THEN 'Medium'
        WHEN amount < 5000 THEN 'Large'
        ELSE 'Very Large'
    END AS payment_amount_band,

    -- Check whether a transaction reference exists
    CASE
        WHEN transaction_reference IS NOT NULL
            THEN TRUE
        ELSE FALSE
    END AS has_transaction_reference,

    -- Days between the payment date and source update
    CASE
        WHEN updated_at IS NOT NULL
        THEN EXTRACT(
            DAY FROM (updated_at - payment_date)
        )::INTEGER
        ELSE NULL
    END AS payment_update_delay_days,

    updated_at,
    ingested_at,
    loaded_at,

    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_payments') }}