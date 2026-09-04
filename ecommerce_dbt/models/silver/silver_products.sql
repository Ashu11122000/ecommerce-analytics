SELECT
    product_id,
    TRIM(product_name) AS product_name,
    TRIM(category) AS category,
    price,
    ingested_at,
    loaded_at,
    CURRENT_TIMESTAMP AS transformed_at

FROM {{ ref('bronze_products') }}