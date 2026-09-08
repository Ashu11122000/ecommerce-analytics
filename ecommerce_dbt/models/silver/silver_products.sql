SELECT
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    supplier_id,
    cost_price,
    selling_price,
    stock_quantity,
    reorder_level,
    product_status,
    launch_date,

    -- Calculate profit earned per unit
    selling_price - cost_price AS profit_amount,

    -- Calculate profit margin percentage
    CASE
        WHEN selling_price > 0
        THEN ROUND(
            ((selling_price - cost_price) / selling_price) * 100,
            2
        )
        ELSE NULL
    END AS profit_margin_pct,

    -- Classify current stock level
    CASE
        WHEN stock_quantity IS NULL THEN 'Unknown'
        WHEN stock_quantity = 0 THEN 'Out of Stock'
        WHEN stock_quantity <= reorder_level THEN 'Low Stock'
        ELSE 'In Stock'
    END AS stock_status,

    -- Classify products by selling price
    CASE
        WHEN selling_price IS NULL THEN 'Unknown'
        WHEN selling_price < 500 THEN 'Budget'
        WHEN selling_price < 2000 THEN 'Mid-Range'
        WHEN selling_price < 5000 THEN 'Premium'
        ELSE 'Luxury'
    END AS price_band,

    -- Identify products that are currently active
    CASE
        WHEN LOWER(product_status) IN ('active', 'available')
            THEN TRUE
        ELSE FALSE
    END AS is_active_product,

    updated_at,
    ingested_at,
    loaded_at,

    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_products') }}
