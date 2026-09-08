SELECT
    product_id,
    product_name,
    category,
    price,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at
FROM {{ source('raw', 'products') }}