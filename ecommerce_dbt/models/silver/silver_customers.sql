SELECT
    customer_id,
    TRIM(customer_name) AS customer_name,
    LOWER(TRIM(email)) AS email,
    TRIM(city) AS city,
    signup_date,
    ingested_at,
    loaded_at,
    CURRENT_TIMESTAMP AS transformed_at

FROM {{ ref('bronze_customers') }}