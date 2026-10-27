
-- ============================================================
-- Model: fact_order_items
-- Layer: Gold
-- Purpose:
--   Build an analytics-ready order-item fact table containing
--   sales measures, product and customer dimension keys,
--   return indicators, and data-quality information.
--
-- Grain:
--   One row per order item (order_item_id).
--
-- Materialization:
--   Incremental table using order_item_id as the unique key.
--
-- Important assumptions:
--   1. Each order item belongs to one order and one product.
--   2. Sales amounts are expressed in the order's currency.
--   3. Gross sales = quantity * unit_price.
--   4. Net sales = gross sales - discount + tax.
--   5. The incremental filter uses a lookback window to detect
--      changes to existing rows. The timestamp watermark logic
--      must be validated against the actual update patterns.
-- ============================================================

{{
    config(
        materialized='incremental',
        unique_key='order_item_id'
    )
}}

WITH order_items AS (

    -- Step 1: Read enriched order-item data from the Silver layer.
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

    -- Step 3: Join each order item to its parent order.
    -- The intended grain remains one row per order_item_id.
    SELECT
        oi.order_item_id,

        -- Dimension and transaction identifiers.
        oi.order_id,
        o.customer_id,
        oi.product_id,

        -- Date dimension key in YYYYMMDD format.
        -- NULL is preserved when the order date is missing.
        CASE
            WHEN o.order_date IS NOT NULL
            THEN TO_CHAR(o.order_date::DATE, 'YYYYMMDD')::INTEGER
            ELSE NULL
        END AS order_date_key,

        -- Order attributes useful for filtering and grouping.
        o.order_date,
        o.order_status,
        o.sales_channel,
        o.currency,

        -- Transaction quantity and pricing components.
        oi.quantity,
        oi.unit_price,
        oi.discount_amount,
        oi.tax_amount,

        -- Source and independently calculated line totals.
        oi.line_total,
        oi.calculated_line_total,

        -- Data-quality indicators inherited from Silver.
        oi.line_total_variance,
        oi.is_line_total_mismatch,
        oi.has_negative_quantity,

        -- Return information inherited from Silver.
        oi.returned_quantity,
        oi.has_return,
        oi.has_excess_returned_quantity,
        oi.return_rate,

        -- Gross sales before discounts and tax.
        -- Assumes unit_price is the historical price per unit.
        CASE
            WHEN oi.quantity IS NOT NULL
                AND oi.unit_price IS NOT NULL
            THEN ROUND(
                (oi.quantity * oi.unit_price)::NUMERIC,
                2
            )
            ELSE NULL
        END AS gross_sales_amount,

        -- Net sales including tax, after line-item discount.
        -- This is a transaction amount, not a tax-exclusive
        -- accounting revenue measure.
        CASE
            WHEN oi.quantity IS NOT NULL
                AND oi.unit_price IS NOT NULL
                AND oi.discount_amount IS NOT NULL
                AND oi.tax_amount IS NOT NULL
            THEN ROUND(
                (
                    oi.quantity * oi.unit_price
                    - oi.discount_amount
                    + oi.tax_amount
                )::NUMERIC,
                2
            )
            ELSE NULL
        END AS net_sales_amount,

        -- Source and ingestion lineage timestamps.
        oi.updated_at,
        oi.ingested_at,
        oi.loaded_at,
        oi.transformed_at

    FROM order_items AS oi

    INNER JOIN orders AS o
        ON oi.order_id = o.order_id

)

-- Step 4: Return the final Gold fact table.
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

    -- Timestamp generated by the modeled_timestamp macro.
    -- Actual behavior depends on the macro implementation.
    {{ modeled_timestamp() }} AS modeled_at

FROM fact_base

{% if is_incremental() %}

-- Step 5: Process recently ingested or updated source records.
-- The lookback window helps detect late-arriving changes.
-- Existing records are updated using the configured unique key.
WHERE
    ingested_at >= (
        SELECT COALESCE(
            MAX(ingested_at),
            '1900-01-01'::TIMESTAMP
        ) - INTERVAL '7 days'
        FROM {{ this }}
    )

    OR updated_at >= (
        SELECT COALESCE(
            MAX(updated_at),
            '1900-01-01'::TIMESTAMP
        ) - INTERVAL '7 days'
        FROM {{ this }}
    )

{% endif %}
