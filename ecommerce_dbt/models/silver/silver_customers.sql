SELECT
    customer_id,
    TRIM(customer_name) AS customer_name,
    LOWER(TRIM(email)) AS email,
    COALESCE(NULLIF(TRIM(city), ''), 'Unknown') AS city,
    signup_date,
    loaded_at
FROM {{ ref('bronze_customers') }}
WHERE customer_id IS NOT NULL