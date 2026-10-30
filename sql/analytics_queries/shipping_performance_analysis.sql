
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: shipping_performance_analysis.sql
-- Purpose:
--   Analyze shipping performance, delivery times, shipment
--   statuses, potential delays, and fulfillment exceptions.
--
-- Target personas:
--   Fulfillment managers, operations analysts, leadership.
--
-- Source tables:
--   raw.shipments
--   raw.orders
--   raw.customers
--
-- Business questions:
--   1. What is the distribution of shipment statuses?
--   2. How many shipments are delayed or still in transit?
--   3. What is the average delivery duration?
--   4. Which shipping methods have the longest delivery times?
--   5. Which delivery locations have the most shipments?
--   6. Are order and shipment statuses consistent?
--   7. Which shipment records need investigation?
--
-- All queries are read-only.
-- ============================================================


-- ============================================================
-- 1. SHIPPING KPI SUMMARY
-- Dashboard visualization:
--   KPI cards for total shipments, delivered shipments,
--   delayed shipments, active shipments, and delivery duration.
-- Grain: one row for the entire dataset.
-- ============================================================

WITH shipment_metrics AS (
    SELECT
        COUNT(*) AS total_shipments,

        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delivered'
        ) AS delivered_shipments,

        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delayed'
        ) AS delayed_shipments,

        COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(shipment_status, '')))
                IN ('processing', 'shipped', 'in transit', 'in_transit')
        ) AS active_shipments,

        COUNT(*) FILTER (
            WHERE shipped_at IS NOT NULL
              AND delivered_at IS NOT NULL
        ) AS shipments_with_both_timestamps,

        AVG(
            EXTRACT(EPOCH FROM (delivered_at - shipped_at)) / 86400.0
        ) FILTER (
            WHERE shipped_at IS NOT NULL
              AND delivered_at IS NOT NULL
              AND delivered_at >= shipped_at
        ) AS average_delivery_days,

        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(
                EPOCH FROM (delivered_at - shipped_at)
            ) / 86400.0
        ) FILTER (
            WHERE shipped_at IS NOT NULL
              AND delivered_at IS NOT NULL
              AND delivered_at >= shipped_at
        ) AS median_delivery_days

    FROM raw.shipments
)
SELECT
    total_shipments,
    delivered_shipments,
    delayed_shipments,
    active_shipments,
    shipments_with_both_timestamps,

    ROUND(
        100.0 * delivered_shipments
        / NULLIF(total_shipments, 0),
        2
    ) AS delivered_shipment_pct,

    ROUND(
        100.0 * delayed_shipments
        / NULLIF(total_shipments, 0),
        2
    ) AS delayed_shipment_pct,

    ROUND(average_delivery_days::NUMERIC, 2)
        AS average_delivery_days,

    ROUND(median_delivery_days::NUMERIC, 2)
        AS median_delivery_days

FROM shipment_metrics;


-- ============================================================
-- 2. SHIPMENT STATUS DISTRIBUTION
-- Dashboard visualization:
--   Donut chart or bar chart.
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
    ) AS shipment_percentage,

    COUNT(*) FILTER (
        WHERE shipped_at IS NOT NULL
          AND delivered_at IS NOT NULL
          AND delivered_at >= shipped_at
    ) AS shipments_with_valid_delivery_duration

FROM raw.shipments
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(shipment_status)), ''),
        'Unknown'
    )
ORDER BY shipment_count DESC;


-- ============================================================
-- 3. MONTHLY SHIPMENT PERFORMANCE
-- Dashboard visualization:
--   Line chart of shipments created, shipped, and delivered.
--
-- Date basis:
--   Shipment creation/cohort month is approximated using
--   the order_date of the associated order.
-- Grain: one row per order month.
-- ============================================================

SELECT
    DATE_TRUNC('month', o.order_date)::DATE AS order_month,

    COUNT(s.shipment_id) AS shipment_count,

    COUNT(s.shipment_id) FILTER (
        WHERE LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delivered'
    ) AS delivered_shipments,

    COUNT(s.shipment_id) FILTER (
        WHERE LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delayed'
    ) AS delayed_shipments,

    COUNT(s.shipment_id) FILTER (
        WHERE s.shipped_at IS NOT NULL
    ) AS shipments_with_shipped_timestamp,

    COUNT(s.shipment_id) FILTER (
        WHERE s.delivered_at IS NOT NULL
    ) AS shipments_with_delivered_timestamp

FROM raw.shipments s
INNER JOIN raw.orders o
    ON o.order_id = s.order_id
WHERE o.order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', o.order_date)::DATE
ORDER BY order_month;


