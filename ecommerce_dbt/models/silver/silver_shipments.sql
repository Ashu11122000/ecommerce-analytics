
-- ============================================================
-- Model: silver_shipments
-- Layer: Silver
-- Purpose:
--   Enrich shipment data from the Bronze layer with delivery
--   duration metrics, standardized shipment statuses, delivery
--   speed classifications, and delay indicators.
--
-- Grain:
--   One row per shipment (shipment_id).
--
-- Important assumptions:
--   1. Delivery duration is measured in elapsed calendar days.
--   2. A non-null delivered_at timestamp indicates delivery.
--   3. Delivery within 2 days is classified as Fast.
--   4. Delivery within 5 days is classified as Standard.
--   5. Delivery taking more than 5 days is classified as Slow
--      and flagged as delayed.
-- ============================================================

WITH shipments_base AS (

    -- Step 1: Select shipment attributes from the Bronze model.
    SELECT
        shipment_id,
        order_id,
        shipping_method,
        shipment_status,
        shipped_at,
        delivered_at,
        delivery_city,
        delivery_state,
        updated_at,
        ingested_at,
        loaded_at

    FROM {{ ref('bronze_shipments') }}

),

shipments_enriched AS (

    -- Step 2: Calculate delivery metrics and classify shipments.
    SELECT
        *,

        -- Calculate the total elapsed duration in days.
        -- Casting the interval to a numeric number of seconds
        -- and dividing by 86,400 preserves fractional days.
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

        -- Identify shipments with a recorded delivery timestamp.
        -- This uses the timestamp rather than shipment_status.
        CASE
            WHEN delivered_at IS NOT NULL THEN TRUE
            ELSE FALSE
        END AS is_delivered,

        -- Standardize shipment statuses for reporting.
        -- Trim spaces and ignore differences in letter case.
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

            -- Keep missing statuses distinct from other values.
            WHEN shipment_status IS NULL
                OR TRIM(shipment_status) = ''
                THEN 'Unknown'

            ELSE 'Other'
        END AS shipment_status_group,

        -- Classify delivery speed using elapsed duration.
        -- Negative durations are invalid and classified separately.
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

        -- Flag completed deliveries taking more than five days.
        -- Missing timestamps do not provide enough evidence to
        -- determine whether delivery was delayed.
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
    -- Shipment identifiers and descriptive attributes.
    shipment_id,
    order_id,
    shipping_method,
    shipment_status,
    shipped_at,
    delivered_at,
    delivery_city,
    delivery_state,

    -- Derived delivery duration and delivery indicator.
    delivery_days,
    is_delivered,

    -- Standardized status and delivery performance categories.
    shipment_status_group,
    delivery_speed,
    is_delivery_delayed,

    -- Source and ingestion audit timestamps.
    updated_at,
    ingested_at,
    loaded_at,

    -- Record when the transformation query executes.
    -- In a view, this value may change whenever the view is queried.
    {{ transformed_timestamp() }} AS transformed_at

FROM shipments_enriched
