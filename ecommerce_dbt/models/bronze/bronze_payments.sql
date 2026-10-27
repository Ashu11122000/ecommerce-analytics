
-- ============================================================
-- Model: bronze_payments
-- Layer: Bronze
-- Grain: One row per source payment transaction (payment_id)
--
-- Purpose:
--   Standardize payment attributes while retaining the
--   source structure for downstream Silver and Gold models.
--
-- Important:
--   - An order can have multiple payment transactions.
--   - Do not aggregate payments at order level in Bronze.
--   - Preserve the original amount for financial validation.
--   - Blank optional text values are converted to NULL.
--   - Payment status rules are applied downstream.
-- ============================================================

SELECT
    payment_id,
    order_id,
    payment_date,
    NULLIF(INITCAP(TRIM(payment_method)), '') AS payment_method,
    NULLIF(INITCAP(TRIM(payment_status)), '') AS payment_status,
    amount,
    NULLIF(TRIM(transaction_reference), '') AS transaction_reference,
    updated_at,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'payments') }}
