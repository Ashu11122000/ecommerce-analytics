SELECT
    customer_id,
    customer_name,
    email,
    city,
    signup_date,

    ingested_at,
    loaded_at,
    transformed_at,

    CURRENT_TIMESTAMP AS modeled_at

FROM {{ ref('silver_customers') }}