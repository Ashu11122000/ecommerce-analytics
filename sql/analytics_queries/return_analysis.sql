
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: return_analysis.sql
-- Purpose:
--   Analyze product returns, refund amounts, return reasons,
--   return outcomes, and return-related data quality.
--
-- Target personas:
--   Returns operations, customer experience, finance analysts,
--   product and business leadership.
--
-- Source tables:
--   raw.returns
--   raw.order_items
--   raw.orders
--   raw.products
--   raw.customers
--
-- Business questions:
--   1. How many return records exist?
--   2. What is the recorded refund amount?
--   3. Which return reasons occur most frequently?
--   4. Which products have the most returned units?
--   5. How do return statuses change over time?
--   6. What proportion of orders have return records?
--   7. Are returned quantities greater than ordered quantities?
--   8. Which return records require investigation?
--
-- Assumptions:
--   - A return record represents a return event or line-level
--     return record, not necessarily a distinct returned order.
--   - Refund amounts are summed as recorded in raw.returns.
--   - Return statuses are compared case-insensitively.
--   - Return records are not assumed to be approved or completed
--     unless their status explicitly indicates this.
--   - Return rate and refund rate are different metrics.
--   - No return rate is interpreted as a causal measure of
--     product quality or customer dissatisfaction.
--
-- All queries are read-only.
-- ============================================================


-- ============================================================
-- 1. RETURN KPI SUMMARY
-- Dashboard visualization:
--   KPI cards for return records, returned units, refunds,
--   and distinct orders affected by returns.
-- Grain: one row for the entire dataset.
-- ============================================================

SELECT
    COUNT(*) AS total_return_records,

    COUNT(DISTINCT oi.order_id) AS distinct_orders_with_returns,

    COUNT(DISTINCT r.order_item_id) AS distinct_order_items_with_returns,

    COALESCE(SUM(r.return_quantity), 0) AS total_recorded_returned_units,

    ROUND(
        COALESCE(SUM(r.refund_amount), 0)::NUMERIC,
        2
    ) AS total_recorded_refund_amount,

    ROUND(
        AVG(r.refund_amount)::NUMERIC,
        2
    ) AS average_refund_per_return_record,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(r.return_status, '')))
              IN ('requested', 'approved')
    ) AS open_return_records,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(r.return_status, ''))) = 'completed'
    ) AS completed_return_records,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(r.return_status, ''))) = 'rejected'
    ) AS rejected_return_records

FROM raw.returns r
LEFT JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id;


-- ============================================================
-- 2. RETURN STATUS DISTRIBUTION
-- Dashboard visualization:
--   Donut chart or bar chart by return status.
-- Grain: one row per normalized return status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(return_status)), ''),
        'Unknown'
    ) AS return_status,

    COUNT(*) AS return_record_count,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS percentage_of_return_records,

    COALESCE(SUM(return_quantity), 0) AS returned_units,

    ROUND(
        COALESCE(SUM(refund_amount), 0)::NUMERIC,
        2
    ) AS recorded_refund_amount

FROM raw.returns
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(return_status)), ''),
        'Unknown'
    )
ORDER BY return_record_count DESC;


-- ============================================================
-- 3. RETURN REASONS
-- Dashboard visualization:
--   Horizontal bar chart of return reasons.
-- Grain: one row per normalized return reason.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(return_reason)), ''),
        'Unknown'
    ) AS return_reason,

    COUNT(*) AS return_record_count,

    COALESCE(SUM(return_quantity), 0) AS returned_units,

    ROUND(
        COALESCE(SUM(refund_amount), 0)::NUMERIC,
        2
    ) AS recorded_refund_amount,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS share_of_return_records_pct

FROM raw.returns
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(return_reason)), ''),
        'Unknown'
    )
ORDER BY return_record_count DESC, recorded_refund_amount DESC;


-- ============================================================
-- 4. MONTHLY RETURN TREND
-- Dashboard visualization:
--   Line chart showing return records, units, and refunds.
-- Grain: one row per return month.
-- ============================================================

