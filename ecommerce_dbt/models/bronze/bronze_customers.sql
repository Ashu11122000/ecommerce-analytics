SELECT
    customer_id,
    customer_name,
    email,
    city,
    signup_date,
    CURRENT_TIMESTAMP AS loaded_at
FROM {{ source('raw', 'customers') }}