-- ============================================================
-- 4. DELIVERY DURATION BY SHIPPING METHOD
-- Dashboard visualization:
--   Bar chart comparing average and median delivery days.
-- Grain: one row per shipping method.
--
-- Only shipments with valid shipped and delivered timestamps
-- are included in completed delivery duration metrics.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(s.shipping_method), ''),
        'Unknown'
    ) AS shipping_method,

    COUNT(*) AS total_shipments,

    COUNT(*) FILTER (
        WHERE s.shipped_at IS NOT NULL
          AND s.delivered_at IS NOT NULL
          AND s.delivered_at >= s.shipped_at
    ) AS completed_valid_deliveries,

    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (s.delivered_at - s.shipped_at))
            / 86400.0
        ) FILTER (
            WHERE s.shipped_at IS NOT NULL
              AND s.delivered_at IS NOT NULL
              AND s.delivered_at >= s.shipped_at
        )::NUMERIC,
        2
    ) AS average_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(
                EPOCH FROM (s.delivered_at - s.shipped_at)
            ) / 86400.0
        ) FILTER (
            WHERE s.shipped_at IS NOT NULL
              AND s.delivered_at IS NOT NULL
              AND s.delivered_at >= s.shipped_at
        )::NUMERIC,
        2
    ) AS median_delivery_days,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delayed'
    ) AS shipments_marked_delayed

FROM raw.shipments s
GROUP BY
    COALESCE(
        NULLIF(TRIM(s.shipping_method), ''),
        'Unknown'
    )
ORDER BY average_delivery_days DESC NULLS LAST;


-- ============================================================
-- 5. DELAYED SHIPMENT INVESTIGATION QUEUE
-- Dashboard visualization:
--   Table of delayed shipments and recommended actions.
-- Grain: one row per shipment requiring attention.
--
-- Provisional rule:
--   - Status is explicitly marked delayed; or
--   - Shipped more than seven days ago and not yet delivered.
-- ============================================================

WITH reference_date AS (
    SELECT
        COALESCE(MAX(order_date)::DATE, CURRENT_DATE) AS as_of_date
    FROM raw.orders
)
SELECT
    s.shipment_id,
    s.order_id,
    o.customer_id,
    c.customer_name,
    o.order_date,

    s.shipping_method,
    s.shipment_status,
    s.shipped_at,
    s.delivered_at,

    rd.as_of_date,

    CASE
        WHEN s.shipped_at IS NOT NULL
         AND s.delivered_at IS NULL
        THEN rd.as_of_date - s.shipped_at::DATE
        ELSE NULL
    END AS days_since_shipped,

    CASE
        WHEN LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delayed'
            THEN 'Investigate shipment marked delayed'
        WHEN s.shipped_at IS NOT NULL
         AND s.delivered_at IS NULL
         AND rd.as_of_date - s.shipped_at::DATE > 7
            THEN 'Investigate shipment exceeding 7-day threshold'
        ELSE 'Review shipment'
    END AS recommended_action

FROM raw.shipments s
LEFT JOIN raw.orders o
    ON o.order_id = s.order_id
LEFT JOIN raw.customers c
    ON c.customer_id = o.customer_id
CROSS JOIN reference_date rd
WHERE LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delayed'
   OR (
        s.shipped_at IS NOT NULL
        AND s.delivered_at IS NULL
        AND rd.as_of_date - s.shipped_at::DATE > 7
   )
ORDER BY
    s.shipped_at ASC NULLS FIRST,
    s.shipment_id;


-- ============================================================
-- 6. DELIVERY PERFORMANCE BY LOCATION
-- Dashboard visualization:
--   Ranked bar chart or location table.
-- Grain: one row per delivery state and city.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(delivery_state), ''),
        'Unknown'
    ) AS delivery_state,

    COALESCE(
        NULLIF(TRIM(delivery_city), ''),
        'Unknown'
    ) AS delivery_city,

    COUNT(*) AS shipment_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delivered'
    ) AS delivered_shipments,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delayed'
    ) AS delayed_shipments,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delayed'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS delayed_shipment_pct,

    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (delivered_at - shipped_at))
            / 86400.0
        ) FILTER (
            WHERE shipped_at IS NOT NULL
              AND delivered_at IS NOT NULL
              AND delivered_at >= shipped_at
        )::NUMERIC,
        2
    ) AS average_delivery_days

