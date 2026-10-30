
-- ============================================================
-- Model: silver_shipments
-- Layer: Silver
-- Grain: One row per shipment (shipment_id)
--
-- Purpose:
--   Enrich shipment data from the Bronze layer with delivery
--   duration metrics, standardized shipment statuses, delivery
--   speed classifications, and delay indicators.
--
-- Transformations:
--   1. Calculate elapsed delivery duration in fractional days.
--   2. Identify shipments with a recorded delivery timestamp.
--   3. Standardize shipment statuses into reporting categories.
--   4. Classify delivery speed using elapsed duration.
--   5. Flag deliveries taking more than five days.
--   6. Preserve source lineage and add a transformation timestamp.
-- ============================================================

WITH shipments_base AS (

    -- Step 1: Select shipment attributes from the Bronze model.
    -- Preserve the shipment-level grain without joins or aggregation.
    SELECT
        -- Shipment and order identifiers
        shipment_id,
        order_id,

        -- Source shipment attributes
        shipping_method,
        shipment_status,
        shipped_at,
        delivered_at,
        delivery_city,
        delivery_state,

        -- Source lineage
        updated_at,
        ingested_at,
        loaded_at

    FROM {{ ref('bronze_shipments') }}

),

shipments_enriched AS (

    -- Step 2: Calculate delivery metrics and classify shipments.
    SELECT
        *,

        -- Calculate elapsed delivery duration in fractional days.
        -- Negative values are retained here for anomaly detection.
        CASE
            WHEN shipped_at IS NOT NULL
                 AND delivered_at IS NOT NULL
            THEN ROUND(
                (
                    EXTRACT(EPOCH FROM (delivered_at - shipped_at))
                    / 86400.0
                )::NUMERIC,
                2
            )
            ELSE NULL
        END AS delivery_days,

        -- A recorded delivery timestamp indicates delivery
        -- according to this model's definition.
        CASE
            WHEN delivered_at IS NOT NULL THEN TRUE
            ELSE FALSE
        END AS is_delivered,

        -- Standardize shipment statuses for reporting.
        -- Comparisons ignore surrounding spaces and letter case.
        CASE
            WHEN LOWER(TRIM(shipment_status)) IN (
                'delivered',
                'completed'
            )
                THEN 'Delivered'

            WHEN LOWER(TRIM(shipment_status)) IN (
                'shipped',
                'in transit',
                'in_transit',
                'out for delivery'
            )
                THEN 'In Transit'

            WHEN LOWER(TRIM(shipment_status)) IN (
                'pending',
                'processing'
            )
                THEN 'Pending'

            WHEN LOWER(TRIM(shipment_status)) IN (
                'cancelled',
                'canceled'
            )
                THEN 'Cancelled'

            -- Distinguish missing statuses from unrecognized values.
            WHEN shipment_status IS NULL
                 OR TRIM(shipment_status) = ''
                THEN 'Unknown'

            ELSE 'Other'
        END AS shipment_status_group,

        -- Classify delivery speed using elapsed duration.
        -- Negative durations are invalid and are classified separately.
        CASE
            WHEN shipped_at IS NULL
                 OR delivered_at IS NULL
                THEN 'Unknown'

            WHEN delivered_at < shipped_at
                THEN 'Invalid'

            WHEN delivered_at - shipped_at <= INTERVAL '2 days'
                THEN 'Fast'

            WHEN delivered_at - shipped_at <= INTERVAL '5 days'
                THEN 'Standard'

            ELSE 'Slow'
        END AS delivery_speed,

        -- Flag completed deliveries taking more than five elapsed days.
        -- Missing or reversed timestamps do not establish a valid delay.
        CASE
            WHEN shipped_at IS NULL
                 OR delivered_at IS NULL
                THEN NULL

            WHEN delivered_at < shipped_at
                THEN NULL

            WHEN delivered_at - shipped_at > INTERVAL '5 days'
                THEN TRUE

            ELSE FALSE
        END AS is_delivery_delayed

    FROM shipments_base

)

-- Step 3: Return the final enriched Silver shipment model.
SELECT
    -- Shipment identifiers and source attributes
    shipment_id,
    order_id,
    shipping_method,
    shipment_status,
    shipped_at,
    delivered_at,
    delivery_city,
    delivery_state,

    -- Derived delivery duration and delivery indicator
    delivery_days,
    is_delivered,

    -- Standardized status and delivery performance categories
    shipment_status_group,
    delivery_speed,
    is_delivery_delayed,

    -- Source lineage
    updated_at,
    ingested_at,
    loaded_at,

    -- Transformation execution timestamp.
    -- For a view, this value may change whenever the view is queried.
    {{ transformed_timestamp() }} AS transformed_at

FROM shipments_enriched
