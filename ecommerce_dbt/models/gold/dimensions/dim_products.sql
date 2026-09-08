SELECT
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    supplier_id,
    cost_price,
    selling_price,
    profit_amount,
    profit_margin_pct,

    -- Final product profitability classification
    CASE
        WHEN profit_margin_pct IS NULL THEN 'Unknown'
        WHEN profit_margin_pct < 10 THEN 'Low Margin'
        WHEN profit_margin_pct < 30 THEN 'Medium Margin'
        WHEN profit_margin_pct < 50 THEN 'High Margin'
        ELSE 'Very High Margin'
    END AS profit_margin_band,

    stock_quantity,
    reorder_level,
    stock_status,

    price_band,

    product_status,
    is_active_product,

    launch_date,

    -- Technical lineage timestamps
    ingested_at,
    loaded_at,
    transformed_at,

    {{ modeled_timestamp() }} AS modeled_at

FROM {{ ref('silver_products') }}
