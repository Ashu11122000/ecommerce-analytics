SELECT
    customer_id,
    customer_name,
    email,
    city,
    signup_date,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at
FROM {{ source('raw', 'customers') }}