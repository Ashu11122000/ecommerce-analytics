
-- ============================================================
-- Model: silver_order_items
-- Layer: Silver
-- Grain: One row per order_item_id
--
-- Purpose:
--   Validate source line totals, identify quantity anomalies,
--   and derive return indicators for downstream analytics.
--
-- Assumptions:
--   - Expected line total = quantity * unit price
--     - discount + tax.
--   - A variance greater than 0.01 is a mismatch.
--   - Returned quantity is not assumed to mean a completed
--     return; return workflow status is modeled separately.
-- ============================================================

WITH order_items_base AS (

    SELECT
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_amount,
        tax_amount,
        line_total,
        returned_quantity,
        updated_at,
        ingested_at,
        loaded_at,

        CASE
            WHEN quantity IS NOT NULL
            AND unit_price IS NOT NULL
            AND discount_amount IS NOT NULL
            AND tax_amount IS NOT NULL
            THEN (
                quantity * unit_price
            ) - discount_amount + tax_amount
            ELSE NULL
        END AS calculated_line_total

    FROM {{ ref('bronze_order_items') }}

),

order_items_validated AS (

    SELECT
        *,

        CASE
            WHEN line_total IS NULL
            OR calculated_line_total IS NULL
            THEN NULL
            ELSE ROUND(line_total - calculated_line_total, 2)
        END AS line_total_variance,

        CASE
            WHEN line_total IS NULL
            OR calculated_line_total IS NULL
            THEN NULL
            WHEN ABS(line_total - calculated_line_total) > 0.01
            THEN TRUE
            ELSE FALSE
        END AS is_line_total_mismatch,

        CASE
            WHEN quantity IS NULL THEN NULL
            WHEN quantity < 0 THEN TRUE
            ELSE FALSE
        END AS has_negative_quantity,

        CASE
            WHEN returned_quantity IS NULL THEN NULL
            WHEN returned_quantity > 0 THEN TRUE
            ELSE FALSE
        END AS has_return,

        CASE
            WHEN quantity IS NULL
            OR returned_quantity IS NULL
            THEN NULL
            WHEN returned_quantity > quantity
            THEN TRUE
            ELSE FALSE
        END AS has_excess_returned_quantity,

        CASE
            WHEN quantity > 0
            AND returned_quantity IS NOT NULL
            THEN ROUND(
                returned_quantity::NUMERIC / quantity,
                4
            )
            ELSE NULL
        END AS return_rate

    FROM order_items_base

)

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    tax_amount,
    line_total,
    returned_quantity,

    calculated_line_total,
    line_total_variance,
    is_line_total_mismatch,
    has_negative_quantity,
    has_return,
    has_excess_returned_quantity,
    return_rate,

    updated_at,
    ingested_at,
    loaded_at,

    {{ transformed_timestamp() }} AS transformed_at

FROM order_items_validated
