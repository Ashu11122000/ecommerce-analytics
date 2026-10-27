
-- ============================================================
-- Model: silver_customers
-- Layer: Silver
-- Grain: One row per customer_id
--
-- Purpose:
--   Apply customer business logic, derive age and tenure,
--   and standardize customer status for analytics.
--
-- Transformations:
--   1. Read standardized customer records from Bronze.
--   2. Calculate customer age using the current date.
--   3. Assign customers to age groups.
--   4. Calculate customer tenure in days.
--   5. Derive a boolean active-customer indicator.
--   6. Group customer statuses into reporting categories.
--   7. Preserve source lineage and add a transformation timestamp.
--
-- Assumptions:
--   - Age is calculated relative to the current date.
--   - Future birth dates produce NULL age and an Unknown age group.
--   - Future signup dates produce NULL tenure.
--   - Only recognized active statuses are marked active.
--   - Status comparisons are case-insensitive and whitespace-trimmed.
--   - Customer identifiers and source grain are preserved.
--   - transformed_at uses the project's transformed_timestamp macro.
-- ============================================================

WITH customer_base AS (

    SELECT
        -- Customer identifiers and descriptive attributes
        customer_id,
        customer_name,
        email,
        phone,
        gender,
        date_of_birth,
        city,
        state,
        country,
        postal_code,
        customer_segment,
        customer_status,
        signup_date,

        -- Source lineage
        updated_at,
        ingested_at,
        loaded_at,

        -- Calculate age only when the birth date is valid
        CASE
            WHEN date_of_birth IS NOT NULL
                 AND date_of_birth <= CURRENT_DATE
            THEN EXTRACT(
                YEAR FROM AGE(CURRENT_DATE, date_of_birth)
            )::INTEGER
            ELSE NULL
        END AS customer_age

    FROM {{ ref('bronze_customers') }}

),

customer_classified AS (

    SELECT
        *,

        -- Assign an age group for customer segmentation
        CASE
            WHEN customer_age IS NULL THEN 'Unknown'
            WHEN customer_age < 18 THEN 'Under 18'
            WHEN customer_age BETWEEN 18 AND 24 THEN '18-24'
            WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
            WHEN customer_age BETWEEN 35 AND 44 THEN '35-44'
            WHEN customer_age BETWEEN 45 AND 54 THEN '45-54'
            WHEN customer_age BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65+'
        END AS age_group,

        -- Calculate tenure in days; do not assign negative tenure
        CASE
            WHEN signup_date IS NULL
                 OR signup_date > CURRENT_DATE
            THEN NULL
            ELSE CURRENT_DATE - signup_date
        END AS customer_tenure_days,

        -- Identify recognized active customer statuses
        CASE
            WHEN LOWER(TRIM(customer_status)) IN ('active', 'enabled')
                THEN TRUE
            ELSE FALSE
        END AS is_active_customer,

        -- Standardize source statuses into reporting categories
        CASE
            WHEN LOWER(TRIM(customer_status)) IN ('active', 'enabled')
                THEN 'Active'
            WHEN LOWER(TRIM(customer_status)) IN ('inactive', 'disabled')
                THEN 'Inactive'
            WHEN LOWER(TRIM(customer_status)) IN ('blocked', 'suspended')
                THEN 'Restricted'
            ELSE 'Unknown'
        END AS customer_status_group

    FROM customer_base

)

SELECT
    -- Customer attributes
    customer_id,
    customer_name,
    email,
    phone,
    gender,
    date_of_birth,
    city,
    state,
    country,
    postal_code,
    customer_segment,
    customer_status,
    signup_date,

    -- Derived customer analytics
    customer_age,
    age_group,
    customer_tenure_days,
    is_active_customer,
    customer_status_group,

    -- Source lineage
    updated_at,
    ingested_at,
    loaded_at,

    -- Transformation audit timestamp
    {{ transformed_timestamp() }} AS transformed_at

FROM customer_classified
