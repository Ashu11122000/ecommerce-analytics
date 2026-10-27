
-- ============================================================
-- Model: silver_payments
-- Layer: Silver
-- Purpose:
--   Clean and enrich payment data from the Bronze layer.
--   Standardize payment statuses, classify payment amounts,
--   and add transaction-reference and update-delay indicators.
--
-- Grain:
--   One row per payment (payment_id).
--
-- Important assumptions:
--   1. Payment amounts are expressed in the currency recorded
--      by the associated order.
--   2. Payment amount bands use fixed thresholds.
--   3. Successful payment statuses are explicitly defined below.
--   4. Payment update delay measures calendar days between
--      payment_date and updated_at.
-- ============================================================

WITH payments_base AS (

    -- Step 1: Select payment attributes from the Bronze model.
    SELECT
        payment_id,
        order_id,
        payment_date,
        payment_method,
        payment_status,
        amount,
        transaction_reference,
        updated_at,
        ingested_at,
        loaded_at

    FROM {{ ref('bronze_payments') }}

),

payments_classified AS (

    -- Step 2: Add business-friendly payment classifications.
    SELECT
        *,

        -- Group payment statuses into standardized categories.
        -- Trim spaces and ignore differences in letter case.
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
        -- Missing statuses remain NULL rather than being treated
        -- as confirmed unsuccessful payments.
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
        -- Thresholds are in the currency unit of the payment.
        CASE
            WHEN amount IS NULL THEN 'Unknown'
            WHEN amount < 0 THEN 'Invalid'
            WHEN amount < 500 THEN 'Small'
            WHEN amount < 2000 THEN 'Medium'
            WHEN amount < 5000 THEN 'Large'
            ELSE 'Very Large'
        END AS payment_amount_band,

        -- Flag whether a non-empty transaction reference exists.
        CASE
            WHEN transaction_reference IS NULL
                OR TRIM(transaction_reference) = ''
                THEN FALSE
            ELSE TRUE
        END AS has_transaction_reference,

        -- Calculate the calendar-day difference between the
        -- payment date and the source's last update timestamp.
        -- Negative values may indicate a data-quality issue.
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
    -- Payment identifiers and descriptive attributes.
    payment_id,
    order_id,
    payment_date,
    payment_method,
    payment_status,
    amount,
    transaction_reference,

    -- Standardized payment classifications and indicators.
    payment_status_group,
    is_successful_payment,
    payment_amount_band,
    has_transaction_reference,

    -- Source update monitoring.
    payment_update_delay_days,

    -- Ingestion and audit timestamps.
    updated_at,
    ingested_at,
    loaded_at,

    -- Record when the transformation query executes.
    -- In a view, this may change each time the view is queried.
    {{ transformed_timestamp() }} AS transformed_at

FROM payments_classified
