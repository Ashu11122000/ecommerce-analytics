
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: operations_dashboard.sql
-- Purpose:
--   SQL queries powering the Analyst / Operations Dashboard.
--
-- Target personas:
--   Operations manager, fulfillment analyst, inventory analyst.
--
-- Business questions:
--   1. Which orders require processing attention?
--   2. Which shipments are delayed or undelivered?
--   3. Which payments have failed or remain pending?
--   4. Which products need replenishment?
--   5. What are the return and refund patterns?
--   6. Which order items contain invalid values?
--   7. Are there missing relationships between source records?
--
-- Source tables:
--   raw.orders
--   raw.order_items
--   raw.payments
--   raw.shipments
--   raw.returns
--   raw.products
--   raw.customers
--
-- All queries are read-only.
-- ============================================================


-- ============================================================
-- 1. OPERATIONAL KPI SUMMARY
-- Dashboard visualization:
--   KPI cards for pending orders, active shipments,
--   delayed shipments, failed payments, and open returns.
-- Grain: one row for the entire dataset.
-- ============================================================

SELECT
    (
        SELECT COUNT(*)
        FROM raw.orders
        WHERE LOWER(TRIM(COALESCE(order_status, '')))
              IN ('pending', 'confirmed', 'processing')
    ) AS orders_awaiting_processing,

    (
        SELECT COUNT(*)
        FROM raw.shipments
        WHERE LOWER(TRIM(COALESCE(shipment_status, '')))
              IN ('processing', 'shipped', 'in transit', 'in_transit')
    ) AS active_shipments,

    (
        SELECT COUNT(*)
        FROM raw.shipments
        WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delayed'
    ) AS delayed_shipments,

    (
        SELECT COUNT(*)
        FROM raw.payments
        WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'failed'
    ) AS failed_payments,

    (
        SELECT COUNT(*)
        FROM raw.payments
        WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'pending'
    ) AS pending_payments,

    (
        SELECT COUNT(*)
        FROM raw.returns
        WHERE LOWER(TRIM(COALESCE(return_status, '')))
              IN ('requested', 'approved')
    ) AS open_return_records,

    (
        SELECT COUNT(*)
        FROM raw.products
        WHERE stock_quantity IS NOT NULL
          AND reorder_level IS NOT NULL
          AND stock_quantity <= reorder_level
    ) AS products_at_or_below_reorder_level;


-- ============================================================
-- 2. ORDERS REQUIRING PROCESSING ATTENTION
-- Dashboard visualization:
--   Sortable table of orders awaiting processing or fulfillment.
-- Grain: one row per order.
-- ============================================================

SELECT
    o.order_id,
    o.customer_id,
    c.customer_name,
    o.order_date,
    o.order_status,
    o.payment_status,
    o.shipping_method,
    o.sales_channel,
    o.total_amount,

    CASE
        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'pending'
            THEN 'Review pending order'
        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'confirmed'
            THEN 'Check fulfillment readiness'
        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'processing'
            THEN 'Monitor processing progress'
        ELSE 'Review order'
    END AS recommended_action

FROM raw.orders o
LEFT JOIN raw.customers c
    ON c.customer_id = o.customer_id
WHERE LOWER(TRIM(COALESCE(o.order_status, '')))
      IN ('pending', 'confirmed', 'processing')
ORDER BY
    o.order_date ASC NULLS FIRST,
    o.order_id;


-- ============================================================
-- 3. SHIPMENT STATUS DISTRIBUTION
-- Dashboard visualization:
--   Bar or donut chart grouped by shipment status.
-- Grain: one row per normalized shipment status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(shipment_status)), ''),
        'Unknown'
    ) AS shipment_status,

    COUNT(*) AS shipment_count,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS percentage_of_shipments

FROM raw.shipments
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(shipment_status)), ''),
        'Unknown'
    )
ORDER BY shipment_count DESC;


-- ============================================================
-- 4. DELAYED SHIPMENTS AND DELIVERY SLA REVIEW
-- Dashboard visualization:
--   Table of delayed shipments with shipment age and delivery
--   duration where timestamps are available.
--
-- Important:
--   Seven days is an exploratory threshold, not a confirmed
--   contractual delivery SLA.
-- Grain: one row per shipment.
-- ============================================================

