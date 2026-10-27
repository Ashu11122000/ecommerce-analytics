
-- ============================================================
-- Model: silver_returns
-- Layer: Silver
-- Grain: One row per return record (return_id)
--
-- Purpose:
--   Enrich return data from the Bronze layer with standardized
--   return status groups, refund metrics, validation flags,
--   and source update monitoring.
--
-- Transformations:
--   1. Standardize return statuses into reporting categories.
--   2. Identify returns approved under the defined status rules.
--   3. Calculate refund amount per returned unit.
--   4. Identify records with positive refund amounts.
--   5. Flag invalid return quantities.
--   6. Calculate return update delay in calendar days.
--   7. Preserve source lineage and add a transformation timestamp.
--
-- Important assumptions:
--   - Approved, completed, and processed statuses are classified
--     as approved.
--   - Refund per unit = refund_amount / return_quantity.
--   - A positive refund amount indicates a recorded refund amount,
--     not necessarily a refund that has been paid.
--   - Return update delay is measured in calendar days.
--   - Source anomalies are flagged rather than silently corrected.
-- ============================================================

WITH returns_base AS (

    -- Step 1: Select return attributes from the Bronze model.
    -- Preserve one row per return_id without joins or aggregation.
    SELECT
        -- Return and order-item identifiers
        return_id,
        order_item_id,

        -- Original return attributes
        return_date,
        return_reason,
        return_quantity,
        refund_amount,
        return_status,

        -- Source lineage
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

        -- Normalize return statuses into reporting categories.
        -- Comparisons ignore letter case and surrounding spaces.
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
        -- or processing under the defined business rule.
        -- This does not independently verify refund payment.
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

        -- Calculate refund amount per returned unit.
        -- Cast before division to ensure decimal arithmetic.
        -- NULL is returned if quantity is not positive or the
        -- refund amount is unknown.
        CASE
            WHEN return_quantity > 0
                 AND refund_amount IS NOT NULL
            THEN ROUND(
                refund_amount::NUMERIC
                / return_quantity::NUMERIC,
                2
            )
            ELSE NULL
        END AS refund_per_unit,

        -- Flag whether a positive refund amount is recorded.
        -- A positive amount does not prove the refund was paid.
        CASE
            WHEN refund_amount IS NULL THEN NULL
            WHEN refund_amount > 0 THEN TRUE
            ELSE FALSE
        END AS has_refund,

        -- Flag zero or negative return quantities.
        -- Missing quantities remain unknown rather than invalid.
        CASE
            WHEN return_quantity IS NULL THEN NULL
            WHEN return_quantity <= 0 THEN TRUE
            ELSE FALSE
        END AS has_invalid_return_quantity,

        -- Calculate calendar-day difference between the return
        -- date and the source's last update date.
        -- Negative values are retained for investigation.
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
    -- Return identifiers and source attributes
    return_id,
    order_item_id,
    return_date,
    return_reason,
    return_quantity,
    refund_amount,
    return_status,

    -- Standardized status and approval indicator
    return_status_group,
    is_return_approved,

    -- Refund metrics and validation flags
    refund_per_unit,
    has_refund,
    has_invalid_return_quantity,

    -- Source update monitoring
    return_update_delay_days,

    -- Source lineage
    updated_at,
    ingested_at,
    loaded_at,

    -- Transformation execution timestamp.
    -- For a view, this value may change when the view is queried.
    {{ transformed_timestamp() }} AS transformed_at

FROM returns_classified
