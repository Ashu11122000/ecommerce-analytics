
-- ============================================================
-- Model: silver_payments
-- Layer: Silver
-- Grain: One row per payment (payment_id)
--
-- Purpose:
--   Clean and enrich payment data from the Bronze layer.
--   Standardize payment statuses, classify payment amounts,
--   and add transaction-reference and update-delay indicators.
--
-- Transformations:
--   1. Preserve the payment transaction grain.
--   2. Group payment statuses into reporting categories.
--   3. Identify recognized successful payments.
--   4. Classify payment amounts into fixed reporting bands.
--   5. Identify whether a transaction reference is available.
--   6. Calculate the calendar-day delay between payment_date
--      and updated_at.
--   7. Preserve source lineage and add a transformation timestamp.
-- ============================================================

WITH payments_base AS (

    -- Step 1: Select payment attributes from the Bronze model.
    -- Do not join orders or aggregate transactions at this layer.
    SELECT
        -- Payment and order identifiers
        payment_id,
        order_id,

        -- Payment details
        payment_date,
        payment_method,
        payment_status,
        amount,
        transaction_reference,

        -- Source lineage
        updated_at,
        ingested_at,
        loaded_at

    FROM {{ ref('bronze_payments') }}

),

payments_classified AS (

    -- Step 2: Add business-friendly payment classifications.
    SELECT
        *,

        -- Normalize statuses into reporting categories.
        -- Comparisons ignore surrounding spaces and letter case.
        CASE
            WHEN LOWER(TRIM(payment_status)) IN (
                'paid', 'completed', 'success', 'successful'
            )
                THEN 'Successful'

            WHEN LOWER(TRIM(payment_status)) IN (
                'failed', 'failure', 'declined'
            )
                THEN 'Failed'

            WHEN LOWER(TRIM(payment_status)) IN (
                'pending', 'processing'
            )
                THEN 'Pending'

            WHEN LOWER(TRIM(payment_status)) IN (
                'refunded', 'refund'
            )
                THEN 'Refunded'

            -- Distinguish missing statuses from unrecognized values.
            WHEN payment_status IS NULL
                 OR TRIM(payment_status) = ''
                THEN 'Unknown'

            ELSE 'Other'
        END AS payment_status_group,

        -- Identify payments with a recognized successful status.
        -- Missing statuses remain NULL, not FALSE.
        CASE
            WHEN LOWER(TRIM(payment_status)) IN (
                'paid', 'completed', 'success', 'successful'
            )
                THEN TRUE

            WHEN payment_status IS NULL
                 OR TRIM(payment_status) = ''
                THEN NULL

            ELSE FALSE
        END AS is_successful_payment,

        -- Classify payment amounts into fixed reporting bands.
        -- Thresholds use the numeric amount in its recorded currency.
        CASE
            WHEN amount IS NULL THEN 'Unknown'
            WHEN amount < 0 THEN 'Invalid'
            WHEN amount < 500 THEN 'Small'
            WHEN amount < 2000 THEN 'Medium'
            WHEN amount < 5000 THEN 'Large'
            ELSE 'Very Large'
        END AS payment_amount_band,

        -- Identify whether a non-empty transaction reference exists.
        CASE
            WHEN transaction_reference IS NULL
                 OR TRIM(transaction_reference) = ''
                THEN FALSE
            ELSE TRUE
        END AS has_transaction_reference,

        -- Calculate the calendar-day difference between the payment
        -- date and the source's last update timestamp.
        -- Negative values are retained for downstream investigation.
        CASE
            WHEN payment_date IS NOT NULL
                 AND updated_at IS NOT NULL
            THEN updated_at::DATE - payment_date::DATE
            ELSE NULL
        END AS payment_update_delay_days

    FROM payments_base

)

-- Step 3: Return the final enriched Silver payment model.
SELECT
    -- Payment identifiers and source attributes
    payment_id,
    order_id,
    payment_date,
    payment_method,
    payment_status,
    amount,
    transaction_reference,

    -- Derived payment classifications and indicators
    payment_status_group,
    is_successful_payment,
    payment_amount_band,
    has_transaction_reference,

    -- Source update monitoring
    payment_update_delay_days,

    -- Source lineage
    updated_at,
    ingested_at,
    loaded_at,

    -- Transformation execution timestamp.
    -- For a view, this value may change between query executions.
    {{ transformed_timestamp() }} AS transformed_at

FROM payments_classified
