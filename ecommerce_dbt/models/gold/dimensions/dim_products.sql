SELECT
    product_id,
    product_name,
    category,
    price,

    ingested_at,
    loaded_at,
    transformed_at,

    CURRENT_TIMESTAMP AS modeled_at

FROM {{ ref('silver_products') }}