SELECT
    DATE_TRUNC('month', return_date)::DATE AS return_month,

    COUNT(*) AS return_record_count,

    COUNT(DISTINCT order_item_id) AS distinct_order_items_returned,

    COALESCE(SUM(return_quantity), 0) AS returned_units,

    ROUND(
        COALESCE(SUM(refund_amount), 0)::NUMERIC,
        2
    ) AS recorded_refund_amount,

    ROUND(
        AVG(refund_amount)::NUMERIC,
        2
    ) AS average_refund_per_return_record

FROM raw.returns
WHERE return_date IS NOT NULL
GROUP BY DATE_TRUNC('month', return_date)::DATE
ORDER BY return_month;


-- ============================================================
-- 5. MONTH-OVER-MONTH REFUND CHANGE
-- Dashboard visualization:
--   Line chart or KPI table for monthly refund movement.
-- Grain: one row per month with return records.
--
-- Note:
--   LAG compares the previous observed return month.
--   Months without return records are not automatically added.
-- ============================================================

WITH monthly_refunds AS (
    SELECT
        DATE_TRUNC('month', return_date)::DATE AS return_month,
        SUM(refund_amount)::NUMERIC AS refund_amount
    FROM raw.returns
    WHERE return_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', return_date)::DATE
),
refund_comparison AS (
    SELECT
        return_month,
        refund_amount,
        LAG(refund_amount) OVER (
            ORDER BY return_month
        ) AS previous_month_refund_amount
    FROM monthly_refunds
)
SELECT
    return_month,

    ROUND(refund_amount, 2) AS refund_amount,

    ROUND(previous_month_refund_amount, 2)
        AS previous_month_refund_amount,

    ROUND(
        refund_amount - previous_month_refund_amount,
        2
    ) AS refund_amount_change,

    ROUND(
        100.0 * (
            refund_amount - previous_month_refund_amount
        ) / NULLIF(previous_month_refund_amount, 0),
        2
    ) AS refund_growth_pct

FROM refund_comparison
ORDER BY return_month;


-- ============================================================
-- 6. RETURN RATE BY ORDER MONTH
-- Dashboard visualization:
--   Line chart showing the percentage of orders with return
--   records, grouped by the original order month.
--
-- Definition:
--   Distinct orders with at least one return record divided by
--   distinct non-cancelled orders in the same order month.
--
-- Important:
--   This is a cohort-based observed return rate. Recent order
--   months may be incomplete because returns can happen later.
-- Grain: one row per order month.
-- ============================================================

WITH eligible_orders AS (
    SELECT
        order_id,
        DATE_TRUNC('month', order_date)::DATE AS order_month
    FROM raw.orders
    WHERE order_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(order_status, ''))) <> 'cancelled'
),
orders_with_returns AS (
    SELECT DISTINCT
        oi.order_id
    FROM raw.returns r
    INNER JOIN raw.order_items oi
        ON oi.order_item_id = r.order_item_id
)
SELECT
    eo.order_month,

    COUNT(*) AS eligible_order_count,

    COUNT(*) FILTER (
        WHERE owr.order_id IS NOT NULL
    ) AS orders_with_return_records,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE owr.order_id IS NOT NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS order_return_rate_pct

FROM eligible_orders eo
LEFT JOIN orders_with_returns owr
    ON owr.order_id = eo.order_id
GROUP BY eo.order_month
ORDER BY eo.order_month;


-- ============================================================
-- 7. PRODUCT RETURN PERFORMANCE
-- Dashboard visualization:
--   Ranked table or bar chart of products by returned units.
-- Grain: one row per product.
--
-- Note:
--   This ranks products by recorded returned units. It does not
--   establish a product return rate without a compatible
--   denominator for units sold.
-- ============================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,

    COUNT(DISTINCT r.return_id) AS return_record_count,

    COUNT(DISTINCT oi.order_id) AS affected_order_count,

    COALESCE(SUM(r.return_quantity), 0) AS returned_units,

    ROUND(
        COALESCE(SUM(r.refund_amount), 0)::NUMERIC,
        2
    ) AS recorded_refund_amount

