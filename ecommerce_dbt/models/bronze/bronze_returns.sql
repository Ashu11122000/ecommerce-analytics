
-- ============================================================
-- Model: bronze_returns
-- Layer: Bronze
-- Grain: One row per source return record (return_id)
--
-- Purpose:
--   Standardize return attributes while preserving source values
--   for downstream data quality checks and analytics.
--
-- Transformations:
--   1. Preserve return and order-item identifiers.
--   2. Retain the original return date, quantity, and refund amount.
--   3. Standardize return reason and status capitalization.
--   4. Convert blank optional text values to NULL.
--   5. Preserve source timestamps for data lineage.
--   6. Add a model execution timestamp.
--
-- Important assumptions:
--   - An order item may have multiple return records.
--   - No joins or aggregations are performed in Bronze.
--   - Return quantities and refund amounts are not defaulted
--     or silently corrected.
--   - A return record is not necessarily a completed return.
--   - Return-status business rules belong in Silver/Gold.
--   - loaded_at is query execution time because this model
--     is configured as a view; it is not a persisted load time.
-- ============================================================

SELECT
    -- Return and order-item identifiers
    return_id,
    order_item_id,

    -- Return date and reason
    return_date,
    NULLIF(INITCAP(TRIM(return_reason)), '') AS return_reason,

    -- Preserve original quantity and refund amount
    return_quantity,
    refund_amount,

    -- Standardized return status
    NULLIF(INITCAP(TRIM(return_status)), '') AS return_status,

    -- Source audit timestamps
    updated_at,
    ingested_at,

    -- Model execution timestamp
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'returns') }}
