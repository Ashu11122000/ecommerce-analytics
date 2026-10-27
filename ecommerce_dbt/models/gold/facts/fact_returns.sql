
-- ============================================================
-- Model: fact_returns
-- Layer: Gold
-- Grain: One row per return record (return_id)
--
-- Purpose:
--   Provide an analytics-ready fact table for return and refund
--   analysis, return reasons, return statuses, and data quality.
--
-- Source:
--   silver_returns
--
-- Business definitions:
--   refund_amount:
--     Refund amount recorded for the return.
--
--   refund_per_unit:
--     Refund amount divided by return quantity, inherited from
--     the Silver model.
--
--   is_return_approved:
--     Approval indicator inherited from Silver status rules.
--
-- Important assumptions:
--   - Each return_id identifies one return record.
--   - Refund amounts use the relevant transaction currency.
--   - Amounts across different currencies must not be aggregated
--     without a currency-conversion method.
--   - Return classifications and quality indicators are inherited
--     from Silver.
--   - One return record may refer to an order item, and multiple
--     return records may exist for the same order item.
-- ============================================================

WITH returns_base AS (

    -- Step 1: Read standardized return records from Silver.
    SELECT
        return_id,
        order_item_id,
        return_date,
        return_reason,
        return_quantity,
        refund_amount,
        return_status,
        return_status_group,
        is_return_approved,
        refund_per_unit,
        has_refund,
        has_invalid_return_quantity,
        return_update_delay_days,
        updated_at,
        ingested_at,
        loaded_at,
        transformed_at

    FROM {{ ref('silver_returns') }}

),

returns_prepared AS (

    -- Step 2: Add the date dimension key.
    SELECT
        *,

        -- Integer date key in YYYYMMDD format.
        -- Example: 20261027 represents October 27, 2026.
        -- Preserve NULL when return_date is unavailable.
        CASE
            WHEN return_date IS NOT NULL
                THEN TO_CHAR(
                    return_date::DATE,
                    'YYYYMMDD'
                )::INTEGER
            ELSE NULL
        END AS return_date_key

    FROM returns_base

)

-- Step 3: Return the final Gold return fact table.
SELECT

    -- Return fact identifier.
    return_id,

    -- Keys for order-item analysis and date dimension joins.
    order_item_id,
    return_date_key,

    -- Return descriptive attributes.
    return_date,
    return_reason,
    return_status,
    return_status_group,

    -- Return quantity and refund measures.
    return_quantity,
    refund_amount,
    refund_per_unit,

    -- Return approval and data-quality indicators.
    is_return_approved,
    has_refund,
    has_invalid_return_quantity,

    -- Operational monitoring metric.
    return_update_delay_days,

    -- Source and transformation lineage.
    updated_at,
    ingested_at,
    loaded_at,
    transformed_at,

    -- Gold model execution timestamp.
    -- Behavior depends on the macro implementation and
    -- the model's materialization.
    {{ modeled_timestamp() }} AS modeled_at

FROM returns_prepared
