
-- ============================================================
-- Model: bronze_returns
-- Layer: Bronze
-- Grain: One row per source return record (return_id)
--
-- Purpose:
--   Standardize return attributes while preserving source
--   values for downstream quality checks and analytics.
--
-- Important:
--   - An order item may have multiple return records.
--   - Preserve refund amounts and return quantities as recorded.
--   - Do not count every return record as a completed return.
--   - Apply return-status business rules in Silver/Gold.
--   - Preserve source timestamps for lineage.
-- ============================================================

SELECT
    return_id,
    order_item_id,
    return_date,
    NULLIF(INITCAP(TRIM(return_reason)), '') AS return_reason,
    return_quantity,
    refund_amount,
    NULLIF(INITCAP(TRIM(return_status)), '') AS return_status,
    updated_at,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at
    
FROM {{ source('raw', 'returns') }}
