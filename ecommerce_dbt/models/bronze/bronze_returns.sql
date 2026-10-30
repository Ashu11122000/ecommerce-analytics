
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
