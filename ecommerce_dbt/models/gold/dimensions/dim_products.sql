
-- ============================================================
-- Model: dim_products
-- Layer: Gold
-- Grain: One row per product (product_id)
--
-- Purpose:
--   Provide a business-friendly product dimension for analytics.
--   Support product performance, pricing, profitability, and
--   inventory analysis in dashboards and the semantic layer.
--
-- Source:
--   silver_products
--
-- Business definitions:
--   profit_amount:
--     Expected profit per unit = selling_price - cost_price.
--     This is not realized profit from completed sales.
--
--   profit_margin_pct:
--     Expected unit profit as a percentage of selling price.
--     The calculation and invalid-price handling are inherited
--     from silver_products.
--
--   profit_margin_band:
--     Unknown       : Margin is unavailable.
--     Low Margin    : Margin < 10%.
--     Medium Margin : Margin >= 10% and < 30%.
--     High Margin   : Margin >= 30% and < 50%.
--     Very High Margin: Margin >= 50%.
-- ============================================================

WITH product_dimension AS (

    -- Step 1: Select descriptive product attributes, pricing,
    -- profitability, inventory, and lineage from the Silver layer.
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
        stock_quantity,
        reorder_level,
        stock_status,
        price_band,
        product_status,
        is_active_product,
        launch_date,
        ingested_at,
        loaded_at,
        transformed_at

    FROM {{ ref('silver_products') }}

),

products_classified AS (

    -- Step 2: Assign a business-friendly profit margin band.
    SELECT
        *,

        CASE
            WHEN profit_margin_pct IS NULL
                THEN 'Unknown'

            WHEN profit_margin_pct < 10
                THEN 'Low Margin'

            WHEN profit_margin_pct < 30
                THEN 'Medium Margin'

            WHEN profit_margin_pct < 50
                THEN 'High Margin'

            ELSE 'Very High Margin'
        END AS profit_margin_band

    FROM product_dimension

)

-- Step 3: Return the final Gold product dimension.
SELECT

    -- Product identifiers and descriptive attributes.
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    supplier_id,

    -- Unit-level pricing and expected profitability.
    cost_price,
    selling_price,
    profit_amount,
    profit_margin_pct,
    profit_margin_band,

    -- Inventory monitoring attributes.
    stock_quantity,
    reorder_level,
    stock_status,

    -- Pricing classification inherited from Silver.
    price_band,

    -- Product status and lifecycle attributes.
    product_status,
    is_active_product,
    launch_date,

    -- Technical lineage timestamps.
    ingested_at,
    loaded_at,
    transformed_at,

    -- Gold model execution timestamp.
    -- Exact behavior depends on the macro implementation
    -- and the model's materialization.
    {{ modeled_timestamp() }} AS modeled_at

FROM products_classified
