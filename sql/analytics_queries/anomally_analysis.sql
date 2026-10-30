-- ============================================================
-- E-COMMERCE ANALYTICS ENGINEERING
-- File: anomally_analysis.sql
-- Purpose: Identify potential anomalies in raw e-commerce data.
-- Database: ecommerce_analytics
-- Schema: raw
--
-- Anomaly categories:
--   1. Invalid order-item quantities
--   2. Unusual order values
--   3. Unusual discounts
--   4. Unusual product pricing
--   5. Unusual payment amounts
--   6. Unusual refunds
--   7. Shipment delays
--   8. Orders without order items
--   9. Orders with inconsistent payment totals
--  10. Orders with unusually many items
-- ============================================================


-- ============================================================
-- 1. INVALID ORDER-ITEM QUANTITIES AND VALUES
-- Expected: no invalid quantities in trusted reporting data.
-- Known anomaly: order_item_id = 1011 has quantity = -1.
-- ============================================================

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    tax_amount,
    line_total,
    returned_quantity,
    CASE
        WHEN quantity <= 0
            THEN 'INVALID_QUANTITY'
        WHEN unit_price < 0
            THEN 'NEGATIVE_UNIT_PRICE'
        WHEN discount_amount < 0
            THEN 'NEGATIVE_DISCOUNT'
        WHEN tax_amount < 0
            THEN 'NEGATIVE_TAX'
        WHEN line_total < 0
            THEN 'NEGATIVE_LINE_TOTAL'
        WHEN returned_quantity < 0
            THEN 'NEGATIVE_RETURNED_QUANTITY'
        WHEN returned_quantity > quantity
            THEN 'RETURNED_QUANTITY_EXCEEDS_ORDERED'
    END AS anomaly_type
FROM raw.order_items
WHERE quantity <= 0
   OR unit_price < 0
   OR discount_amount < 0
   OR tax_amount < 0
   OR line_total < 0
   OR returned_quantity < 0
   OR returned_quantity > quantity
ORDER BY order_item_id;


-- ============================================================
-- 2. UNUSUALLY HIGH ORDER VALUES
--
-- Flags orders whose total exceeds the mean by more than
-- three population standard deviations.
--
-- Limitation:
-- This is a statistical screening rule. A high-value order
-- may be legitimate.
-- ============================================================

