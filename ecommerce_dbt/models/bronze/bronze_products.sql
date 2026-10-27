
-- ============================================================
-- Model: bronze_products
-- Layer: Bronze
-- Grain: One row per source product (product_id)
--
-- Purpose:
--   Standardize basic product attributes while preserving
--   the source structure for downstream transformations.
--
-- Important:
--   - No joins or aggregation.
--   - Preserve source prices and inventory quantities.
--   - Convert blank optional text values to NULL.
--   - Do not silently correct invalid prices or stock values.
--   - Apply business rules and quality checks in Silver.
-- ============================================================

SELECT
    product_id,
    NULLIF(TRIM(product_name), '') AS product_name,
    NULLIF(INITCAP(TRIM(category)), '') AS category,
    NULLIF(INITCAP(TRIM(subcategory)), '') AS subcategory,
    NULLIF(INITCAP(TRIM(brand)), '') AS brand,
    supplier_id,
    cost_price,
    selling_price,
    stock_quantity,
    reorder_level,
    NULLIF(INITCAP(TRIM(product_status)), '') AS product_status,
    launch_date,
    updated_at,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'products') }}