WITH reference_date AS (
    SELECT
        COALESCE(
            MAX(order_date)::DATE,
            CURRENT_DATE
        ) AS as_of_date
    FROM raw.orders
)
SELECT
    s.shipment_id,
    s.order_id,
    o.customer_id,
    o.order_status,
    s.shipping_method,
    s.shipment_status,
    s.shipped_at,
    s.delivered_at,
    s.delivery_city,
    s.delivery_state,

    rd.as_of_date,

    CASE
        WHEN s.shipped_at IS NOT NULL
         AND s.delivered_at IS NOT NULL
        THEN ROUND(
            (
                EXTRACT(
                    EPOCH FROM (s.delivered_at - s.shipped_at)
                ) / 86400.0
            )::NUMERIC,
            2
        )
        ELSE NULL
    END AS delivery_duration_days,

    CASE
        WHEN s.shipped_at IS NOT NULL
         AND s.delivered_at IS NULL
        THEN rd.as_of_date - s.shipped_at::DATE
        ELSE NULL
    END AS days_since_shipped,

    CASE
        WHEN LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delayed'
            THEN 'Marked delayed'
        WHEN s.shipped_at IS NOT NULL
         AND s.delivered_at IS NULL
         AND rd.as_of_date - s.shipped_at::DATE > 7
            THEN 'Potential delay: over 7 days'
        WHEN s.shipped_at IS NULL
         AND LOWER(TRIM(COALESCE(s.shipment_status, '')))
             IN ('shipped', 'in transit', 'in_transit')
            THEN 'Missing shipped timestamp'
        WHEN s.delivered_at IS NOT NULL
         AND s.shipped_at IS NULL
            THEN 'Delivered timestamp without shipped timestamp'
        WHEN s.delivered_at IS NOT NULL
         AND s.shipped_at IS NOT NULL
         AND s.delivered_at < s.shipped_at
            THEN 'Invalid delivery timestamps'
        ELSE 'Review if needed'
    END AS shipment_attention_reason

FROM raw.shipments s
LEFT JOIN raw.orders o
    ON o.order_id = s.order_id
CROSS JOIN reference_date rd
WHERE LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delayed'
   OR (
        s.shipped_at IS NOT NULL
        AND s.delivered_at IS NULL
        AND rd.as_of_date - s.shipped_at::DATE > 7
   )
   OR (
        s.shipped_at IS NULL
        AND LOWER(TRIM(COALESCE(s.shipment_status, '')))
            IN ('shipped', 'in transit', 'in_transit')
   )
   OR (
        s.delivered_at IS NOT NULL
        AND (
            s.shipped_at IS NULL
            OR s.delivered_at < s.shipped_at
        )
   )
ORDER BY
    s.shipped_at ASC NULLS FIRST,
    s.shipment_id;


-- ============================================================
-- 5. PAYMENT EXCEPTIONS
-- Dashboard visualization:
--   Table of failed and pending payments.
-- Grain: one row per payment record.
-- ============================================================

SELECT
    p.payment_id,
    p.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    p.payment_date,
    p.payment_method,
    p.payment_status,
    p.amount,
    p.transaction_reference,

    CASE
        WHEN LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'failed'
            THEN 'Investigate failed payment'
        WHEN LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'pending'
            THEN 'Check payment confirmation'
        WHEN p.amount IS NULL OR p.amount <= 0
            THEN 'Validate payment amount'
        WHEN NULLIF(TRIM(p.transaction_reference), '') IS NULL
            THEN 'Check transaction reference'
        ELSE 'Review payment'
    END AS recommended_action

FROM raw.payments p
LEFT JOIN raw.orders o
    ON o.order_id = p.order_id
WHERE LOWER(TRIM(COALESCE(p.payment_status, '')))
      IN ('failed', 'pending')
   OR p.amount IS NULL
   OR p.amount <= 0
   OR NULLIF(TRIM(p.transaction_reference), '') IS NULL
ORDER BY
    p.payment_date ASC NULLS FIRST,
    p.payment_id;


