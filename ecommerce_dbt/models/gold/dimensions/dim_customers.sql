
-- ============================================================
-- Model: dim_customers
-- Layer: Gold
-- Grain: One row per customer (customer_id)
--
-- Purpose:
--   Create a business-friendly customer dimension for analytics.
--   Provide customer profile attributes, lifecycle classification,
--   and activity indicators for dashboard filtering and analysis.
--
-- Source:
--   silver_customers
--
-- Transformations:
--   1. Select standardized customer attributes from Silver.
--   2. Preserve customer age, age group, and tenure.
--   3. Classify customers by lifecycle stage.
--   4. Preserve source and transformation lineage timestamps.
--   5. Add a Gold modeling timestamp.
--
-- Lifecycle assumptions:
--   - New Customer: tenure under 90 days.
--   - Established Customer: tenure from 90 through 364 days.
--   - Long-Term Customer: tenure of 365 days or more.
--   - Missing tenure is classified as Unknown.
--   - Negative tenure is classified as Invalid Tenure.
--   - Tenure is inherited from silver_customers and is
--     calculated relative to the current date.
-- ============================================================

WITH customer_dimension AS (

    -- Step 1: Select standardized customer attributes from Silver.
    -- Preserve the customer-level grain; do not join or aggregate.
    SELECT
        -- Customer identifiers and profile attributes
        customer_id,
        customer_name,
        email,
        gender,
        age_group,
        city,
        state,
        country,
        postal_code,

        -- Customer segmentation and status
        customer_segment,
        customer_status_group,
        is_active_customer,

        -- Customer lifecycle attributes
        signup_date,
        customer_age,
        customer_tenure_days,

        -- Classify customers by registration tenure.
        -- Missing and negative tenure values remain distinguishable.
        CASE
            WHEN customer_tenure_days IS NULL
                THEN 'Unknown'

            WHEN customer_tenure_days < 0
                THEN 'Invalid Tenure'

            WHEN customer_tenure_days < 90
                THEN 'New Customer'

            WHEN customer_tenure_days < 365
                THEN 'Established Customer'

            ELSE 'Long-Term Customer'
        END AS customer_lifecycle_stage,

        -- Source and upstream transformation lineage
        ingested_at,
        loaded_at,
        transformed_at

    FROM {{ ref('silver_customers') }}

)

-- Step 2: Return the final Gold customer dimension.
SELECT
    -- Customer key and profile attributes
    customer_id,
    customer_name,
    email,
    gender,
    age_group,
    city,
    state,
    country,
    postal_code,

    -- Customer segmentation and status
    customer_segment,
    customer_status_group,
    is_active_customer,

    -- Customer lifecycle attributes
    signup_date,
    customer_age,
    customer_tenure_days,
    customer_lifecycle_stage,

    -- Technical lineage timestamps
    ingested_at,
    loaded_at,
    transformed_at,

    -- Gold modeling timestamp.
    -- Its persistence depends on the macro and materialization.
    {{ modeled_timestamp() }} AS modeled_at

FROM customer_dimension
