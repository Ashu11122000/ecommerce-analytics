
-- ============================================================
-- Model: fact_payments
-- Layer: Gold
-- Grain: One row per payment (payment_id)
--
-- Purpose:
--   Support payment monitoring, payment-method analysis,
--   payment success reporting, and operational data-quality checks.
--
-- Source:
--   silver_payments
--
-- Business definitions:
--   amount:
--     Payment amount as recorded in the Silver layer.
--
--   is_successful_payment:
--     Success indicator inherited from Silver's standardized
--     payment-status rules.
--
--   payment_update_delay_days:
--     Calendar-day difference between payment_date and updated_at,
--     as calculated in the Silver model.
--
-- Important assumptions:
--   - payment_id uniquely identifies a payment record.
--   - Payment amounts must not be aggregated across currencies
--     unless a consistent currency-conversion method is applied.
--   - Payment statuses and classifications are inherited from Silver.
--   - Missing payment dates produce a NULL date dimension key.
-- ============================================================

WITH payments_base AS (

    -- Step 1: Select enriched payment records from Silver.
    SELECT
        payment_id,
        order_id,
        payment_date,
        payment_method,
        payment_status,
        payment_status_group,
        amount,
        is_successful_payment,
        has_transaction_reference,
        payment_amount_band,
        payment_update_delay_days,
        updated_at,
        ingested_at,
        loaded_at,
        transformed_at

    FROM {{ ref('silver_payments') }}

),

payments_prepared AS (

    -- Step 2: Add a date dimension key for dashboard joins.
    SELECT
        *,

        -- Integer key in YYYYMMDD format.
        -- Example: 20261027 represents October 27, 2026.
        CASE
            WHEN payment_date IS NOT NULL
                THEN TO_CHAR(
                    payment_date::DATE,
                    'YYYYMMDD'
                )::INTEGER
            ELSE NULL
        END AS payment_date_key

    FROM payments_base

)

-- Step 3: Return the final Gold payment fact table.
SELECT

    -- Payment fact identifier.
    payment_id,

    -- Keys for order analysis and date dimension joins.
    order_id,
    payment_date_key,

    -- Descriptive payment attributes.
    payment_method,
    payment_status,
    payment_status_group,

    -- Payment amount in its recorded currency.
    amount,

    -- Payment success and data-quality indicators.
    is_successful_payment,
    has_transaction_reference,

    -- Payment amount classification inherited from Silver.
    payment_amount_band,

    -- Operational monitoring metric.
    payment_update_delay_days,

    -- Source and transformation lineage.
    updated_at,
    ingested_at,
    loaded_at,
    transformed_at,

    -- Gold model execution timestamp.
    -- Behavior depends on the macro implementation and
    -- the model's materialization.
    {{ modeled_timestamp() }} AS modeled_at

FROM payments_prepared
