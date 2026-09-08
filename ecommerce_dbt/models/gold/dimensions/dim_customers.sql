SELECT
    customer_id,
    customer_name,
    email,
    city,
    signup_date,

    ingested_at,
    loaded_at,
    transformed_at,

    {{ modeled_timestamp() }} AS modeled_at

FROM {{ ref('silver_customers') }}