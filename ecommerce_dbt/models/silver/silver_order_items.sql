
-- ============================================================
-- Model: silver_order_items
-- Layer: Silver
-- Grain: One row per order_item_id
--
-- Purpose:
--   Validate source line totals, identify quantity anomalies,
--   and derive return indicators for downstream analytics.
--
-- Transformations:
--   1. Calculate an expected line total.
--   2. Calculate the variance between recorded and expected totals.
--   3. Flag line-total mismatches using a 0.01 tolerance.
--   4. Identify negative ordered quantities.
--   5. Identify order items with recorded returned quantities.
--   6. Flag returned quantities exceeding ordered quantities.
--   7. Calculate a return rate when the denominator is valid.
-- ============================================================

WITH order_items_base AS (

    SELECT
        -- Order-item identifiers
        order_item_id,
        order_id,
        product_id,

        -- Original quantity and financial values
        quantity,
        unit_price,
        discount_amount,
        tax_amount,
        line_total,
        returned_quantity,

        -- Source lineage
        updated_at,
        ingested_at,
        loaded_at,

        -- Calculate expected line total using the stated assumption.
        -- NULL inputs produce an unknown calculated total.
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

        -- Difference between recorded and calculated totals.
        -- Positive variance means recorded total is higher.
        -- Negative variance means recorded total is lower.
        CASE
            WHEN line_total IS NULL
                 OR calculated_line_total IS NULL
            THEN NULL
            ELSE ROUND(line_total - calculated_line_total, 2)
        END AS line_total_variance,

        -- Flag mismatches beyond the accepted tolerance.
        CASE
            WHEN line_total IS NULL
                 OR calculated_line_total IS NULL
            THEN NULL
            WHEN ABS(line_total - calculated_line_total) > 0.01
            THEN TRUE
            ELSE FALSE
        END AS is_line_total_mismatch,

        -- Identify negative ordered quantities.
        CASE
            WHEN quantity IS NULL THEN NULL
            WHEN quantity < 0 THEN TRUE
            ELSE FALSE
        END AS has_negative_quantity,

        -- Indicates a positive recorded returned quantity.
        -- This does not establish whether the return was completed.
        CASE
            WHEN returned_quantity IS NULL THEN NULL
            WHEN returned_quantity > 0 THEN TRUE
            ELSE FALSE
        END AS has_return,

        -- Flag returned quantity greater than ordered quantity.
        CASE
            WHEN quantity IS NULL
                 OR returned_quantity IS NULL
            THEN NULL
            WHEN returned_quantity > quantity
            THEN TRUE
            ELSE FALSE
        END AS has_excess_returned_quantity,

        -- Return rate = returned quantity / ordered quantity.
        -- NULL is used when the denominator is not positive
        -- or returned quantity is unavailable.
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
    -- Original order-item attributes
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    tax_amount,
    line_total,
    returned_quantity,

    -- Derived financial validation fields
    calculated_line_total,
    line_total_variance,
    is_line_total_mismatch,

    -- Derived quantity and return indicators
    has_negative_quantity,
    has_return,
    has_excess_returned_quantity,
    return_rate,

    -- Source lineage
    updated_at,
    ingested_at,
    loaded_at,

    -- Transformation audit timestamp
    {{ transformed_timestamp() }} AS transformed_at

FROM order_items_validated
