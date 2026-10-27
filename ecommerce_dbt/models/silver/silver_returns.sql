
-- ============================================================
-- Model: silver_returns
-- Layer: Silver
-- Purpose:
--   Enrich return data from the Bronze layer with standardized
--   return status groups, refund metrics, validation flags,
--   and source update monitoring.
--
-- Grain:
--   One row per return record (return_id).
--
-- Important assumptions:
--   1. Only approved, completed, or processed returns are
--      classified as approved.
--   2. Refund per unit is refund_amount divided by return_quantity.
--   3. A positive refund amount indicates that a refund exists.
--   4. Return update delay is measured in calendar days.
-- ============================================================

WITH returns_base AS (

    -- Step 1: Select return attributes from the Bronze model.
    SELECT
        return_id,
        order_item_id,
        return_date,
        return_reason,
        return_quantity,
        refund_amount,
        return_status,
        updated_at,
        ingested_at,
        loaded_at

    FROM {{ ref('bronze_returns') }}

),

returns_classified AS (

    -- Step 2: Add business-friendly return classifications
    -- and derived metrics.
    SELECT
        *,

        -- Group return statuses into standardized categories.
        -- Ignore differences in letter case and surrounding spaces.
        CASE
            WHEN LOWER(TRIM(return_status)) IN (
                'approved',
                'completed',
                'processed'
            )
                THEN 'Approved'

            WHEN LOWER(TRIM(return_status)) IN (
                'pending',
                'requested',
                'under review',
                'under_review'
            )
                THEN 'Pending'

            WHEN LOWER(TRIM(return_status)) IN (
                'rejected',
                'denied',
                'cancelled',
                'canceled'
            )
                THEN 'Rejected'

            -- Separate missing statuses from unrecognized values.
            WHEN return_status IS NULL
                OR TRIM(return_status) = ''
                THEN 'Unknown'

            ELSE 'Other'
        END AS return_status_group,

        -- Identify returns whose statuses indicate approval
        -- or processing according to the business rule above.
        -- This does not independently verify that a refund was paid.
        CASE
            WHEN LOWER(TRIM(return_status)) IN (
                'approved',
                'completed',
                'processed'
            )
                THEN TRUE

            WHEN return_status IS NULL
                OR TRIM(return_status) = ''
                THEN NULL

            ELSE FALSE
        END AS is_return_approved,

        -- Calculate the refund amount per returned unit.
        -- Return NULL when quantity is missing or not positive,
        -- or when the refund amount is unknown.
        CASE
            WHEN return_quantity > 0
                AND refund_amount IS NOT NULL
            THEN ROUND(
                (refund_amount / return_quantity)::NUMERIC,
                2
            )
            ELSE NULL
        END AS refund_per_unit,

        -- Flag returns with a positive refund amount.
        -- A positive refund does not by itself prove that the
        -- return was approved or that the refund was paid.
        CASE
            WHEN refund_amount IS NULL THEN NULL
            WHEN refund_amount > 0 THEN TRUE
            ELSE FALSE
        END AS has_refund,

        -- Identify missing, zero, or negative return quantities.
        CASE
            WHEN return_quantity IS NULL THEN NULL
            WHEN return_quantity <= 0 THEN TRUE
            ELSE FALSE
        END AS has_invalid_return_quantity,

        -- Calculate the calendar-day difference between the
        -- return date and the source's last update date.
        -- Negative values may indicate a data-quality issue.
        CASE
            WHEN return_date IS NOT NULL
                AND updated_at IS NOT NULL
            THEN updated_at::DATE - return_date::DATE
            ELSE NULL
        END AS return_update_delay_days

    FROM returns_base

)

-- Step 3: Return the final enriched Silver return model.
SELECT
    -- Return identifiers and descriptive attributes.
    return_id,
    order_item_id,
    return_date,
    return_reason,
    return_quantity,
    refund_amount,
    return_status,

    -- Standardized return status and approval indicator.
    return_status_group,
    is_return_approved,

    -- Refund metrics and validation flags.
    refund_per_unit,
    has_refund,
    has_invalid_return_quantity,

    -- Source update monitoring.
    return_update_delay_days,

    -- Source and ingestion audit timestamps.
    updated_at,
    ingested_at,
    loaded_at,

    -- Record when the transformation query executes.
    -- In a view, this value may change when the view is queried.
    {{ transformed_timestamp() }} AS transformed_at

FROM returns_classified
