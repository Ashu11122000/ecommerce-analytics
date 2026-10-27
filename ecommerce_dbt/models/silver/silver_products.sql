
-- ============================================================
-- Model: silver_products
-- Layer: Silver
-- Purpose:
--   Enrich product data from the Bronze layer with profitability
--   metrics, stock classifications, pricing bands, and product
--   activity indicators.
--
-- Grain:
--   One row per product (product_id).
--
-- Important assumptions:
--   1. Selling price and cost price use the same currency and unit.
--   2. Profit amount is selling price minus cost price per unit.
--   3. Profit margin is calculated as a percentage of selling price.
--   4. Stock status is determined using stock_quantity and reorder_level.
--   5. Price bands use fixed thresholds for reporting purposes.
-- ============================================================

WITH products_base AS (

    -- Step 1: Select product attributes from the Bronze model.
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
        updated_at,
        ingested_at,
        loaded_at

    FROM {{ ref('bronze_products') }}

),

products_enriched AS (

    -- Step 2: Calculate profitability and classify products.
    SELECT
        *,

        -- Calculate expected profit per unit.
        -- This is a theoretical amount before other business costs.
        CASE
            WHEN selling_price IS NOT NULL
                AND cost_price IS NOT NULL
            THEN ROUND((selling_price - cost_price)::NUMERIC, 2)
            ELSE NULL
        END AS profit_amount,

        -- Calculate profit margin as a percentage of selling price.
        -- Return NULL when selling price is missing or zero/negative.
        CASE
            WHEN selling_price > 0
                AND cost_price IS NOT NULL
            THEN ROUND(
                (
                    (selling_price - cost_price)
                    / selling_price
                )::NUMERIC * 100,
                2
            )
            ELSE NULL
        END AS profit_margin_pct,

        -- Classify inventory using the configured reorder threshold.
        -- A quantity equal to the reorder level is considered low stock.
        CASE
            WHEN stock_quantity IS NULL THEN 'Unknown'
            WHEN stock_quantity < 0 THEN 'Invalid Stock'
            WHEN stock_quantity = 0 THEN 'Out of Stock'
            WHEN reorder_level IS NULL THEN 'Unknown'
            WHEN stock_quantity <= reorder_level THEN 'Low Stock'
            ELSE 'In Stock'
        END AS stock_status,

        -- Group products into fixed selling-price bands.
        -- These thresholds are reporting conventions, not universal
        -- definitions of budget, premium, or luxury products.
        CASE
            WHEN selling_price IS NULL THEN 'Unknown'
            WHEN selling_price < 0 THEN 'Invalid Price'
            WHEN selling_price < 500 THEN 'Budget'
            WHEN selling_price < 2000 THEN 'Mid-Range'
            WHEN selling_price < 5000 THEN 'Premium'
            ELSE 'Luxury'
        END AS price_band,

        -- Identify products whose source status indicates availability.
        -- This does not guarantee that the product is currently in stock.
        CASE
            WHEN LOWER(TRIM(product_status)) IN (
                'active',
                'available'
            )
                THEN TRUE

            WHEN product_status IS NULL
                OR TRIM(product_status) = ''
                THEN NULL

            ELSE FALSE
        END AS is_active_product

    FROM products_base

)

-- Step 3: Return the final enriched Silver product model.
SELECT
    -- Product identifiers and descriptive attributes.
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    supplier_id,

    -- Source pricing and inventory attributes.
    cost_price,
    selling_price,
    stock_quantity,
    reorder_level,
    product_status,
    launch_date,

    -- Derived profitability metrics.
    profit_amount,
    profit_margin_pct,

    -- Derived stock, price, and activity classifications.
    stock_status,
    price_band,
    is_active_product,

    -- Source and ingestion audit timestamps.
    updated_at,
    ingested_at,
    loaded_at,

    -- Record when the transformation query executes.
    -- In a view, this value may change whenever the view is queried.
    {{ transformed_timestamp() }} AS transformed_at

FROM products_enriched
