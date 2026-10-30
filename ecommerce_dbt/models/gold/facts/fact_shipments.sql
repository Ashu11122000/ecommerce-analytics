
-- ============================================================
-- Model: fact_shipments
-- Layer: Gold
-- Grain: One row per shipment (shipment_id)
--
-- Purpose:
--   Support shipment operations, delivery performance analysis,
--   delivery delay monitoring, and shipping-status reporting.
--
-- Source:
--   silver_shipments
--
-- Business definitions:
--   delivery_days:
--     Delivery duration in days, inherited from Silver.
--
--   is_delivered:
--     Delivery indicator inherited from Silver.
--
--   is_delivery_delayed:
--     Delivery delay indicator inherited from Silver.
--
--   delivery_speed:
--     Delivery-speed classification inherited from Silver.
-- ============================================================

WITH shipments_base AS (

    -- Step 1: Read standardized shipment records from Silver.
    SELECT
        shipment_id,
        order_id,
        shipping_method,
        shipment_status,
        shipment_status_group,
        shipped_at,
        delivered_at,
        delivery_city,
        delivery_state,
        delivery_days,
        is_delivered,
        delivery_speed,
        is_delivery_delayed,
        updated_at,
        ingested_at,
        loaded_at,
        transformed_at

    FROM {{ ref('silver_shipments') }}

),

shipments_prepared AS (

    -- Step 2: Create a date dimension key from the shipment date.
    -- Use shipped_at as the event date for shipment operations.
    SELECT
        *,

        -- Integer date key in YYYYMMDD format.
        -- Example: 20261027 represents October 27, 2026.
        -- Preserve NULL when shipped_at is unavailable.
        CASE
            WHEN shipped_at IS NOT NULL
                THEN TO_CHAR(
                    shipped_at::DATE,
                    'YYYYMMDD'
                )::INTEGER
            ELSE NULL
        END AS shipped_date_key

    FROM shipments_base

)

-- Step 3: Return the final Gold shipment fact table.
SELECT

    -- Shipment fact identifier.
    shipment_id,

    -- Order and date dimension keys.
    order_id,
    shipped_date_key,

    -- Shipping and delivery attributes.
    shipping_method,
    shipment_status,
    shipment_status_group,
    delivery_city,
    delivery_state,

    -- Shipment lifecycle timestamps.
    shipped_at,
    delivered_at,

    -- Delivery performance measures.
    delivery_days,
    is_delivered,
    delivery_speed,
    is_delivery_delayed,

    -- Source and transformation lineage.
    updated_at,
    ingested_at,
    loaded_at,
    transformed_at,

    -- Gold model execution timestamp.
    -- Behavior depends on the macro implementation and
    -- the model's materialization.
    {{ modeled_timestamp() }} AS modeled_at

FROM shipments_prepared
