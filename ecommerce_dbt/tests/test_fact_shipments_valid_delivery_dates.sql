
-- Test: Shipment delivery dates must be valid.
-- Expected result: Zero rows returned.
--
-- Rules:
-- 1. Delivery date cannot be earlier than shipment date.
-- 2. Delivered shipments must have a delivery date.
-- 3. Undelivered shipments may have a NULL delivery date.

SELECT
    shipment_id,
    shipped_at,
    delivered_at,
    shipment_status
FROM {{ ref('fact_shipments') }}
WHERE
    (
        shipped_at IS NOT NULL
        AND delivered_at IS NOT NULL
        AND delivered_at < shipped_at
    )
    OR (
        LOWER(TRIM(shipment_status)) = 'delivered'
        AND delivered_at IS NULL
    )
