
-- ============================================================
-- Model: fact_order_items
-- Layer: Gold
-- Grain: One row per order item (order_item_id)
--
-- Purpose:
--   Provide an analytics-ready fact table for sales, product,
--   customer, returns, and order-item data-quality analysis.
--
-- Materialization:
--   Incremental table, using order_item_id as the unique key.
--
-- Financial definitions:
--   gross_sales_amount = quantity * unit_price
--   net_sales_amount   = gross sales - discount + tax
--
-- Sales eligibility:
--   An item is eligible for sales reporting when:
--     1. Quantity is positive.
--     2. Unit price, discount, and tax are non-null.
--     3. Unit price is non-negative.
--     4. Discount and tax are non-negative.
--     5. The recorded and calculated line totals reconcile
--        within 0.01.
--
-- Important assumptions:
--   - Each order item belongs to one order and one product.
--   - Amounts are expressed in the order's currency.
--   - Net sales includes tax and is not tax-exclusive revenue.
--   - Source values are preserved for auditing.
--   - Ineligible items receive NULL sales measures rather than
--     being deleted or silently corrected.
--   - Return attributes and source quality flags are preserved.
--   - Incremental processing uses a seven-day timestamp lookback.
--   - The LEFT JOIN preserves items if the parent order is missing.
-- ============================================================

{{
    config(
        materialized='incremental',
        unique_key='order_item_id'
    )
}}

WITH order_items AS (

    -- Step 1: Read enriched order-item records from Silver.
    SELECT
        oi.order_item_id,
        oi.order_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.discount_amount,
        oi.tax_amount,
        oi.line_total,
        oi.calculated_line_total,
        oi.line_total_variance,
        oi.is_line_total_mismatch,
        oi.has_negative_quantity,
        oi.returned_quantity,
        oi.has_return,
        oi.has_excess_returned_quantity,
        oi.return_rate,
        oi.updated_at,
        oi.ingested_at,
        oi.loaded_at,
        oi.transformed_at

    FROM {{ ref('silver_order_items') }} AS oi

),

orders AS (

    -- Step 2: Read the order attributes needed for analysis.
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        o.order_status,
        o.sales_channel,
        o.currency

    FROM {{ ref('silver_orders') }} AS o

),

fact_base AS (

    -- Step 3: Enrich each item with its parent order.
    -- LEFT JOIN preserves items with missing parent orders.
    SELECT
        oi.order_item_id,

        -- Transaction identifiers and dimension keys.
        oi.order_id,
        o.customer_id,
        oi.product_id,

        -- Date key compatible with dim_date.date_key.
        CASE
            WHEN o.order_date IS NOT NULL
                THEN TO_CHAR(
                    o.order_date::DATE,
                    'YYYYMMDD'
                )::INTEGER
            ELSE NULL
        END AS order_date_key,

        -- Order-level descriptive attributes.
        o.order_date,
        o.order_status,
        o.sales_channel,
        o.currency,

        -- Quantity and original pricing components.
        oi.quantity,
        oi.unit_price,
        oi.discount_amount,
        oi.tax_amount,

        -- Preserve source and calculated line totals.
        oi.line_total,
        oi.calculated_line_total,
        oi.line_total_variance,

        -- Source data-quality indicators.
        oi.is_line_total_mismatch,
        oi.has_negative_quantity,

        -- Return attributes inherited from Silver.
        oi.returned_quantity,
        oi.has_return,
        oi.has_excess_returned_quantity,
        oi.return_rate,

        -- Step 4: Determine eligibility for sales reporting.
        -- Original source values are not modified.
        CASE
            WHEN oi.quantity > 0
             AND oi.unit_price IS NOT NULL
             AND oi.unit_price >= 0
             AND oi.discount_amount IS NOT NULL
             AND oi.discount_amount >= 0
             AND oi.tax_amount IS NOT NULL
             AND oi.tax_amount >= 0
             AND oi.line_total IS NOT NULL
             AND oi.calculated_line_total IS NOT NULL
             AND ABS(
                 oi.line_total::NUMERIC
                 - oi.calculated_line_total::NUMERIC
             ) <= 0.01
            THEN TRUE
            ELSE FALSE
        END AS is_valid_for_sales,

        -- Gross sales before discounts and tax.
        -- Ineligible records remain present, but do not
        -- contribute a sales measure.
        CASE
            WHEN oi.quantity > 0
             AND oi.unit_price IS NOT NULL
             AND oi.unit_price >= 0
             AND oi.discount_amount IS NOT NULL
             AND oi.discount_amount >= 0
             AND oi.tax_amount IS NOT NULL
             AND oi.tax_amount >= 0
             AND oi.line_total IS NOT NULL
             AND oi.calculated_line_total IS NOT NULL
             AND ABS(
                 oi.line_total::NUMERIC
                 - oi.calculated_line_total::NUMERIC
             ) <= 0.01
            THEN ROUND(
                oi.quantity::NUMERIC
                * oi.unit_price::NUMERIC,
                2
            )
            ELSE NULL
        END AS gross_sales_amount,

        -- Net sales after discount and including tax.
        CASE
            WHEN oi.quantity > 0
             AND oi.unit_price IS NOT NULL
             AND oi.unit_price >= 0
             AND oi.discount_amount IS NOT NULL
             AND oi.discount_amount >= 0
             AND oi.tax_amount IS NOT NULL
             AND oi.tax_amount >= 0
             AND oi.line_total IS NOT NULL
             AND oi.calculated_line_total IS NOT NULL
             AND ABS(
                 oi.line_total::NUMERIC
                 - oi.calculated_line_total::NUMERIC
             ) <= 0.01
            THEN ROUND(
                (
                    oi.quantity::NUMERIC
                    * oi.unit_price::NUMERIC
                    - oi.discount_amount::NUMERIC
                    + oi.tax_amount::NUMERIC
                ),
                2
            )
            ELSE NULL
        END AS net_sales_amount,

        -- Source and transformation lineage.
        oi.updated_at,
        oi.ingested_at,
        oi.loaded_at,
        oi.transformed_at

    FROM order_items AS oi

    LEFT JOIN orders AS o
        ON oi.order_id = o.order_id

)

-- Step 5: Return the final Gold order-item fact.
SELECT
    order_item_id,
    order_id,
    customer_id,
    product_id,
    order_date_key,

    order_date,
    order_status,
    sales_channel,
    currency,

    quantity,
    unit_price,
    discount_amount,
    tax_amount,

    line_total,
    calculated_line_total,
    line_total_variance,

    is_line_total_mismatch,
    has_negative_quantity,

    returned_quantity,
    has_return,
    has_excess_returned_quantity,
    return_rate,

    is_valid_for_sales,
    gross_sales_amount,
    net_sales_amount,

    updated_at,
    ingested_at,
    loaded_at,
    transformed_at,

    {{ modeled_timestamp() }} AS modeled_at

FROM fact_base

{% if is_incremental() %}

-- Step 6: Reprocess recently ingested or updated records.
-- dbt merges matching rows using order_item_id as unique_key.
WHERE
    ingested_at >= (
        SELECT
            COALESCE(
                MAX(ingested_at),
                '1900-01-01'::TIMESTAMP
            ) - INTERVAL '7 days'
        FROM {{ this }}
    )

    OR updated_at >= (
        SELECT
            COALESCE(
                MAX(updated_at),
                '1900-01-01'::TIMESTAMP
            ) - INTERVAL '7 days'
        FROM {{ this }}
    )

{% endif %}
