
-- ============================================================
-- Model: bronze_order_items
-- Layer: Bronze
-- Grain: One row per source order item (order_item_id)
--
-- Purpose:
--   Standardize basic order-item fields and preserve source
--   values for downstream Silver and Gold transformations.
--
-- Important:
--   - No joins or aggregation: preserves the source grain.
--   - Missing discount and tax values default to zero.
--   - Missing returned_quantity defaults to zero.
--   - Negative quantities and monetary anomalies are not
--     silently corrected; validate them downstream.
-- ============================================================

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    COALESCE(discount_amount, 0.00) AS discount_amount,
    COALESCE(tax_amount, 0.00) AS tax_amount,
    line_total,
    COALESCE(returned_quantity, 0) AS returned_quantity,
    updated_at,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'order_items') }}
