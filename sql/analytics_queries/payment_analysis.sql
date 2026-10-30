
-- ============================================================
-- E-COMMERCE ANALYTICS
-- File: payment_analysis.sql
-- Purpose:
--   Analyze payment transactions, payment success/failure,
--   payment methods, revenue collection, and reconciliation.
--
-- Target personas:
--   Finance analyst, payment operations team, business leadership.
--
-- Source tables:
--   raw.payments
--   raw.orders
--
-- Business questions:
--   1. How many payments are paid, pending, failed, or refunded?
--   2. Which payment methods are used most frequently?
--   3. What is the total amount recorded by payment status?
--   4. Which transactions need attention?
--   5. Do paid payment totals reconcile with order totals?
--   6. Are there duplicate transaction references or invalid values?
--   7. How are payment outcomes changing over time?

-- Grain:
--   Documented separately for each query.
--
-- All queries are read-only.
-- ============================================================


-- ============================================================
-- 1. PAYMENT KPI SUMMARY
-- Dashboard visualization:
--   KPI cards for total payments, paid, pending, failed,
--   refunded, and total recorded payment amount.
-- Grain: one row for the entire dataset.
-- ============================================================

SELECT
    COUNT(*) AS total_payment_records,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'paid'
    ) AS paid_payment_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'pending'
    ) AS pending_payment_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'failed'
    ) AS failed_payment_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'refunded'
    ) AS refunded_payment_count,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_status), '') IS NULL
    ) AS missing_payment_status_count,

    ROUND(
        COALESCE(SUM(amount), 0)::NUMERIC,
        2
    ) AS total_recorded_payment_amount,

    ROUND(
        COALESCE(
            SUM(amount) FILTER (
                WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'paid'
            ),
            0
        )::NUMERIC,
        2
    ) AS total_paid_amount,

    ROUND(
        COALESCE(
            SUM(amount) FILTER (
                WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'refunded'
            ),
            0
        )::NUMERIC,
        2
    ) AS total_amount_on_refunded_payment_records

FROM raw.payments;


-- ============================================================
-- 2. PAYMENT STATUS DISTRIBUTION
-- Dashboard visualization:
--   Donut chart or bar chart.
-- Grain: one row per normalized payment status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    ) AS payment_status,

    COUNT(*) AS payment_count,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS percentage_of_payment_records,

    ROUND(
        COALESCE(SUM(amount), 0)::NUMERIC,
        2
    ) AS recorded_payment_amount,

    ROUND(
        AVG(amount)::NUMERIC,
        2
    ) AS average_payment_amount

FROM raw.payments
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    )
ORDER BY payment_count DESC;


-- ============================================================
-- 3. PAYMENT METHOD PERFORMANCE
-- Dashboard visualization:
--   Bar chart by payment method.
-- Grain: one row per payment method and payment status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_method)), ''),
        'Unknown'
    ) AS payment_method,

    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    ) AS payment_status,

    COUNT(*) AS payment_count,

    ROUND(
        COALESCE(SUM(amount), 0)::NUMERIC,
        2
    ) AS recorded_payment_amount,

    ROUND(
        AVG(amount)::NUMERIC,
        2
    ) AS average_payment_amount

FROM raw.payments
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_method)), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    )
ORDER BY payment_method, payment_count DESC;


-- ============================================================
-- 4. PAYMENT OUTCOME RATES
-- Dashboard visualization:
--   KPI cards for paid, failed, and pending payment rates.
--
-- Denominator:
--   Payment records with a recognized status of paid, failed,
--   pending, or refunded. Unknown statuses are excluded.
--
-- Grain: one row for the entire dataset.
-- ============================================================

WITH recognized_payments AS (
    SELECT
        LOWER(TRIM(payment_status)) AS normalized_status
    FROM raw.payments
    WHERE LOWER(TRIM(COALESCE(payment_status, '')))
          IN ('paid', 'failed', 'pending', 'refunded')
)
SELECT
    COUNT(*) AS recognized_payment_count,

    COUNT(*) FILTER (
        WHERE normalized_status = 'paid'
    ) AS paid_payment_count,

    COUNT(*) FILTER (
        WHERE normalized_status = 'failed'
    ) AS failed_payment_count,

    COUNT(*) FILTER (
        WHERE normalized_status = 'pending'
    ) AS pending_payment_count,

    COUNT(*) FILTER (
        WHERE normalized_status = 'refunded'
    ) AS refunded_payment_count,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE normalized_status = 'paid'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS paid_payment_rate_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE normalized_status = 'failed'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS failed_payment_rate_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE normalized_status = 'pending'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pending_payment_rate_pct

FROM recognized_payments;


