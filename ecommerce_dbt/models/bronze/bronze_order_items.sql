
-- ============================================================
-- Model: bronze_order_items
-- Layer: Bronze
-- Grain: One row per source order item (order_item_id)
--
-- Purpose:
--   Standardize basic order-item fields while preserving the
--   source-level structure for Silver and Gold transformations.
--
-- Transformations:
--   1. Preserve source identifiers and transaction measures.
--   2. Replace missing discount and tax amounts with zero.
--   3. Replace missing returned quantity with zero.
--   4. Preserve source update and ingestion timestamps.
--   5. Add a model execution timestamp for audit visibility.
-- ============================================================

SELECT
    -- Source identifiers
    order_item_id,
    order_id,
    product_id,

    -- Quantity and unit price are preserved as recorded
    quantity,
    unit_price,

    -- Financial attributes
    COALESCE(discount_amount, 0.00) AS discount_amount,
    COALESCE(tax_amount, 0.00) AS tax_amount,
    line_total,

    -- Return information
    COALESCE(returned_quantity, 0) AS returned_quantity,

    -- Source audit timestamps
    updated_at,
    ingested_at,

    -- Model execution timestamp
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'order_items') }}
