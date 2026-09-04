SELECT
    product_id,
    TRIM(product_name) AS product_name,
    TRIM(category) AS category,
    price,
    ingested_at,
    loaded_at,
    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_products') }}