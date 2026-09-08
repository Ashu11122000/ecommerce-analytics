SELECT
    customer_id,
    TRIM(customer_name) AS customer_name,
    LOWER(TRIM(email)) AS email,
    NULLIF(TRIM(phone), '') AS phone,
    INITCAP(TRIM(gender)) AS gender,
    date_of_birth,
    INITCAP(TRIM(city)) AS city,
    INITCAP(TRIM(state)) AS state,
    INITCAP(TRIM(country)) AS country,
    TRIM(postal_code) AS postal_code,
    INITCAP(TRIM(customer_segment)) AS customer_segment,
    INITCAP(TRIM(customer_status)) AS customer_status,
    signup_date,
    updated_at,
    ingested_at,
    
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'customers') }}