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

    -- Customer lifecycle classification
    CASE
        WHEN customer_tenure_days < 90
            THEN 'New Customer'

        WHEN customer_tenure_days < 365
            THEN 'Established Customer'

        ELSE 'Long-Term Customer'
    END AS customer_lifecycle_stage,

    -- Technical lineage timestamps
    ingested_at,
    loaded_at,
    transformed_at,

    {{ modeled_timestamp() }} AS modeled_at

FROM {{ ref('silver_customers') }}
