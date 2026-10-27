
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
--
-- Important assumptions:
--   - No joins or aggregations; source grain is preserved.
--   - NULL discount means no discount was recorded.
--   - NULL tax means no tax was recorded.
--   - NULL returned_quantity means no returned quantity
--     was recorded.
--   - These assumptions must be validated against the
--     source generator and business rules.
--   - Negative quantities and financial anomalies are not
--     silently corrected; they must be flagged downstream.
--   - loaded_at is query execution time because this model
--     is configured as a view; it is not a persisted load time.
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
