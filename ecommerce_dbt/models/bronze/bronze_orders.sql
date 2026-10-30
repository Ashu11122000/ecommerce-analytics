
-- ============================================================
-- Model: bronze_orders
-- Layer: Bronze
-- Grain: One row per source order (order_id)
--
-- Purpose:
--   Standardize basic order attributes and normalize optional
--   text and monetary values for downstream transformations.
--
-- Transformations:
--   1. Preserve order and customer identifiers.
--   2. Normalize status, shipping method, and sales channel text.
--   3. Normalize currency codes to uppercase.
--   4. Replace NULL shipping, discount, and tax amounts with 0.
--   5. Preserve source update and ingestion timestamps.
--   6. Add a model execution timestamp.
-- ============================================================

SELECT
    -- Order identifiers and date
    order_id,
    customer_id,
    order_date,

    -- Order and fulfillment attributes
    NULLIF(INITCAP(TRIM(order_status)), '') AS order_status,
    NULLIF(INITCAP(TRIM(payment_status)), '') AS payment_status,
    NULLIF(INITCAP(TRIM(shipping_method)), '') AS shipping_method,

    -- Monetary attributes
    COALESCE(shipping_cost, 0.00) AS shipping_cost,
    COALESCE(discount_amount, 0.00) AS discount_amount,
    COALESCE(tax_amount, 0.00) AS tax_amount,
    total_amount,

    -- Sales and currency attributes
    NULLIF(INITCAP(TRIM(sales_channel)), '') AS sales_channel,
    UPPER(NULLIF(TRIM(currency), '')) AS currency,

    -- Source audit timestamps
    updated_at,
    ingested_at,

    -- Model execution timestamp
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'orders') }}
