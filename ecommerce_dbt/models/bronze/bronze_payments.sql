
-- ============================================================
-- Model: bronze_payments
-- Layer: Bronze
-- Grain: One row per source payment transaction (payment_id)
--
-- Purpose:
--   Standardize payment attributes while retaining the source
--   structure for downstream Silver and Gold transformations.
--
-- Transformations:
--   1. Preserve payment and order identifiers.
--   2. Standardize payment method and status capitalization.
--   3. Convert blank transaction references to NULL.
--   4. Preserve the original payment amount for validation.
--   5. Retain source timestamps for lineage.
--   6. Add a model execution timestamp.
-- ============================================================

SELECT
    -- Payment transaction and order identifiers
    payment_id,
    order_id,

    -- Payment date
    payment_date,

    -- Standardized payment attributes
    NULLIF(INITCAP(TRIM(payment_method)), '') AS payment_method,
    NULLIF(INITCAP(TRIM(payment_status)), '') AS payment_status,

    -- Preserve the original amount for financial validation
    amount,

    -- Normalize blank transaction references to NULL
    NULLIF(TRIM(transaction_reference), '') AS transaction_reference,

    -- Source audit timestamps
    updated_at,
    ingested_at,

    -- Model execution timestamp
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'payments') }}
