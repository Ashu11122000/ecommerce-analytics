
-- ============================================================
-- Model: bronze_products
-- Layer: Bronze
-- Grain: One row per source product (product_id)
--
-- Purpose:
--   Standardize basic product attributes while preserving
--   the source structure for downstream Silver and Gold models.
--
-- Transformations:
--   1. Preserve product and supplier identifiers.
--   2. Trim product names and optional text attributes.
--   3. Normalize category, subcategory, brand, and status casing.
--   4. Preserve original prices and inventory quantities.
--   5. Retain source timestamps for data lineage.
--   6. Add a model execution timestamp.
-- ============================================================

SELECT
    -- Product identity
    product_id,
    NULLIF(TRIM(product_name), '') AS product_name,

    -- Product classification and descriptive attributes
    NULLIF(INITCAP(TRIM(category)), '') AS category,
    NULLIF(INITCAP(TRIM(subcategory)), '') AS subcategory,
    NULLIF(INITCAP(TRIM(brand)), '') AS brand,
    supplier_id,

    -- Preserve original financial and inventory values
    cost_price,
    selling_price,
    stock_quantity,
    reorder_level,

    -- Product status and lifecycle
    NULLIF(INITCAP(TRIM(product_status)), '') AS product_status,
    launch_date,

    -- Source audit timestamps
    updated_at,
    ingested_at,

    -- Model execution timestamp
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'products') }}