-- ============================================================
-- 5. MONTHLY PAYMENT TREND
-- Dashboard visualization:
--   Line chart for payment counts and recorded amounts.
-- Grain: one row per payment month and payment status.
--
-- Date basis:
--   payment_date, not order_date.
-- ============================================================

SELECT
    DATE_TRUNC('month', payment_date)::DATE AS payment_month,

    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    ) AS payment_status,

    COUNT(*) AS payment_count,

    ROUND(
        COALESCE(SUM(amount), 0)::NUMERIC,
        2
    ) AS recorded_payment_amount

FROM raw.payments
WHERE payment_date IS NOT NULL
GROUP BY
    DATE_TRUNC('month', payment_date)::DATE,
    COALESCE(
        NULLIF(INITCAP(TRIM(payment_status)), ''),
        'Unknown'
    )
ORDER BY payment_month, payment_status;


-- ============================================================
-- 6. MONTH-OVER-MONTH PAID AMOUNT CHANGE
-- Dashboard visualization:
--   Line chart or KPI table showing paid amount growth.
-- Grain: one row per month containing paid payment records.
--
-- Note:
--   This compares observed months. Months without paid
--   transactions are not automatically inserted as zero.
-- ============================================================

WITH monthly_paid_amount AS (
    SELECT
        DATE_TRUNC('month', payment_date)::DATE AS payment_month,
        SUM(amount)::NUMERIC AS paid_amount
    FROM raw.payments
    WHERE payment_date IS NOT NULL
      AND LOWER(TRIM(COALESCE(payment_status, ''))) = 'paid'
      AND amount IS NOT NULL
    GROUP BY DATE_TRUNC('month', payment_date)::DATE
),
comparison AS (
    SELECT
        payment_month,
        paid_amount,
        LAG(paid_amount) OVER (
            ORDER BY payment_month
        ) AS previous_month_paid_amount
    FROM monthly_paid_amount
)
SELECT
    payment_month,
    ROUND(paid_amount, 2) AS paid_amount,
    ROUND(previous_month_paid_amount, 2)
        AS previous_month_paid_amount,

    ROUND(
        paid_amount - previous_month_paid_amount,
        2
    ) AS paid_amount_change,

    ROUND(
        100.0 * (paid_amount - previous_month_paid_amount)
        / NULLIF(previous_month_paid_amount, 0),
        2
    ) AS paid_amount_growth_pct

FROM comparison
ORDER BY payment_month;


-- ============================================================
-- 7. FAILED AND PENDING PAYMENT INVESTIGATION QUEUE
-- Dashboard visualization:
--   Sortable table for payment operations.
-- Grain: one row per payment record requiring attention.
-- ============================================================

SELECT
    p.payment_id,
    p.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.payment_status AS order_payment_status,

    p.payment_date,
    p.payment_method,
    p.payment_status AS transaction_payment_status,
    p.amount,
    p.transaction_reference,

    CASE
        WHEN LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'failed'
            THEN 'Investigate failed transaction'
        WHEN LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'pending'
            THEN 'Check transaction confirmation'
        WHEN p.amount IS NULL
            THEN 'Missing payment amount'
        WHEN p.amount <= 0
            THEN 'Validate non-positive payment amount'
        WHEN NULLIF(TRIM(p.transaction_reference), '') IS NULL
            THEN 'Missing transaction reference'
        ELSE 'Review transaction'
    END AS recommended_action

FROM raw.payments p
LEFT JOIN raw.orders o
    ON o.order_id = p.order_id
WHERE LOWER(TRIM(COALESCE(p.payment_status, '')))
          IN ('failed', 'pending')
   OR p.amount IS NULL
   OR p.amount <= 0
   OR NULLIF(TRIM(p.transaction_reference), '') IS NULL
ORDER BY p.payment_date ASC NULLS FIRST, p.payment_id;


-- ============================================================
-- 8. ORDER-TO-PAID-PAYMENT RECONCILIATION
-- Dashboard visualization:
--   Table of order totals and recorded paid amounts.
-- Grain: one row per order.
--
-- Assumptions:
--   - Only transactions marked 'paid' are included.
--   - Multiple paid transactions are aggregated by order.
--   - Difference = order total - sum of paid payment amounts.
--   - A tolerance of 0.01 is used for rounding.
--   - Partial payments, payment fees, refunds, and split
--     transactions require explicit business rules.
-- ============================================================

