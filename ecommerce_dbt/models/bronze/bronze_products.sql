SELECT
    product_id,
    TRIM(product_name) AS product_name,
    INITCAP(TRIM(category)) AS category,
    INITCAP(TRIM(subcategory)) AS subcategory,
    INITCAP(TRIM(brand)) AS brand,
    supplier_id,
    cost_price,
    selling_price,
    stock_quantity,
    reorder_level,
    INITCAP(TRIM(product_status)) AS product_status,
    launch_date,
    updated_at,
    ingested_at,
    
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'products') }}