SELECT
    customer_id,
    TRIM(customer_name) AS customer_name,
    LOWER(TRIM(email)) AS email,
    TRIM(city) AS city,
    signup_date,
    ingested_at,
    loaded_at,
    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_customers') }}