WITH paid_payment_totals AS (
    SELECT
        order_id,
        COUNT(*) AS paid_transaction_count,
        SUM(amount)::NUMERIC AS total_paid_amount
    FROM raw.payments
    WHERE LOWER(TRIM(COALESCE(payment_status, ''))) = 'paid'
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.payment_status,

    ROUND(o.total_amount::NUMERIC, 2) AS order_total,

    COALESCE(
        ppt.paid_transaction_count,
        0
    ) AS paid_transaction_count,

    ROUND(
        COALESCE(ppt.total_paid_amount, 0),
        2
    ) AS total_paid_amount,

    ROUND(
        o.total_amount::NUMERIC
        - COALESCE(ppt.total_paid_amount, 0),
        2
    ) AS unpaid_or_overpaid_difference,

    CASE
        WHEN o.total_amount IS NULL
            THEN 'Missing order total'
        WHEN ppt.order_id IS NULL
            THEN 'No paid transaction recorded'
        WHEN ABS(
            o.total_amount::NUMERIC - ppt.total_paid_amount
        ) <= 0.01
            THEN 'Reconciled'
        WHEN ppt.total_paid_amount < o.total_amount
            THEN 'Paid amount below order total'
        ELSE 'Paid amount above order total'
    END AS reconciliation_status

FROM raw.orders o
LEFT JOIN paid_payment_totals ppt
    ON ppt.order_id = o.order_id
ORDER BY
    CASE
        WHEN o.total_amount IS NULL THEN 1
        WHEN ppt.order_id IS NULL THEN 1
        WHEN ABS(
            o.total_amount::NUMERIC - ppt.total_paid_amount
        ) > 0.01 THEN 1
        ELSE 0
    END DESC,
    o.order_id;


-- ============================================================
-- 9. ORDERS WITHOUT A PAYMENT RECORD
-- Dashboard visualization:
--   Exception table.
-- Grain: one row per order without any payment record.
--
-- Note:
--   This identifies missing payment records, not necessarily
--   unpaid orders. Payment collection may occur elsewhere.
-- ============================================================

SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.payment_status,
    o.total_amount

FROM raw.orders o
LEFT JOIN raw.payments p
    ON p.order_id = o.order_id
WHERE p.payment_id IS NULL
ORDER BY o.order_date DESC NULLS LAST, o.order_id;


-- ============================================================
-- 10. PAYMENT AMOUNTS THAT REQUIRE VALIDATION
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per suspicious payment record.
-- ============================================================

SELECT
    payment_id,
    order_id,
    payment_date,
    payment_method,
    payment_status,
    amount,
    transaction_reference,

    CASE
        WHEN amount IS NULL
            THEN 'Missing payment amount'
        WHEN amount < 0
            THEN 'Negative payment amount'
        WHEN amount = 0
            THEN 'Zero payment amount'
        WHEN NULLIF(TRIM(transaction_reference), '') IS NULL
            THEN 'Missing transaction reference'
        ELSE 'Review payment'
    END AS validation_issue

FROM raw.payments
WHERE amount IS NULL
   OR amount <= 0
   OR NULLIF(TRIM(transaction_reference), '') IS NULL
ORDER BY payment_id;


-- ============================================================
-- 11. DUPLICATE TRANSACTION REFERENCES
-- Dashboard visualization:
--   Exception table for possible duplicate references.
-- Grain: one row per non-empty reference appearing more than
-- once, with its associated payment records.
--
-- Note:
--   Duplicate references may be legitimate in some payment
--   systems; verify provider-specific rules before flagging
--   these as confirmed duplicates.
-- ============================================================

WITH duplicate_references AS (
    SELECT
        LOWER(TRIM(transaction_reference)) AS normalized_reference,
        COUNT(*) AS reference_count
    FROM raw.payments
    WHERE NULLIF(TRIM(transaction_reference), '') IS NOT NULL
    GROUP BY LOWER(TRIM(transaction_reference))
    HAVING COUNT(*) > 1
)
SELECT
    dr.normalized_reference,
    dr.reference_count,
    p.payment_id,
    p.order_id,
    p.payment_date,
    p.payment_status,
    p.amount,
    p.transaction_reference

FROM duplicate_references dr
INNER JOIN raw.payments p
    ON LOWER(TRIM(p.transaction_reference)) = dr.normalized_reference
ORDER BY dr.normalized_reference, p.payment_id;


-- ============================================================
-- 12. PAYMENT RECORDS WITH MISSING ORPHANED ORDER REFERENCES
-- Dashboard visualization:
--   Data-quality exception table.
-- Grain: one row per payment with a missing order relationship.
-- ============================================================

SELECT
    p.payment_id,
    p.order_id,
    p.payment_date,
    p.payment_status,
    p.amount,
    p.transaction_reference

FROM raw.payments p
LEFT JOIN raw.orders o
    ON o.order_id = p.order_id
WHERE p.order_id IS NULL
   OR o.order_id IS NULL
ORDER BY p.payment_id;


-- ============================================================
-- 13. PAYMENT STATUS CONSISTENCY CHECK
-- Purpose:
--   Compare order-level payment status with transaction status.
-- Dashboard visualization:
--   Exception table.
-- Grain: one row per order-payment pair.
--
-- This query checks common cases only. Confirm allowed status
-- combinations with the business before treating them as errors.
-- ============================================================

SELECT
    o.order_id,
    o.payment_status AS order_payment_status,
    p.payment_id,
    p.payment_status AS transaction_payment_status,
    p.amount,
    p.payment_date,

    CASE
        WHEN LOWER(TRIM(COALESCE(o.payment_status, '')))
             IN ('paid', 'completed', 'successful')
         AND LOWER(TRIM(COALESCE(p.payment_status, '')))
             IN ('failed', 'pending')
            THEN 'Order marked paid but transaction is failed/pending'

        WHEN LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'failed'
         AND LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'paid'
            THEN 'Order marked failed but transaction is paid'

        WHEN LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'pending'
         AND LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'paid'
            THEN 'Order marked pending but transaction is paid'

        WHEN LOWER(TRIM(COALESCE(o.payment_status, '')))
             IN ('paid', 'completed', 'successful')
         AND p.payment_id IS NULL
            THEN 'Order marked paid but no transaction exists'

        ELSE 'Review'
    END AS consistency_issue

FROM raw.orders o
LEFT JOIN raw.payments p
    ON p.order_id = o.order_id
WHERE (
        LOWER(TRIM(COALESCE(o.payment_status, '')))
            IN ('paid', 'completed', 'successful')
        AND LOWER(TRIM(COALESCE(p.payment_status, '')))
            IN ('failed', 'pending')
      )
   OR (
        LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'failed'
        AND LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'paid'
      )
   OR (
        LOWER(TRIM(COALESCE(o.payment_status, ''))) = 'pending'
        AND LOWER(TRIM(COALESCE(p.payment_status, ''))) = 'paid'
      )
   OR (
        LOWER(TRIM(COALESCE(o.payment_status, '')))
            IN ('paid', 'completed', 'successful')
        AND p.payment_id IS NULL
      )
ORDER BY o.order_id, p.payment_id;


-- ============================================================
-- 14. PAYMENT DATA QUALITY SUMMARY
-- Dashboard visualization:
--   KPI cards for payment data completeness and validity.
-- Grain: one row for the entire dataset.
-- ============================================================

SELECT
    COUNT(*) AS total_payment_records,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS payments_missing_order_id,

    COUNT(*) FILTER (
        WHERE payment_date IS NULL
    ) AS payments_missing_payment_date,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_status), '') IS NULL
    ) AS payments_missing_status,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_method), '') IS NULL
    ) AS payments_missing_method,

    COUNT(*) FILTER (
        WHERE amount IS NULL
    ) AS payments_missing_amount,

    COUNT(*) FILTER (
        WHERE amount < 0
    ) AS payments_with_negative_amount,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(transaction_reference), '') IS NULL
    ) AS payments_missing_transaction_reference,

    COUNT(*) FILTER (
        WHERE updated_at IS NOT NULL
          AND payment_date IS NOT NULL
          AND updated_at < payment_date
    ) AS payments_updated_before_payment_date,

    COUNT(*) FILTER (
        WHERE ingested_at IS NULL
    ) AS payments_missing_ingestion_timestamp

FROM raw.payments;


-- ============================================================
-- 15. PAYMENT STATUS BY ORDER STATUS
-- Dashboard visualization:
--   Stacked bar chart or cross-tab table.
-- Grain: one row per order status and transaction payment status.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(INITCAP(TRIM(o.order_status)), ''),
        'Unknown'
    ) AS order_status,

    COALESCE(
        NULLIF(INITCAP(TRIM(p.payment_status)), ''),
        'Unknown'
    ) AS transaction_payment_status,

    COUNT(*) AS payment_count,

    ROUND(
        COALESCE(SUM(p.amount), 0)::NUMERIC,
        2
    ) AS recorded_payment_amount

FROM raw.payments p
INNER JOIN raw.orders o
    ON o.order_id = p.order_id
GROUP BY
    COALESCE(
        NULLIF(INITCAP(TRIM(o.order_status)), ''),
        'Unknown'
    ),
    COALESCE(
        NULLIF(INITCAP(TRIM(p.payment_status)), ''),
        'Unknown'
    )
ORDER BY order_status, payment_count DESC;


-- ============================================================
-- END OF payment_analysis.sql
-- ============================================================
