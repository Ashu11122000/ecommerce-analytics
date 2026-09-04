SELECT
    product_id,
    TRIM(product_name) AS product_name,
    TRIM(category) AS category,
    price,
    loaded_at
FROM {{ ref('bronze_products') }}
WHERE product_id IS NOT NULL
  AND price > 0