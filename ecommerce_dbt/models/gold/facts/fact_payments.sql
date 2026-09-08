
SELECT
    -- Payment fact key
    payment_id,

    -- Dimension keys
    order_id,
    TO_CHAR(payment_date::DATE, 'YYYYMMDD')::INTEGER AS payment_date_key,

    -- Payment attributes
    payment_method,
    payment_status,
    payment_status_group,

    -- Payment measures
    amount,

    -- Analytical flags
    is_successful_payment,
    has_transaction_reference,

    -- Payment classification
    payment_amount_band,

    -- Operational metric
    payment_update_delay_days,

    -- Technical lineage timestamps
    updated_at,
    ingested_at,
    loaded_at,
    transformed_at,

    {{ modeled_timestamp() }} AS modeled_at

FROM {{ ref('silver_payments') }}