FROM raw.returns r
INNER JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand
ORDER BY returned_units DESC, recorded_refund_amount DESC;


-- ============================================================
-- 8. RETURN REASONS BY PRODUCT CATEGORY
-- Dashboard visualization:
--   Stacked bar chart or heatmap.
-- Grain: one row per category and return reason.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(p.category), ''),
        'Unknown'
    ) AS product_category,

    COALESCE(
        NULLIF(INITCAP(TRIM(r.return_reason)), ''),
        'Unknown'
    ) AS return_reason,

    COUNT(*) AS return_record_count,

    COALESCE(SUM(r.return_quantity), 0) AS returned_units,

    ROUND(
        COALESCE(SUM(r.refund_amount), 0)::NUMERIC,
        2
    ) AS recorded_refund_amount

FROM raw.returns r
INNER JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
GROUP BY
    COALESCE(
        NULLIF(TRIM(p.category), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(r.return_reason)), ''),
        'Unknown'
    )
ORDER BY returned_units DESC, product_category, return_reason;


-- ============================================================
-- 9. RETURN AND ORDER DETAIL
-- Dashboard visualization:
--   Drill-through table for return investigations.
-- Grain: one row per return record.
-- ============================================================

SELECT
    r.return_id,
    r.return_date,
    r.return_status,
    r.return_reason,
    r.return_quantity,
    r.refund_amount,

    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity AS ordered_quantity,
    oi.unit_price,
    oi.line_total,

    p.product_name,
    p.category,

    o.customer_id,
    c.customer_name,
    o.order_date,
    o.order_status,
    o.total_amount AS order_total,

    CASE
        WHEN oi.order_item_id IS NULL
            THEN 'Return references missing order item'
        WHEN r.return_quantity IS NULL
            THEN 'Missing return quantity'
        WHEN r.return_quantity <= 0
            THEN 'Non-positive return quantity'
        WHEN oi.quantity IS NOT NULL
         AND r.return_quantity > oi.quantity
            THEN 'Return quantity exceeds ordered quantity'
        WHEN r.refund_amount IS NULL
            THEN 'Missing refund amount'
        WHEN r.refund_amount < 0
            THEN 'Negative refund amount'
        WHEN NULLIF(TRIM(r.return_status), '') IS NULL
            THEN 'Missing return status'
        ELSE 'No basic exception detected'
    END AS return_review_status

FROM raw.returns r
LEFT JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id
LEFT JOIN raw.orders o
    ON o.order_id = oi.order_id
LEFT JOIN raw.customers c
    ON c.customer_id = o.customer_id
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
ORDER BY r.return_date DESC NULLS LAST, r.return_id;


-- ============================================================
-- 10. RETURN QUANTITY VALIDATION
-- Purpose:
--   Identify return records whose quantity is missing,
--   non-positive, or greater than the original item quantity.
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per invalid return record.
-- ============================================================

SELECT
    r.return_id,
    r.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity AS ordered_quantity,
    r.return_quantity,
    r.return_date,
    r.return_status,

    CASE
        WHEN oi.order_item_id IS NULL
            THEN 'Missing referenced order item'
        WHEN r.return_quantity IS NULL
            THEN 'Missing return quantity'
        WHEN r.return_quantity <= 0
            THEN 'Return quantity must be positive'
        WHEN oi.quantity IS NULL
            THEN 'Original ordered quantity is missing'
        WHEN oi.quantity <= 0
            THEN 'Original ordered quantity is invalid'
        WHEN r.return_quantity > oi.quantity
            THEN 'Return quantity exceeds ordered quantity'
        ELSE 'Review'
    END AS validation_issue

