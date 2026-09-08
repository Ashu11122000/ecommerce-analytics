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

    -- Customer age at the current date
    CASE
        WHEN date_of_birth IS NOT NULL
        THEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth))::INTEGER
        ELSE NULL
    END AS customer_age,

    -- Business-friendly age grouping
    CASE
        WHEN date_of_birth IS NULL THEN 'Unknown'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 18
            THEN 'Under 18'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) BETWEEN 18 AND 24
            THEN '18-24'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) BETWEEN 25 AND 34
            THEN '25-34'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) BETWEEN 35 AND 44
            THEN '35-44'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) BETWEEN 45 AND 54
            THEN '45-54'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) BETWEEN 55 AND 64
            THEN '55-64'
        ELSE '65+'
    END AS age_group,

    -- Number of days the customer has been registered
    CURRENT_DATE - signup_date AS customer_tenure_days,

    -- Active customer flag
    CASE
        WHEN LOWER(customer_status) IN ('active', 'enabled')
            THEN TRUE
        ELSE FALSE
    END AS is_active_customer,

    -- Business classification of customer status
    CASE
        WHEN LOWER(customer_status) IN ('active', 'enabled')
            THEN 'Active'
        WHEN LOWER(customer_status) IN ('inactive', 'disabled')
            THEN 'Inactive'
        WHEN LOWER(customer_status) IN ('blocked', 'suspended')
            THEN 'Restricted'
        ELSE 'Unknown'
    END AS customer_status_group,

    -- Technical/source timestamps
    updated_at,
    ingested_at,
    loaded_at,

    -- Silver transformation timestamp
    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_customers') }}
