
-- ============================================================
-- Analysis: anomaly_analysis
-- Layer: Gold / Analytics
--
-- Purpose:
--   Identify unusual values and operational patterns in the
--   Gold reporting layer for investigation and dashboarding.
--
-- Output grain:
--   One row per detected anomaly.
--
-- Output columns:
--   anomaly_type, severity, entity_type, entity_id,
--   order_id, event_date, metric_value, anomaly_details
--
-- Important:
--   - This is a read-only dbt analysis query.
--   - It does not create or modify database tables.
--   - Threshold-based findings require business review.
--   - Multiple anomalies may be reported for the same entity.
-- ============================================================

WITH order_item_anomalies AS (

    -- 1. Source line total differs from calculated line total.
    SELECT
        'LINE_TOTAL_MISMATCH'::TEXT AS anomaly_type,
        'Medium'::TEXT AS severity,
        'order_item'::TEXT AS entity_type,
        f.order_item_id::TEXT AS entity_id,
        f.order_id::TEXT AS order_id,
        f.order_date::DATE AS event_date,
        f.line_total_variance::NUMERIC AS metric_value,
        (
            'Source line total differs from calculated line total. '
            || 'Source total: '
            || COALESCE(f.line_total::TEXT, 'NULL')
            || '; calculated total: '
            || COALESCE(f.calculated_line_total::TEXT, 'NULL')
        )::TEXT AS anomaly_details
    FROM {{ ref('fact_order_items') }} AS f
    WHERE f.is_line_total_mismatch IS TRUE

    UNION ALL

    -- 2. Negative item quantity.
    SELECT
        'NEGATIVE_ORDER_QUANTITY'::TEXT,
        'High'::TEXT,
        'order_item'::TEXT,
        f.order_item_id::TEXT,
        f.order_id::TEXT,
        f.order_date::DATE,
        f.quantity::NUMERIC,
        (
            'Order item has a negative quantity: '
            || COALESCE(f.quantity::TEXT, 'NULL')
        )::TEXT
    FROM {{ ref('fact_order_items') }} AS f
    WHERE f.has_negative_quantity IS TRUE

    UNION ALL

    -- 3. Returned quantity exceeds ordered quantity.
    SELECT
        'EXCESS_RETURNED_QUANTITY'::TEXT,
        'High'::TEXT,
        'order_item'::TEXT,
        f.order_item_id::TEXT,
        f.order_id::TEXT,
        f.order_date::DATE,
        f.returned_quantity::NUMERIC,
        (
            'Returned quantity exceeds ordered quantity. Ordered: '
            || COALESCE(f.quantity::TEXT, 'NULL')
            || '; returned: '
            || COALESCE(f.returned_quantity::TEXT, 'NULL')
        )::TEXT
    FROM {{ ref('fact_order_items') }} AS f
    WHERE f.has_excess_returned_quantity IS TRUE

),

payment_anomalies AS (

    -- 4. Negative payment amount.
    -- Silver classifies negative amounts as Invalid.
    SELECT
        'INVALID_PAYMENT_AMOUNT'::TEXT AS anomaly_type,
        'High'::TEXT AS severity,
        'payment'::TEXT AS entity_type,
        p.payment_id::TEXT AS entity_id,
        p.order_id::TEXT AS order_id,
        p.payment_date::DATE AS event_date,
        p.amount::NUMERIC AS metric_value,
        (
            'Payment amount is negative: '
            || COALESCE(p.amount::TEXT, 'NULL')
        )::TEXT AS anomaly_details
    FROM {{ ref('fact_payments') }} AS p
    WHERE p.payment_amount_band = 'Invalid'

    UNION ALL

    -- 5. Very large payment amount.
    -- Silver defines Very Large as an amount >= 5000.
    -- This is a review flag, not proof of an error.
    SELECT
        'VERY_LARGE_PAYMENT'::TEXT,
        'Review'::TEXT,
        'payment'::TEXT,
        p.payment_id::TEXT,
        p.order_id::TEXT,
        p.payment_date::DATE,
        p.amount::NUMERIC,
        (
            'Payment is classified as Very Large by Silver. Amount: '
            || COALESCE(p.amount::TEXT, 'NULL')
            || '. Verify currency and payment status.'
        )::TEXT
    FROM {{ ref('fact_payments') }} AS p
    WHERE p.payment_amount_band = 'Very Large'

),