FROM raw.shipments
GROUP BY
    COALESCE(
        NULLIF(TRIM(delivery_state), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(TRIM(delivery_city), ''),
        'Unknown'
    )
ORDER BY delayed_shipments DESC, shipment_count DESC;


-- ============================================================
-- 7. ORDER AND SHIPMENT STATUS CONSISTENCY
-- Dashboard visualization:
--   Exception table.
-- Grain: one row per order-shipment pair with a potential issue.
--
-- These are diagnostic rules, not definitive proof of error.
-- ============================================================

SELECT
    o.order_id,
    o.order_status,

    s.shipment_id,
    s.shipment_status,
    s.shipped_at,
    s.delivered_at,

    CASE
        WHEN s.shipment_id IS NULL
         AND LOWER(TRIM(COALESCE(o.order_status, '')))
             IN ('shipped', 'delivered')
            THEN 'Order shipped/delivered without shipment record'

        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'delivered'
         AND LOWER(TRIM(COALESCE(s.shipment_status, ''))) <> 'delivered'
            THEN 'Delivered order with non-delivered shipment status'

        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'shipped'
         AND s.shipped_at IS NULL
            THEN 'Shipped order without shipped timestamp'

        WHEN LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delivered'
         AND s.delivered_at IS NULL
            THEN 'Delivered shipment without delivered timestamp'

        WHEN LOWER(TRIM(COALESCE(o.order_status, ''))) = 'cancelled'
         AND LOWER(TRIM(COALESCE(s.shipment_status, '')))
             IN ('shipped', 'in transit', 'in_transit', 'delivered')
            THEN 'Cancelled order has active/completed shipment'

        ELSE 'Review'
    END AS consistency_issue

FROM raw.orders o
LEFT JOIN raw.shipments s
    ON s.order_id = o.order_id
WHERE (
        s.shipment_id IS NULL
        AND LOWER(TRIM(COALESCE(o.order_status, '')))
            IN ('shipped', 'delivered')
      )
   OR (
        LOWER(TRIM(COALESCE(o.order_status, ''))) = 'delivered'
        AND LOWER(TRIM(COALESCE(s.shipment_status, ''))) <> 'delivered'
      )
   OR (
        LOWER(TRIM(COALESCE(o.order_status, ''))) = 'shipped'
        AND s.shipped_at IS NULL
      )
   OR (
        LOWER(TRIM(COALESCE(s.shipment_status, ''))) = 'delivered'
        AND s.delivered_at IS NULL
      )
   OR (
        LOWER(TRIM(COALESCE(o.order_status, ''))) = 'cancelled'
        AND LOWER(TRIM(COALESCE(s.shipment_status, '')))
            IN ('shipped', 'in transit', 'in_transit', 'delivered')
      )
ORDER BY o.order_id, s.shipment_id;


-- ============================================================
-- 8. SHIPMENT TIMESTAMP VALIDATION
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per shipment with a timestamp issue.
-- ============================================================

SELECT
    shipment_id,
    order_id,
    shipment_status,
    shipped_at,
    delivered_at,

    CASE
        WHEN shipped_at IS NOT NULL
         AND delivered_at IS NOT NULL
         AND delivered_at < shipped_at
            THEN 'Delivered before shipped timestamp'

        WHEN LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delivered'
         AND delivered_at IS NULL
            THEN 'Delivered status without delivery timestamp'

        WHEN LOWER(TRIM(COALESCE(shipment_status, '')))
             IN ('shipped', 'in transit', 'in_transit')
         AND shipped_at IS NULL
            THEN 'Shipped/in-transit status without shipped timestamp'

        WHEN shipped_at IS NOT NULL
         AND updated_at IS NOT NULL
         AND updated_at < shipped_at
            THEN 'Updated timestamp predates shipped timestamp'

        WHEN delivered_at IS NOT NULL
         AND updated_at IS NOT NULL
         AND updated_at < delivered_at
            THEN 'Updated timestamp predates delivered timestamp'

        ELSE 'Review'
    END AS timestamp_issue

FROM raw.shipments
WHERE (
        shipped_at IS NOT NULL
        AND delivered_at IS NOT NULL
        AND delivered_at < shipped_at
      )
   OR (
        LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delivered'
        AND delivered_at IS NULL
      )
   OR (
        LOWER(TRIM(COALESCE(shipment_status, '')))
            IN ('shipped', 'in transit', 'in_transit')
        AND shipped_at IS NULL
      )
   OR (
        shipped_at IS NOT NULL
        AND updated_at IS NOT NULL
        AND updated_at < shipped_at
      )
   OR (
        delivered_at IS NOT NULL
        AND updated_at IS NOT NULL
        AND updated_at < delivered_at
      )
ORDER BY shipment_id;


-- ============================================================
-- 9. SHIPMENT RECORDS WITHOUT VALID ORDER REFERENCES
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per orphaned shipment.
-- ============================================================

SELECT
    s.shipment_id,
    s.order_id,
    s.shipping_method,
    s.shipment_status,
    s.shipped_at,
    s.delivered_at

FROM raw.shipments s
LEFT JOIN raw.orders o
    ON o.order_id = s.order_id
WHERE s.order_id IS NULL
   OR o.order_id IS NULL
ORDER BY s.shipment_id;


-- ============================================================
-- 10. SHIPPING METHOD AND STATUS PERFORMANCE
-- Dashboard visualization:
--   Stacked bar chart or cross-tab table.
-- Grain: one row per shipping method and shipment status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(shipping_method), ''),
        'Unknown'
    ) AS shipping_method,

    COALESCE(
        NULLIF(INITCAP(TRIM(shipment_status)), ''),
        'Unknown'
    ) AS shipment_status,

    COUNT(*) AS shipment_count,

    COUNT(*) FILTER (
        WHERE shipped_at IS NOT NULL
          AND delivered_at IS NOT NULL
          AND delivered_at >= shipped_at
    ) AS valid_completed_delivery_count,

    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (delivered_at - shipped_at))
            / 86400.0
        ) FILTER (
            WHERE shipped_at IS NOT NULL
              AND delivered_at IS NOT NULL
              AND delivered_at >= shipped_at
        )::NUMERIC,
        2
    ) AS average_delivery_days

