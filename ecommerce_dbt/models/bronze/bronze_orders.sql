
-- ============================================================
-- Model: bronze_orders
-- Layer: Bronze
-- Grain: One row per source order (order_id)
--
-- Purpose:
--   Standardize basic order attributes and normalize missing
--   optional text and monetary values.
--
-- Important:
--   - Preserve one row per order.
--   - Do not aggregate or join other tables at this layer.
--   - Monetary defaults assume NULL means no amount recorded.
--   - Preserve source timestamps for lineage.
--   - Validate order totals and status mappings downstream.
-- ============================================================

SELECT
    order_id,
    customer_id,
    order_date,
    NULLIF(INITCAP(TRIM(order_status)), '') AS order_status,
    NULLIF(INITCAP(TRIM(payment_status)), '') AS payment_status,
    NULLIF(INITCAP(TRIM(shipping_method)), '') AS shipping_method,
    COALESCE(shipping_cost, 0.00) AS shipping_cost,
    COALESCE(discount_amount, 0.00) AS discount_amount,
    COALESCE(tax_amount, 0.00) AS tax_amount,
    total_amount,
    NULLIF(INITCAP(TRIM(sales_channel)), '') AS sales_channel,
    UPPER(NULLIF(TRIM(currency), '')) AS currency,
    updated_at,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'orders') }}
