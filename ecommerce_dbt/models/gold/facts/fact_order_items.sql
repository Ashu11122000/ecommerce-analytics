
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
-- Important assumptions:
--   - Each order item belongs to one order and one product.
--   - Amounts are expressed in the order's currency.
--   - Net sales includes tax and is not tax-exclusive revenue.
--   - Return quantities and rates are inherited from Silver.
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
    -- LEFT JOIN preserves the item if its order is missing.
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

        -- Quantity and pricing components.
        oi.quantity,
        oi.unit_price,
        oi.discount_amount,
        oi.tax_amount,

        -- Source and calculated line totals.
        oi.line_total,
        oi.calculated_line_total,

        -- Data-quality indicators inherited from Silver.
        oi.line_total_variance,
        oi.is_line_total_mismatch,
        oi.has_negative_quantity,

        -- Return attributes inherited from Silver.
        oi.returned_quantity,
        oi.has_return,
        oi.has_excess_returned_quantity,
        oi.return_rate,

        -- Gross sales before discounts and tax.
        CASE
            WHEN oi.quantity IS NOT NULL
             AND oi.unit_price IS NOT NULL
            THEN ROUND(
                (
                    oi.quantity::NUMERIC
                    * oi.unit_price::NUMERIC
                ),
                2
            )
            ELSE NULL
        END AS gross_sales_amount,

        -- Net transaction amount after discount and including tax.
        CASE
            WHEN oi.quantity IS NOT NULL
             AND oi.unit_price IS NOT NULL
             AND oi.discount_amount IS NOT NULL
             AND oi.tax_amount IS NOT NULL
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

-- Step 4: Return the final Gold order-item fact.
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

    gross_sales_amount,
    net_sales_amount,

    updated_at,
    ingested_at,
    loaded_at,
    transformed_at,

    {{ modeled_timestamp() }} AS modeled_at

FROM fact_base

{% if is_incremental() %}

-- Step 5: Reprocess recently ingested or updated records.
-- The lookback allows recent source changes to be picked up.
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