return_anomalies AS (

    -- 6. Non-positive return quantity.
    SELECT
        'INVALID_RETURN_QUANTITY'::TEXT AS anomaly_type,
        'High'::TEXT AS severity,
        'return'::TEXT AS entity_type,
        r.return_id::TEXT AS entity_id,
        oi.order_id::TEXT AS order_id,
        r.return_date::DATE AS event_date,
        r.return_quantity::NUMERIC AS metric_value,
        (
            'Return quantity is zero or negative: '
            || COALESCE(r.return_quantity::TEXT, 'NULL')
        )::TEXT AS anomaly_details
    FROM {{ ref('fact_returns') }} AS r
    LEFT JOIN {{ ref('fact_order_items') }} AS oi
        ON r.order_item_id = oi.order_item_id
    WHERE r.has_invalid_return_quantity IS TRUE

    UNION ALL

    -- 7. Negative recorded refund amount.
    SELECT
        'NEGATIVE_REFUND_AMOUNT'::TEXT,
        'High'::TEXT,
        'return'::TEXT,
        r.return_id::TEXT,
        oi.order_id::TEXT,
        r.return_date::DATE,
        r.refund_amount::NUMERIC,
        (
            'Recorded refund amount is negative: '
            || COALESCE(r.refund_amount::TEXT, 'NULL')
        )::TEXT
    FROM {{ ref('fact_returns') }} AS r
    LEFT JOIN {{ ref('fact_order_items') }} AS oi
        ON r.order_item_id = oi.order_item_id
    WHERE r.refund_amount < 0

),

shipment_anomalies AS (

    -- 8. Invalid delivery duration.
    -- Silver identifies invalid durations when delivery precedes
    -- shipment or the duration is otherwise classified as Invalid.
    SELECT
        'INVALID_DELIVERY_DURATION'::TEXT AS anomaly_type,
        'High'::TEXT AS severity,
        'shipment'::TEXT AS entity_type,
        s.shipment_id::TEXT AS entity_id,
        s.order_id::TEXT AS order_id,
        s.shipped_at::DATE AS event_date,
        s.delivery_days::NUMERIC AS metric_value,
        (
            'Shipment has an invalid delivery duration. Shipped at: '
            || COALESCE(s.shipped_at::TEXT, 'NULL')
            || '; delivered at: '
            || COALESCE(s.delivered_at::TEXT, 'NULL')
        )::TEXT AS anomaly_details
    FROM {{ ref('fact_shipments') }} AS s
    WHERE s.delivery_speed = 'Invalid'

    UNION ALL

    -- 9. Delivery delay according to the Silver business rule.
    SELECT
        'DELAYED_DELIVERY'::TEXT,
        'Review'::TEXT,
        'shipment'::TEXT,
        s.shipment_id::TEXT,
        s.order_id::TEXT,
        s.shipped_at::DATE,
        s.delivery_days::NUMERIC,
        (
            'Shipment is classified as delayed by Silver. '
            || 'Delivery duration in days: '
            || COALESCE(s.delivery_days::TEXT, 'NULL')
        )::TEXT
    FROM {{ ref('fact_shipments') }} AS s
    WHERE s.is_delivery_delayed IS TRUE

),

product_anomalies AS (

    -- 10. Invalid product stock quantity or inventory data.
    SELECT
        'INVALID_PRODUCT_STOCK'::TEXT AS anomaly_type,
        'High'::TEXT AS severity,
        'product'::TEXT AS entity_type,
        p.product_id::TEXT AS entity_id,
        NULL::TEXT AS order_id,
        p.launch_date::DATE AS event_date,
        p.stock_quantity::NUMERIC AS metric_value,
        (
            'Product has Invalid Stock status. Stock quantity: '
            || COALESCE(p.stock_quantity::TEXT, 'NULL')
            || '; reorder level: '
            || COALESCE(p.reorder_level::TEXT, 'NULL')
        )::TEXT AS anomaly_details
    FROM {{ ref('dim_products') }} AS p
    WHERE p.stock_status = 'Invalid Stock'

),

all_anomalies AS (

    SELECT * FROM order_item_anomalies

    UNION ALL

    SELECT * FROM payment_anomalies

    UNION ALL

    SELECT * FROM return_anomalies

    UNION ALL

    SELECT * FROM shipment_anomalies

    UNION ALL

    SELECT * FROM product_anomalies

)

-- Final output: one row per detected anomaly.
SELECT
    anomaly_type,
    severity,
    entity_type,
    entity_id,
    order_id,
    event_date,
    metric_value,
    anomaly_details

FROM all_anomalies

ORDER BY
    CASE severity
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Review' THEN 3
        ELSE 4
    END,
    event_date DESC NULLS LAST,
    anomaly_type,
    entity_id;