FROM raw.returns r
LEFT JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id
WHERE oi.order_item_id IS NULL
   OR r.return_quantity IS NULL
   OR r.return_quantity <= 0
   OR oi.quantity IS NULL
   OR oi.quantity <= 0
   OR r.return_quantity > oi.quantity
ORDER BY r.return_id;


-- ============================================================
-- 11. CUMULATIVE RETURN QUANTITY BY ORDER ITEM
-- Purpose:
--   Check whether the sum of return quantities across multiple
--   return records exceeds the original quantity ordered.
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per affected order item.
-- ============================================================

WITH return_totals AS (
    SELECT
        order_item_id,
        COUNT(*) AS return_record_count,
        SUM(return_quantity) AS cumulative_returned_quantity,
        SUM(refund_amount)::NUMERIC AS cumulative_refund_amount
    FROM raw.returns
    GROUP BY order_item_id
)
SELECT
    rt.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity AS ordered_quantity,
    rt.return_record_count,
    rt.cumulative_returned_quantity,

    ROUND(
        rt.cumulative_refund_amount,
        2
    ) AS cumulative_refund_amount,

    CASE
        WHEN oi.order_item_id IS NULL
            THEN 'Missing referenced order item'
        WHEN oi.quantity IS NULL
            THEN 'Missing ordered quantity'
        WHEN oi.quantity <= 0
            THEN 'Invalid ordered quantity'
        WHEN rt.cumulative_returned_quantity IS NULL
            THEN 'Missing cumulative returned quantity'
        WHEN rt.cumulative_returned_quantity > oi.quantity
            THEN 'Cumulative returns exceed ordered quantity'
        ELSE 'Within ordered quantity'
    END AS validation_status

FROM return_totals rt
LEFT JOIN raw.order_items oi
    ON oi.order_item_id = rt.order_item_id
WHERE oi.order_item_id IS NULL
   OR oi.quantity IS NULL
   OR oi.quantity <= 0
   OR rt.cumulative_returned_quantity IS NULL
   OR rt.cumulative_returned_quantity > oi.quantity
ORDER BY rt.order_item_id;


-- ============================================================
-- 12. REFUND AMOUNT VALIDATION
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per return record with a questionable refund.
--
-- Note:
--   Zero refunds are flagged for review, not automatically
--   classified as invalid. A rejected return may legitimately
--   have a zero refund.
-- ============================================================

SELECT
    return_id,
    order_item_id,
    return_date,
    return_status,
    return_quantity,
    refund_amount,

    CASE
        WHEN refund_amount IS NULL
            THEN 'Missing refund amount'
        WHEN refund_amount < 0
            THEN 'Negative refund amount'
        WHEN refund_amount = 0
            THEN 'Zero refund: verify return outcome'
        ELSE 'Review'
    END AS refund_validation_issue

FROM raw.returns
WHERE refund_amount IS NULL
   OR refund_amount <= 0
ORDER BY return_id;


-- ============================================================
-- 13. RETURN DATE VALIDATION
-- Purpose:
--   Identify returns that predate their original orders or have
--   timestamps inconsistent with the ingestion timestamp.
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per affected return record.
-- ============================================================

SELECT
    r.return_id,
    r.order_item_id,
    oi.order_id,
    o.order_date,
    r.return_date,
    r.ingested_at,

    CASE
        WHEN oi.order_item_id IS NULL
            THEN 'Missing referenced order item'
        WHEN o.order_id IS NULL
            THEN 'Missing referenced order'
        WHEN r.return_date IS NULL
            THEN 'Missing return date'
        WHEN o.order_date IS NOT NULL
         AND r.return_date < o.order_date
            THEN 'Return predates order'
        WHEN r.ingested_at IS NOT NULL
         AND r.return_date IS NOT NULL
         AND r.return_date > r.ingested_at
            THEN 'Return date is later than ingestion timestamp'
        ELSE 'Review'
    END AS date_validation_issue

FROM raw.returns r
LEFT JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id
LEFT JOIN raw.orders o
    ON o.order_id = oi.order_id
