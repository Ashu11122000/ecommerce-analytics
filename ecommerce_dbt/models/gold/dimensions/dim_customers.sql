
-- ============================================================
-- Model: dim_customers
-- Layer: Gold
-- Purpose:
--   Create a business-friendly customer dimension for analytics.
--   Provide customer profile attributes, lifecycle classification,
--   and customer activity indicators for dashboard filtering.
--
-- Grain:
--   One row per customer (customer_id).
--
-- Source:
--   silver_customers
--
-- Important assumptions:
--   1. Customer lifecycle is based on customer tenure in days.
--   2. New Customer: tenure under 90 days.
--   3. Established Customer: tenure from 90 to 364 days.
--   4. Long-Term Customer: tenure of 365 days or more.
--   5. Lifecycle classification depends on customer_tenure_days
--      calculated by the Silver model.
-- ============================================================

WITH customer_dimension AS (

    -- Step 1: Select customer attributes from the Silver layer.
    SELECT
        customer_id,
        customer_name,
        email,
        gender,
        age_group,
        city,
        state,
        country,
        postal_code,
        customer_segment,
        customer_status_group,
        signup_date,
        customer_age,
        customer_tenure_days,
        is_active_customer,

        -- Classify customers by how long they have been registered.
        -- Missing tenure remains Unknown instead of being
        -- incorrectly assigned to a lifecycle stage.
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

        -- Carry source and transformation timestamps forward
        -- for lineage and data auditing.
        ingested_at,
        loaded_at,
        transformed_at

    FROM {{ ref('silver_customers') }}

)

-- Step 2: Return the final customer dimension.
SELECT
    customer_id,
    customer_name,
    email,
    gender,
    age_group,
    city,
    state,
    country,
    postal_code,
    customer_segment,
    customer_status_group,
    signup_date,
    customer_age,
    customer_tenure_days,
    is_active_customer,
    customer_lifecycle_stage,

    -- Technical lineage timestamps.
    ingested_at,
    loaded_at,
    transformed_at,

    -- Record when this Gold model's transformation executes.
    -- Actual behavior depends on the modeled_timestamp() macro
    -- and the model's materialization.
    {{ modeled_timestamp() }} AS modeled_at

FROM customer_dimension