WITH order_statistics AS (
    SELECT
        AVG(total_amount) AS average_order_value,
        STDDEV_POP(total_amount) AS order_value_stddev
    FROM raw.orders
    WHERE total_amount IS NOT NULL
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.total_amount,
    s.average_order_value,
    s.order_value_stddev,
    CASE
        WHEN s.order_value_stddev = 0
            THEN NULL
        ELSE
            (o.total_amount - s.average_order_value)
            / s.order_value_stddev
    END AS z_score,
    'HIGH_ORDER_VALUE' AS anomaly_type
FROM raw.orders AS o
CROSS JOIN order_statistics AS s
WHERE o.total_amount IS NOT NULL
  AND s.order_value_stddev > 0
  AND o.total_amount >
      s.average_order_value + (3 * s.order_value_stddev)
ORDER BY o.total_amount DESC;


-- ============================================================
-- 3. UNUSUALLY HIGH ORDER-ITEM DISCOUNTS
--
-- Flags discounts greater than 50% of the item's gross value.
--
-- Assumption:
-- gross item value = quantity * unit_price.
-- The 50% threshold is configurable and should be reviewed.
-- ============================================================

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    quantity * unit_price AS gross_item_value,
    ROUND(
        100.0 * discount_amount
        / NULLIF(quantity * unit_price, 0),
        2
    ) AS discount_percentage,
    'HIGH_ITEM_DISCOUNT' AS anomaly_type
FROM raw.order_items
WHERE quantity > 0
  AND unit_price > 0
  AND discount_amount IS NOT NULL
  AND discount_amount >
      0.50 * quantity * unit_price
ORDER BY discount_percentage DESC;


-- ============================================================
-- 4. PRODUCT PRICING ANOMALIES
--
-- Flags:
--   - Negative prices or costs
--   - Zero selling prices
--   - Cost higher than selling price
--
-- Cost exceeding price may be legitimate for clearance,
-- promotions, or loss-leading products.
-- ============================================================

SELECT
    product_id,
    product_name,
    category,
    cost_price,
    selling_price,
    CASE
        WHEN cost_price < 0 OR selling_price < 0
            THEN 'NEGATIVE_PRICE_OR_COST'
        WHEN selling_price = 0
            THEN 'ZERO_SELLING_PRICE'
        WHEN cost_price > selling_price
            THEN 'COST_EXCEEDS_SELLING_PRICE'
    END AS anomaly_type
FROM raw.products
WHERE cost_price < 0
   OR selling_price < 0
   OR selling_price = 0
   OR cost_price > selling_price
ORDER BY product_id;


-- ============================================================
-- 5. UNUSUALLY HIGH PAYMENT AMOUNTS
--
-- Flags payment amounts greater than the mean by more than
-- three population standard deviations.
--
-- This screening does not distinguish successful, pending,
-- failed, or refunded payments.
-- ============================================================

WITH payment_statistics AS (
    SELECT
        AVG(amount) AS average_payment_amount,
        STDDEV_POP(amount) AS payment_amount_stddev
    FROM raw.payments
    WHERE amount IS NOT NULL
)
SELECT
    p.payment_id,
    p.order_id,
    p.payment_date,
    p.payment_method,
    p.payment_status,
    p.amount,
    s.average_payment_amount,
    s.payment_amount_stddev,
    CASE
        WHEN s.payment_amount_stddev = 0
            THEN NULL
        ELSE
            (p.amount - s.average_payment_amount)
            / s.payment_amount_stddev
    END AS z_score,
    'HIGH_PAYMENT_AMOUNT' AS anomaly_type
FROM raw.payments AS p
CROSS JOIN payment_statistics AS s
WHERE p.amount IS NOT NULL
  AND s.payment_amount_stddev > 0
  AND p.amount >
      s.average_payment_amount + (3 * s.payment_amount_stddev)
ORDER BY p.amount DESC;


-- ============================================================
-- 6. UNUSUALLY HIGH REFUNDS
--
-- Flags refund amounts greater than the mean by more than
-- three population standard deviations.
--
-- Refunds may be associated with partial returns, so a refund
-- need not equal the full order-item value.
-- ============================================================

WITH refund_statistics AS (
    SELECT
        AVG(refund_amount) AS average_refund_amount,
        STDDEV_POP(refund_amount) AS refund_amount_stddev
    FROM raw.returns
    WHERE refund_amount IS NOT NULL
)
SELECT
    r.return_id,
    r.order_item_id,
    r.return_date,
    r.return_quantity,
    r.refund_amount,
    r.return_status,
    s.average_refund_amount,
    s.refund_amount_stddev,
    CASE
        WHEN s.refund_amount_stddev = 0
            THEN NULL
        ELSE
            (r.refund_amount - s.average_refund_amount)
            / s.refund_amount_stddev
    END AS z_score,
    'HIGH_REFUND_AMOUNT' AS anomaly_type
FROM raw.returns AS r
CROSS JOIN refund_statistics AS s
WHERE r.refund_amount IS NOT NULL
  AND s.refund_amount_stddev > 0
  AND r.refund_amount >
      s.average_refund_amount + (3 * s.refund_amount_stddev)
ORDER BY r.refund_amount DESC;


-- ============================================================
-- 7. SHIPMENT DELAYS
--
-- Flags shipments taking longer than seven days between
-- shipped_at and delivered_at.
--
-- Assumption:
-- Seven calendar days is a screening threshold, not a
-- confirmed service-level agreement.
-- ============================================================

SELECT
    shipment_id,
    order_id,
    shipping_method,
    shipment_status,
    shipped_at,
    delivered_at,
    ROUND(
        (
            EXTRACT(EPOCH FROM (delivered_at - shipped_at))
            / 86400.0
        )::NUMERIC,
        2
    ) AS delivery_days,
    'LONG_DELIVERY_DURATION' AS anomaly_type
FROM raw.shipments
WHERE shipped_at IS NOT NULL
  AND delivered_at IS NOT NULL
  AND delivered_at >= shipped_at
  AND delivered_at - shipped_at > INTERVAL '7 days'
ORDER BY delivery_days DESC;


-- ============================================================
-- 8. ORDERS WITHOUT ORDER ITEMS
--
-- Flags orders that have no corresponding order-item records.
-- Investigate cancellations and incomplete order ingestion
-- before classifying these records as data errors.
-- ============================================================

SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.total_amount,
    'ORDER_WITHOUT_ITEMS' AS anomaly_type
FROM raw.orders AS o
LEFT JOIN raw.order_items AS oi
    ON o.order_id = oi.order_id
WHERE oi.order_item_id IS NULL
ORDER BY o.order_date DESC;


-- ============================================================
-- 9. PAYMENT TOTALS THAT DIFFER FROM ORDER TOTALS
--
-- Diagnostic comparison of successful-looking payment records
-- against the order total.
--
-- Assumptions:
--   - Paid records represent completed payment amounts.
--   - Refunded, pending, and failed records are excluded.
--   - Multiple successful payments are summed.
--
-- Important:
-- Validate the payment-status semantics and whether payment
-- amounts are gross, net, or already adjusted for refunds.
-- ============================================================

WITH paid_totals AS (
    SELECT
        order_id,
        COUNT(*) AS paid_payment_count,
        SUM(amount) AS paid_payment_total
    FROM raw.payments
    WHERE LOWER(TRIM(payment_status)) = 'paid'
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    o.total_amount AS order_total,
    p.paid_payment_count,
    p.paid_payment_total,
    p.paid_payment_total - o.total_amount AS payment_difference,
    CASE
        WHEN p.order_id IS NULL
            THEN 'NO_PAID_PAYMENT'
        WHEN o.total_amount IS NULL
            THEN 'MISSING_ORDER_TOTAL'
        WHEN ABS(p.paid_payment_total - o.total_amount) <= 0.01
            THEN 'MATCH'
        WHEN p.paid_payment_total < o.total_amount
            THEN 'PAYMENT_BELOW_ORDER_TOTAL'
        ELSE 'PAYMENT_ABOVE_ORDER_TOTAL'
    END AS anomaly_type
FROM raw.orders AS o
LEFT JOIN paid_totals AS p
    ON o.order_id = p.order_id
ORDER BY o.order_id;


-- ============================================================
-- 10. ORDERS WITH UNUSUALLY MANY DISTINCT ORDER ITEMS
--
-- Flags orders with more than ten distinct order-item records.
-- This is an illustrative operational threshold.
-- ============================================================

SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    COUNT(oi.order_item_id) AS order_item_count,
    SUM(oi.quantity) AS total_units,
    'HIGH_ORDER_ITEM_COUNT' AS anomaly_type
FROM raw.orders AS o
JOIN raw.order_items AS oi
    ON o.order_id = oi.order_id
GROUP BY
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status
HAVING COUNT(oi.order_item_id) > 10
ORDER BY order_item_count DESC, o.order_id;


-- ============================================================
-- 11. RETURNED QUANTITY EXCEEDS ORDERED QUANTITY
--
-- Compares cumulative return records with the original
-- quantity on each order item.
--
-- This is more reliable than checking each return record alone
-- when an order item can have multiple return records.
-- ============================================================

WITH return_totals AS (
    SELECT
        order_item_id,
        COUNT(*) AS return_record_count,
        SUM(return_quantity) AS total_return_quantity
    FROM raw.returns
    GROUP BY order_item_id
)
SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity AS ordered_quantity,
    rt.return_record_count,
    rt.total_return_quantity,
    rt.total_return_quantity - oi.quantity AS excess_quantity,
    'CUMULATIVE_RETURN_EXCEEDS_ORDERED' AS anomaly_type
FROM raw.order_items AS oi
JOIN return_totals AS rt
    ON oi.order_item_id = rt.order_item_id
WHERE rt.total_return_quantity > oi.quantity
ORDER BY excess_quantity DESC;


-- ============================================================
-- 12. ANOMALY SUMMARY
--
-- Consolidated count of several core anomaly categories.
-- These counts can be used as a simple operational KPI.
--
-- Categories are not mutually exclusive: one record may
-- qualify for more than one category.
-- ============================================================

WITH anomaly_counts AS (
    SELECT
        'INVALID_ORDER_ITEM_QUANTITY' AS anomaly_type,
        COUNT(*) AS anomaly_count
    FROM raw.order_items
    WHERE quantity <= 0

    UNION ALL

    SELECT
        'NEGATIVE_ORDER_ITEM_PRICE',
        COUNT(*)
    FROM raw.order_items
    WHERE unit_price < 0

    UNION ALL

    SELECT
        'NEGATIVE_ORDER_ITEM_DISCOUNT',
        COUNT(*)
    FROM raw.order_items
    WHERE discount_amount < 0

    UNION ALL

    SELECT
        'NEGATIVE_ORDER_ITEM_TAX',
        COUNT(*)
    FROM raw.order_items
    WHERE tax_amount < 0

    UNION ALL

    SELECT
        'NEGATIVE_ORDER_ITEM_LINE_TOTAL',
        COUNT(*)
    FROM raw.order_items
    WHERE line_total < 0

    UNION ALL

    SELECT
        'MISSING_CUSTOMER_RELATIONSHIP',
        COUNT(*)
    FROM raw.orders AS o
    LEFT JOIN raw.customers AS c
        ON o.customer_id = c.customer_id
    WHERE c.customer_id IS NULL

    UNION ALL

    SELECT
        'MISSING_ORDER_RELATIONSHIP',
        COUNT(*)
    FROM raw.order_items AS oi
    LEFT JOIN raw.orders AS o
        ON oi.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'MISSING_PRODUCT_RELATIONSHIP',
        COUNT(*)
    FROM raw.order_items AS oi
    LEFT JOIN raw.products AS p
        ON oi.product_id = p.product_id
    WHERE p.product_id IS NULL

    UNION ALL

    SELECT
        'MISSING_INGESTION_TIMESTAMP',
        (
            SELECT COUNT(*)
            FROM (
                SELECT ingested_at FROM raw.customers
                UNION ALL
                SELECT ingested_at FROM raw.products
                UNION ALL
                SELECT ingested_at FROM raw.orders
                UNION ALL
                SELECT ingested_at FROM raw.order_items
                UNION ALL
                SELECT ingested_at FROM raw.payments
                UNION ALL
                SELECT ingested_at FROM raw.shipments
                UNION ALL
                SELECT ingested_at FROM raw.returns
            ) AS all_ingestion_timestamps
            WHERE ingested_at IS NULL
        )
)
SELECT
    anomaly_type,
    anomaly_count,
    CASE
        WHEN anomaly_count = 0 THEN 'NO_ISSUES_FOUND'
        ELSE 'REVIEW_REQUIRED'
    END AS validation_status
FROM anomaly_counts
ORDER BY anomaly_count DESC, anomaly_type;


-- ============================================================
-- END OF ANOMALY ANALYSIS
-- ============================================================