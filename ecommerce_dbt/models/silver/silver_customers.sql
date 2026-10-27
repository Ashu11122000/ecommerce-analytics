
-- ============================================================
-- Model: silver_customers
-- Layer: Silver
-- Grain: One row per customer_id
--
-- Purpose:
--   Apply customer business logic, derive age and tenure,
--   and standardize customer status for analytics.
--
-- Assumptions:
--   - Age is calculated relative to the current date.
--   - Future birth dates produce an unknown age group.
--   - Future signup dates produce NULL tenure.
--   - Only recognized active statuses are marked active.
-- ============================================================

WITH customer_base AS (

    SELECT
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
        updated_at,
        ingested_at,
        loaded_at,

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

        CASE
            WHEN signup_date IS NULL
            OR signup_date > CURRENT_DATE
            THEN NULL
            ELSE CURRENT_DATE - signup_date
        END AS customer_tenure_days,

        CASE
            WHEN LOWER(TRIM(customer_status)) IN ('active', 'enabled')
                THEN TRUE
            ELSE FALSE
        END AS is_active_customer,

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
    customer_age,
    age_group,
    customer_tenure_days,
    is_active_customer,
    customer_status_group,

    updated_at,
    ingested_at,
    loaded_at,

    {{ transformed_timestamp() }} AS transformed_at

FROM customer_classified
