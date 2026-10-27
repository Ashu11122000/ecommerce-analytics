
-- ============================================================
-- Model: bronze_shipments
-- Layer: Bronze
-- Grain: One row per source shipment (shipment_id)
--
-- Purpose:
--   Standardize shipment attributes while preserving source
--   values for downstream operational analytics.
--
-- Important:
--   - An order may have multiple shipment records.
--   - Preserve shipment and delivery timestamps.
--   - Convert blank optional text values to NULL.
--   - Validate shipment statuses and delivery durations
--     in downstream Silver models.
-- ============================================================

SELECT
    shipment_id,
    order_id,
    NULLIF(INITCAP(TRIM(shipping_method)), '') AS shipping_method,
    NULLIF(INITCAP(TRIM(shipment_status)), '') AS shipment_status,
    shipped_at,
    delivered_at,
    NULLIF(INITCAP(TRIM(delivery_city)), '') AS delivery_city,
    NULLIF(INITCAP(TRIM(delivery_state)), '') AS delivery_state,
    updated_at,
    ingested_at,
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'shipments') }}
