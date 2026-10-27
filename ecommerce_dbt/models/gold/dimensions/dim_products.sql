
-- ============================================================
-- Model: dim_products
-- Layer: Gold
-- Purpose:
--   Create a business-friendly product dimension for analytics.
--   Provide product attributes, profitability classifications,
--   pricing bands, and inventory information for dashboards.
--
-- Grain:
--   One row per product (product_id).
--
-- Source:
--   silver_products
--
-- Important assumptions:
--   1. Profit amount represents expected profit per unit,
--      not realized profit from completed sales.
--   2. Profit margin is calculated as a percentage of selling price.
--   3. Margin bands use fixed percentage thresholds.
--   4. Stock status is inherited from the Silver model.
-- ============================================================

WITH product_dimension AS (

    -- Step 1: Select product attributes and calculated metrics
    -- from the Silver layer.
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

    -- Step 2: Classify products according to their expected
    -- unit profit margin.
    SELECT
        *,

        -- Group profit margins into business-friendly bands.
        -- A margin below 10% is classified as Low Margin.
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

    -- Inventory attributes for stock monitoring.
    stock_quantity,
    reorder_level,
    stock_status,

    -- Product pricing classification.
    price_band,

    -- Product availability and lifecycle attributes.
    product_status,
    is_active_product,
    launch_date,

    -- Technical lineage timestamps.
    ingested_at,
    loaded_at,
    transformed_at,

    -- Record when this Gold model's transformation executes.
    -- Behavior depends on the modeled_timestamp() macro.
    {{ modeled_timestamp() }} AS modeled_at

FROM products_classified
