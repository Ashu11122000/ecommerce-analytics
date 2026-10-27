
-- ============================================================
-- Model: bronze_customers
-- Layer: Bronze
-- Grain: One row per source customer (customer_id)
--
-- Purpose:
--   Standardize basic customer attributes while preserving
--   the source-oriented structure for downstream Silver models.
--
-- Transformations:
--   1. Trim surrounding whitespace from text attributes.
--   2. Normalize email addresses to lowercase.
--   3. Convert blank optional text fields to NULL.
--   4. Preserve source business dates and timestamps.
--   5. Add a model execution timestamp for audit purposes.
--
-- Important:
--   - No deduplication is performed in this model.
--   - No customer business classifications are calculated here.
--   - Source records are not modified by this SELECT statement.
--   - loaded_at is query execution time for this view; it is
--     not a persisted historical load timestamp.
-- ============================================================

SELECT
    -- Customer identifier
    customer_id,

    -- Customer identity attributes
    NULLIF(TRIM(customer_name), '') AS customer_name,
    LOWER(NULLIF(TRIM(email), '')) AS email,
    NULLIF(TRIM(phone), '') AS phone,

    -- Standardize selected categorical attributes
    NULLIF(INITCAP(TRIM(gender)), '') AS gender,

    -- Preserve source date of birth
    date_of_birth,

    -- Location attributes
    NULLIF(INITCAP(TRIM(city)), '') AS city,
    NULLIF(INITCAP(TRIM(state)), '') AS state,
    NULLIF(INITCAP(TRIM(country)), '') AS country,
    NULLIF(TRIM(postal_code), '') AS postal_code,

    -- Customer classification attributes
    NULLIF(INITCAP(TRIM(customer_segment)), '')
        AS customer_segment,

    NULLIF(INITCAP(TRIM(customer_status)), '')
        AS customer_status,

    -- Preserve source business and audit timestamps
    signup_date,
    updated_at,
    ingested_at,

    -- Query execution timestamp.
    -- Because this model is a view, the value changes when queried.
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'customers') }}
