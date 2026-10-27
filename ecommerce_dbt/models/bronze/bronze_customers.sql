
-- ============================================================
-- Model: bronze_customers
-- Layer: Bronze
-- Grain: One row per source customer (customer_id)
--
-- Purpose:
--   Standardize basic customer fields while retaining the
--   source-oriented structure for downstream Silver models.
--
-- Data quality:
--   - Trim text fields.
--   - Normalize email casing.
--   - Convert blank optional text values to NULL.
--   - Preserve source and ingestion timestamps.
--
-- Note:
--   This model does not deduplicate customers or apply
--   business rules. Those operations belong in Silver.
-- ============================================================

SELECT
    customer_id,
    NULLIF(TRIM(customer_name), '') AS customer_name,
    LOWER(NULLIF(TRIM(email), '')) AS email,
    NULLIF(TRIM(phone), '') AS phone,
    NULLIF(INITCAP(TRIM(gender)), '') AS gender,
    date_of_birth,
    NULLIF(INITCAP(TRIM(city)), '') AS city,
    NULLIF(INITCAP(TRIM(state)), '') AS state,
    NULLIF(INITCAP(TRIM(country)), '') AS country,
    NULLIF(TRIM(postal_code), '') AS postal_code,
    NULLIF(INITCAP(TRIM(customer_segment)), '') AS customer_segment,
    NULLIF(INITCAP(TRIM(customer_status)), '') AS customer_status,
    signup_date,
    updated_at,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'customers') }}
