
-- Test: Shipment delivery dates must be valid.
-- Expected result: Zero rows returned.
--
-- Rules:
-- 1. Delivery date cannot be earlier than shipment date.
-- 2. Delivered shipments must have a delivery date.
-- 3. Undelivered shipments may have a NULL delivery date.

SELECT
    shipment_id,
    shipment_date,
    delivery_date,
    shipment_status
FROM {{ ref('fact_shipments') }}
WHERE
    (
        shipment_date IS NOT NULL
        AND delivery_date IS NOT NULL
        AND delivery_date < shipment_date
    )
    OR (
        LOWER(TRIM(shipment_status)) = 'delivered'
        AND delivery_date IS NULL
    )
