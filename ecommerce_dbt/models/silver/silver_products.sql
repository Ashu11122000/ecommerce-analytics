
-- ============================================================
-- Model: silver_products
-- Layer: Silver
-- Grain: One row per product (product_id)
--
-- Purpose:
--   Enrich product data from the Bronze layer with profitability
--   metrics, stock classifications, pricing bands, and product
--   activity indicators.
--
-- Transformations:
--   1. Calculate expected profit per unit.
--   2. Calculate profit margin as a percentage of selling price.
--   3. Classify inventory levels using the reorder threshold.
--   4. Assign products to fixed selling-price bands.
--   5. Identify products with recognized active statuses.
--   6. Preserve source lineage and add a transformation timestamp.
-- ============================================================

WITH products_base AS (

    -- Step 1: Select product attributes from the Bronze model.
    -- Preserve the product-level grain; do not join or aggregate.
    SELECT
        -- Product identifiers and descriptive attributes
        product_id,
        product_name,
        category,
        subcategory,
        brand,
        supplier_id,

        -- Source pricing and inventory attributes
        cost_price,
        selling_price,
        stock_quantity,
        reorder_level,

        -- Product lifecycle attributes
        product_status,
        launch_date,

        -- Source lineage
        updated_at,
        ingested_at,
        loaded_at

    FROM {{ ref('bronze_products') }}

),

products_enriched AS (

    -- Step 2: Calculate profitability and classify products.
    SELECT
        *,

        -- Expected profit per unit before other business costs.
        CASE
            WHEN selling_price IS NOT NULL
                 AND cost_price IS NOT NULL
            THEN ROUND(
                (selling_price - cost_price)::NUMERIC,
                2
            )
            ELSE NULL
        END AS profit_amount,

        -- Profit margin as a percentage of selling price.
        -- Explicit NUMERIC casting avoids integer division.
        -- NULL is returned for missing, zero, or negative prices.
        CASE
            WHEN selling_price > 0
                 AND cost_price IS NOT NULL
            THEN ROUND(
                (
                    (selling_price::NUMERIC - cost_price::NUMERIC)
                    / selling_price::NUMERIC
                ) * 100,
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
        -- These thresholds are reporting conventions.
        CASE
            WHEN selling_price IS NULL THEN 'Unknown'
            WHEN selling_price < 0 THEN 'Invalid Price'
            WHEN selling_price < 500 THEN 'Budget'
            WHEN selling_price < 2000 THEN 'Mid-Range'
            WHEN selling_price < 5000 THEN 'Premium'
            ELSE 'Luxury'
        END AS price_band,

        -- Identify products whose source status indicates availability.
        -- Active status does not guarantee available inventory.
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
    -- Product identifiers and descriptive attributes
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    supplier_id,

    -- Source pricing and inventory attributes
    cost_price,
    selling_price,
    stock_quantity,
    reorder_level,
    product_status,
    launch_date,

    -- Derived profitability metrics
    profit_amount,
    profit_margin_pct,

    -- Derived stock, price, and activity classifications
    stock_status,
    price_band,
    is_active_product,

    -- Source lineage
    updated_at,
    ingested_at,
    loaded_at,

    -- Transformation execution timestamp.
    -- In a view, this value may change whenever the view is queried.
    {{ transformed_timestamp() }} AS transformed_at

FROM products_enriched