-- ============================================================
-- 6. PAYMENT STATUS AND AMOUNT SUMMARY
-- Dashboard visualization:
--   Bar chart of payment counts and amounts by status.
-- Grain: one row per payment status and payment method.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    ) AS payment_status,

    COALESCE(
        NULLIF(INITCAP(TRIM(payment_method)), ''),
        'Unknown'
    ) AS payment_method,

    COUNT(*) AS payment_count,

    ROUND(
        COALESCE(SUM(amount), 0)::NUMERIC,
        2
    ) AS total_payment_amount,

    ROUND(
        AVG(amount)::NUMERIC,
        2
    ) AS average_payment_amount

FROM raw.payments
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_method)), ''),
        'Unknown'
    )
ORDER BY payment_count DESC;


-- ============================================================
-- 7. INVENTORY REPLENISHMENT PRIORITIES
-- Dashboard visualization:
--   Table sorted by stock shortage.
-- Grain: one row per product below or at reorder level.
-- ============================================================

SELECT
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    supplier_id,
    stock_quantity,
    reorder_level,

    reorder_level - stock_quantity AS units_below_reorder_level,

    cost_price,
    selling_price,

    CASE
        WHEN stock_quantity < 0
            THEN 'Data quality issue: negative stock'
        WHEN stock_quantity = 0
            THEN 'Urgent: out of stock'
        WHEN stock_quantity <= reorder_level
            THEN 'Reorder required'
        ELSE 'Stock available'
    END AS inventory_attention_status

FROM raw.products
WHERE stock_quantity IS NOT NULL
  AND reorder_level IS NOT NULL
  AND stock_quantity <= reorder_level
ORDER BY
    CASE WHEN stock_quantity <= 0 THEN 0 ELSE 1 END,
    (reorder_level - stock_quantity) DESC,
    product_name;


-- ============================================================
-- 8. RETURN WORK QUEUE
-- Dashboard visualization:
--   Table of requested or approved returns awaiting resolution.
-- Grain: one row per return record.
-- ============================================================

SELECT
    r.return_id,
    r.order_item_id,
    oi.order_id,
    oi.product_id,
    p.product_name,
    o.customer_id,
    r.return_date,
    r.return_reason,
    r.return_quantity,
    r.refund_amount,
    r.return_status,

    CASE
        WHEN LOWER(TRIM(COALESCE(r.return_status, ''))) = 'requested'
            THEN 'Review return request'
        WHEN LOWER(TRIM(COALESCE(r.return_status, ''))) = 'approved'
            THEN 'Track return completion and refund'
        ELSE 'Review return status'
    END AS recommended_action

FROM raw.returns r
LEFT JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
LEFT JOIN raw.orders o
    ON o.order_id = oi.order_id
WHERE LOWER(TRIM(COALESCE(r.return_status, '')))
      IN ('requested', 'approved')
ORDER BY
    r.return_date ASC NULLS FIRST,
    r.return_id;


-- ============================================================
-- 9. RETURN AND REFUND PERFORMANCE
-- Dashboard visualization:
--   Bar chart by return reason and return status.
-- Grain: one row per return reason and status combination.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(return_reason)), ''),
        'Unknown'
    ) AS return_reason,

    COALESCE(
        NULLIF(INITCAP(TRIM(return_status)), ''),
        'Unknown'
    ) AS return_status,

    COUNT(*) AS return_record_count,

    SUM(return_quantity) AS returned_units,

    ROUND(
        COALESCE(SUM(refund_amount), 0)::NUMERIC,
        2
    ) AS total_refund_amount

FROM raw.returns
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(return_reason)), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(return_status)), ''),
        'Unknown'
    )
ORDER BY total_refund_amount DESC NULLS LAST;


-- ============================================================
-- 10. ORDER ITEMS WITH INVALID VALUES
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per invalid order-item record.
--
-- Negative quantity is an observed anomaly in the source data.
-- Do not silently change the raw record; correct or exclude it
-- in a documented downstream transformation.
-- ============================================================

SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    oi.tax_amount,
    oi.line_total,
    oi.returned_quantity,

    CASE
        WHEN oi.quantity IS NULL
            THEN 'Missing quantity'
        WHEN oi.quantity <= 0
            THEN 'Invalid quantity: must be positive'
        WHEN oi.unit_price IS NULL OR oi.unit_price < 0
            THEN 'Invalid unit price'
        WHEN oi.discount_amount IS NULL OR oi.discount_amount < 0
            THEN 'Invalid discount amount'
        WHEN oi.tax_amount IS NULL OR oi.tax_amount < 0
            THEN 'Invalid tax amount'
        WHEN oi.line_total IS NULL OR oi.line_total < 0
            THEN 'Invalid line total'
        WHEN oi.returned_quantity IS NULL
            THEN 'Missing returned quantity'
        WHEN oi.returned_quantity < 0
            THEN 'Negative returned quantity'
        WHEN oi.returned_quantity > oi.quantity
            THEN 'Returned quantity exceeds ordered quantity'
        ELSE 'Review record'
    END AS data_quality_issue

FROM raw.order_items oi
WHERE oi.quantity IS NULL
   OR oi.quantity <= 0
   OR oi.unit_price IS NULL
   OR oi.unit_price < 0
   OR oi.discount_amount IS NULL
   OR oi.discount_amount < 0
   OR oi.tax_amount IS NULL
   OR oi.tax_amount < 0
   OR oi.line_total IS NULL
   OR oi.line_total < 0
   OR oi.returned_quantity IS NULL
   OR oi.returned_quantity < 0
   OR oi.returned_quantity > oi.quantity
ORDER BY oi.order_item_id;


-- ============================================================
-- 11. MISSING OR ORPHANED RELATIONSHIPS
-- Dashboard visualization:
--   Data-quality KPI cards and exception table.
-- Grain: one row per detected relationship issue.
-- ============================================================

SELECT
    'Order references missing customer' AS issue_type,
    o.order_id::TEXT AS record_id,
    o.customer_id::TEXT AS related_record_id
FROM raw.orders o
LEFT JOIN raw.customers c
    ON c.customer_id = o.customer_id
WHERE o.customer_id IS NOT NULL
  AND c.customer_id IS NULL

UNION ALL

SELECT
    'Order item references missing order',
    oi.order_item_id::TEXT,
    oi.order_id::TEXT
FROM raw.order_items oi
LEFT JOIN raw.orders o
    ON o.order_id = oi.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'Order item references missing product',
    oi.order_item_id::TEXT,
    oi.product_id::TEXT
FROM raw.order_items oi
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT
    'Payment references missing order',
    p.payment_id::TEXT,
    p.order_id::TEXT
FROM raw.payments p
LEFT JOIN raw.orders o
    ON o.order_id = p.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'Shipment references missing order',
    s.shipment_id::TEXT,
    s.order_id::TEXT
FROM raw.shipments s
LEFT JOIN raw.orders o
    ON o.order_id = s.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'Return references missing order item',
    r.return_id::TEXT,
    r.order_item_id::TEXT
FROM raw.returns r
LEFT JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id
WHERE oi.order_item_id IS NULL

ORDER BY issue_type, record_id;


-- ============================================================
-- 12. ORDER-TO-PAYMENT RECONCILIATION
-- Dashboard visualization:
--   Table of orders whose successful payment totals differ
--   from their order total.
--
-- Assumption:
--   Only payment records with status 'paid' are included.
--   Multiple payment records are aggregated before joining
--   to orders to avoid duplicating order rows.
--   Refund and partial-payment accounting needs separate rules.
-- Grain: one row per order with payment records.
-- ============================================================