FROM raw.shipments
GROUP BY
    COALESCE(
        NULLIF(TRIM(shipping_method), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(shipment_status)), ''),
        'Unknown'
    )
ORDER BY shipping_method, shipment_count DESC;


-- ============================================================
-- 11. SHIPPING DATA QUALITY SUMMARY
-- Dashboard visualization:
--   KPI cards for shipment completeness and timestamp validity.
-- Grain: one row for the entire dataset.
-- ============================================================

SELECT
    COUNT(*) AS total_shipments,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS shipments_missing_order_id,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(shipping_method), '') IS NULL
    ) AS shipments_missing_shipping_method,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(shipment_status), '') IS NULL
    ) AS shipments_missing_status,

    COUNT(*) FILTER (
        WHERE shipped_at IS NULL
    ) AS shipments_missing_shipped_timestamp,

    COUNT(*) FILTER (
        WHERE delivered_at IS NULL
    ) AS shipments_missing_delivered_timestamp,

    COUNT(*) FILTER (
        WHERE shipped_at IS NOT NULL
          AND delivered_at IS NOT NULL
          AND delivered_at < shipped_at
    ) AS shipments_with_invalid_timestamp_order,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(delivery_city), '') IS NULL
    ) AS shipments_missing_delivery_city,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(delivery_state), '') IS NULL
    ) AS shipments_missing_delivery_state,

    COUNT(*) FILTER (
        WHERE ingested_at IS NULL
    ) AS shipments_missing_ingestion_timestamp

FROM raw.shipments;


-- ============================================================
-- 12. SHIPPING EXCEPTION COUNTS
-- Dashboard visualization:
--   Bar chart or table of shipping exceptions.
-- Grain: one row per exception category.
-- ============================================================

SELECT
    'Shipments marked delayed' AS exception_category,
    COUNT(*)::BIGINT AS exception_count
FROM raw.shipments
WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delayed'

UNION ALL

SELECT
    'Delivered status without delivery timestamp',
    COUNT(*)::BIGINT
FROM raw.shipments
WHERE LOWER(TRIM(COALESCE(shipment_status, ''))) = 'delivered'
  AND delivered_at IS NULL

UNION ALL

SELECT
    'Shipped/in-transit status without shipped timestamp',
    COUNT(*)::BIGINT
FROM raw.shipments
WHERE LOWER(TRIM(COALESCE(shipment_status, '')))
          IN ('shipped', 'in transit', 'in_transit')
  AND shipped_at IS NULL

UNION ALL

SELECT
    'Delivery timestamp earlier than shipped timestamp',
    COUNT(*)::BIGINT
FROM raw.shipments
WHERE shipped_at IS NOT NULL
  AND delivered_at IS NOT NULL
  AND delivered_at < shipped_at

UNION ALL

SELECT
    'Shipments missing order references',
    COUNT(*)::BIGINT
FROM raw.shipments s
LEFT JOIN raw.orders o
    ON o.order_id = s.order_id
WHERE s.order_id IS NULL
   OR o.order_id IS NULL

ORDER BY exception_count DESC, exception_category;


-- ============================================================
-- END OF shipping_performance_analysis.sql
-- ============================================================
