
-- ============================================================
-- Model: bronze_shipments
-- Layer: Bronze
-- Grain: One row per source shipment (shipment_id)
--
-- Purpose:
--   Standardize shipment attributes while preserving source
--   values for downstream operational analytics.
--
-- Transformations:
--   1. Preserve shipment and order identifiers.
--   2. Standardize shipping method and shipment status casing.
--   3. Convert blank optional text values to NULL.
--   4. Preserve shipment and delivery timestamps.
--   5. Retain source timestamps for data lineage.
--   6. Add a model execution timestamp.
--
-- Important assumptions:
--   - An order may have multiple shipment records.
--   - No joins or aggregations are performed in Bronze.
--   - Source timestamps are preserved without modification.
--   - Shipment status rules and delivery-duration calculations
--     are handled downstream in Silver/Gold.
--   - loaded_at is query execution time because this model
--     is configured as a view; it is not a persisted load time.
-- ============================================================

SELECT
    -- Shipment and order identifiers
    shipment_id,
    order_id,

    -- Standardized shipping attributes
    NULLIF(INITCAP(TRIM(shipping_method)), '') AS shipping_method,
    NULLIF(INITCAP(TRIM(shipment_status)), '') AS shipment_status,

    -- Preserve original shipment and delivery timestamps
    shipped_at,
    delivered_at,

    -- Standardized delivery location
    NULLIF(INITCAP(TRIM(delivery_city)), '') AS delivery_city,
    NULLIF(INITCAP(TRIM(delivery_state)), '') AS delivery_state,

    -- Source audit timestamps
    updated_at,
    ingested_at,

    -- Model execution timestamp
    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'shipments') }}