WITH paid_payment_totals AS (
    SELECT
        order_id,
        COUNT(*) AS paid_payment_count,
        SUM(amount)::NUMERIC AS paid_amount
    FROM raw.payments
    WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'paid'
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    o.payment_status AS order_payment_status,
    o.total_amount AS order_total,
    ppt.paid_payment_count,
    ROUND(ppt.paid_amount, 2) AS total_paid_amount,

    ROUND(
        o.total_amount::NUMERIC - ppt.paid_amount,
        2
    ) AS difference_amount,

    CASE
        WHEN o.total_amount IS NULL
            THEN 'Missing order total'
        WHEN ppt.paid_amount IS NULL
            THEN 'No paid payment recorded'
        WHEN ABS(o.total_amount::NUMERIC - ppt.paid_amount) <= 0.01
            THEN 'Reconciled'
        WHEN ppt.paid_amount < o.total_amount
            THEN 'Paid amount below order total'
        ELSE 'Paid amount above order total'
    END AS reconciliation_status

FROM raw.orders o
LEFT JOIN paid_payment_totals ppt
    ON ppt.order_id = o.order_id
WHERE ppt.order_id IS NOT NULL
   OR LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'paid'
ORDER BY
    CASE
        WHEN ppt.paid_amount IS NULL THEN 1
        WHEN o.total_amount IS NULL THEN 1
        WHEN ABS(o.total_amount::NUMERIC - ppt.paid_amount) > 0.01 THEN 1
        ELSE 0
    END DESC,
    o.order_id;


-- ============================================================
-- 13. INGESTION FRESHNESS
-- Dashboard visualization:
--   Table or KPI cards showing latest ingestion timestamp
--   and records missing ingestion timestamps.
-- Grain: one row per raw table.
-- ============================================================

SELECT
    'customers' AS table_name,
    COUNT(*) AS row_count,
    MAX(ingested_at) AS latest_ingested_at,
    COUNT(*) FILTER (
        WHERE ingested_at IS NULL
    ) AS missing_ingested_at_count
FROM raw.customers

UNION ALL

SELECT
    'products',
    COUNT(*),
    MAX(ingested_at),
    COUNT(*) FILTER (WHERE ingested_at IS NULL)
FROM raw.products

UNION ALL

SELECT
    'orders',
    COUNT(*),
    MAX(ingested_at),
    COUNT(*) FILTER (WHERE ingested_at IS NULL)
FROM raw.orders

UNION ALL

SELECT
    'order_items',
    COUNT(*),
    MAX(ingested_at),
    COUNT(*) FILTER (WHERE ingested_at IS NULL)
FROM raw.order_items

UNION ALL

SELECT
    'payments',
    COUNT(*),
    MAX(ingested_at),
    COUNT(*) FILTER (WHERE ingested_at IS NULL)
FROM raw.payments

UNION ALL

SELECT
    'shipments',
    COUNT(*),
    MAX(ingested_at),
    COUNT(*) FILTER (WHERE ingested_at IS NULL)
FROM raw.shipments

UNION ALL

SELECT
    'returns',
    COUNT(*),
    MAX(ingested_at),
    COUNT(*) FILTER (WHERE ingested_at IS NULL)
FROM raw.returns

ORDER BY table_name;


-- ============================================================
-- 14. OPERATIONAL EXCEPTION COUNTS
-- Dashboard visualization:
--   Compact table or bar chart of outstanding issue categories.
-- Grain: one row per exception category.
-- ============================================================

SELECT
    'Orders awaiting processing' AS exception_category,
    COUNT(*)::BIGINT AS exception_count
FROM raw.orders
WHERE LOWER(TRIM(COALESCE(order_status, '')))
      IN ('pending', 'confirmed', 'processing')

UNION ALL

SELECT
    'Delayed shipments',
    COUNT(*)::BIGINT
FROM raw.shipments
WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delayed'

UNION ALL

SELECT
    'Failed payments',
    COUNT(*)::BIGINT
FROM raw.payments
WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'failed'

UNION ALL

SELECT
    'Pending payments',
    COUNT(*)::BIGINT
FROM raw.payments
WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'pending'

UNION ALL

SELECT
    'Open return records',
    COUNT(*)::BIGINT
FROM raw.returns
WHERE LOWER(TRIM(COALESCE(return_status, '')))
      IN ('requested', 'approved')

UNION ALL

SELECT
    'Invalid order-item quantities',
    COUNT(*)::BIGINT
FROM raw.order_items
WHERE quantity IS NULL OR quantity <= 0

UNION ALL

SELECT
    'Products at or below reorder level',
    COUNT(*)::BIGINT
FROM raw.products
WHERE stock_quantity IS NOT NULL
  AND reorder_level IS NOT NULL
  AND stock_quantity <= reorder_level

ORDER BY exception_count DESC, exception_category;


-- ============================================================
-- END OF operations_dashboard.sql
-- ============================================================