WHERE oi.order_item_id IS NULL
   OR o.order_id IS NULL
   OR r.return_date IS NULL
   OR (
        o.order_date IS NOT NULL
        AND r.return_date < o.order_date
   )
   OR (
        r.ingested_at IS NOT NULL
        AND r.return_date IS NOT NULL
        AND r.return_date > r.ingested_at
   )
ORDER BY r.return_date DESC NULLS LAST, r.return_id;


-- ============================================================
-- 14. RETURN STATUS AND REASON DATA QUALITY
-- Purpose:
--   Identify missing or unrecognized return statuses and
--   missing return reasons.
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per affected return record.
-- ============================================================

SELECT
    return_id,
    order_item_id,
    return_date,
    return_status,
    return_reason,
    return_quantity,
    refund_amount,

    CASE
        WHEN NULLIF(TRIM(return_status), '') IS NULL
            THEN 'Missing return status'
        WHEN LOWER(TRIM(return_status)) NOT IN (
            'requested',
            'approved',
            'completed',
            'rejected'
        )
            THEN 'Unrecognized return status'
        WHEN NULLIF(TRIM(return_reason), '') IS NULL
            THEN 'Missing return reason'
        ELSE 'Review'
    END AS data_quality_issue

FROM raw.returns
WHERE NULLIF(TRIM(return_status), '') IS NULL
   OR LOWER(TRIM(return_status)) NOT IN (
        'requested',
        'approved',
        'completed',
        'rejected'
   )
   OR NULLIF(TRIM(return_reason), '') IS NULL
ORDER BY return_id;


-- ============================================================
-- 15. RETURN DATA QUALITY SUMMARY
-- Dashboard visualization:
--   KPI cards for completeness and invalid records.
-- Grain: one row for the entire dataset.
-- ============================================================

SELECT
    COUNT(*) AS total_return_records,

    COUNT(*) FILTER (
        WHERE order_item_id IS NULL
    ) AS returns_missing_order_item_id,

    COUNT(*) FILTER (
        WHERE return_date IS NULL
    ) AS returns_missing_date,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(return_status), '') IS NULL
    ) AS returns_missing_status,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(return_reason), '') IS NULL
    ) AS returns_missing_reason,

    COUNT(*) FILTER (
        WHERE return_quantity IS NULL
    ) AS returns_missing_quantity,

    COUNT(*) FILTER (
        WHERE return_quantity <= 0
    ) AS returns_with_non_positive_quantity,

    COUNT(*) FILTER (
        WHERE refund_amount IS NULL
    ) AS returns_missing_refund_amount,

    COUNT(*) FILTER (
        WHERE refund_amount < 0
    ) AS returns_with_negative_refund_amount,

    COUNT(*) FILTER (
        WHERE ingested_at IS NULL
    ) AS returns_missing_ingestion_timestamp

FROM raw.returns;


-- ============================================================
-- 16. RETURN STATUS BY PRODUCT CATEGORY
-- Dashboard visualization:
--   Stacked bar chart.
-- Grain: one row per product category and return status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(p.category), ''),
        'Unknown'
    ) AS product_category,

    COALESCE(
        NULLIF(INITCAP(TRIM(r.return_status)), ''),
        'Unknown'
    ) AS return_status,

    COUNT(*) AS return_record_count,

    COALESCE(SUM(r.return_quantity), 0) AS returned_units,

    ROUND(
        COALESCE(SUM(r.refund_amount), 0)::NUMERIC,
        2
    ) AS recorded_refund_amount

FROM raw.returns r
INNER JOIN raw.order_items oi
    ON oi.order_item_id = r.order_item_id
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
GROUP BY
    COALESCE(
        NULLIF(TRIM(p.category), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(r.return_status)), ''),
        'Unknown'
    )
ORDER BY product_category, return_record_count DESC;


-- ============================================================
-- END OF return_analysis.sql
-- ============================================================
