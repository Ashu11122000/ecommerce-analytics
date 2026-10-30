Purpose:
    Validate business metrics against the Gold reporting layer.

Gold models:
    gold.fact_order_items
    gold.fact_payments
    gold.fact_returns
    gold.fact_shipments

Validation areas:
    1. Order-item grain and key uniqueness
    2. Sales metrics and data-quality indicators
    3. Order-level reconciliation
    4. Payment metrics
    5. Return and refund metrics
    6. Shipping metrics
    7. Order-item key completeness
    8. Cross-fact metric summary

Important:
    Uses actual column names from the Gold schema.
    Invalid sales rows remain available for auditing.
    Sales-eligible totals use is_valid_for_sales = TRUE.
    Metrics from separate fact tables are aggregated independently.
*/


-- ============================================================
-- 1. ORDER-ITEM GRAIN VALIDATION
-- Expected grain: One row per order item
-- ============================================================

SELECT
    COUNT(*) AS total_order_item_rows,
    COUNT(DISTINCT order_item_id) AS distinct_order_items,

    COUNT(*) - COUNT(DISTINCT order_item_id)
        AS duplicate_order_item_rows,

    COUNT(*) FILTER (
        WHERE order_item_id IS NULL
    ) AS missing_order_item_ids

FROM gold.fact_order_items;


-- ============================================================
-- 2. SALES METRIC VALIDATION
-- Compare all rows with rows eligible for sales reporting.
-- ============================================================

SELECT
    COUNT(*) AS total_order_item_rows,

    COUNT(*) FILTER (
        WHERE is_valid_for_sales IS TRUE
    ) AS valid_for_sales_rows,

    COUNT(*) FILTER (
        WHERE is_valid_for_sales IS FALSE
    ) AS invalid_for_sales_rows,

    COUNT(*) FILTER (
        WHERE is_valid_for_sales IS NULL
    ) AS unknown_sales_validity_rows,

    SUM(quantity) AS total_units_all_rows,

    SUM(quantity) FILTER (
        WHERE is_valid_for_sales IS TRUE
    ) AS valid_sales_units,

    SUM(gross_sales_amount) AS gross_sales_all_rows,

    SUM(net_sales_amount) AS net_sales_all_rows,

    SUM(gross_sales_amount) FILTER (
        WHERE is_valid_for_sales IS TRUE
    ) AS eligible_gross_sales,

    SUM(net_sales_amount) FILTER (
        WHERE is_valid_for_sales IS TRUE
    ) AS eligible_net_sales,

    COUNT(*) FILTER (
        WHERE is_line_total_mismatch IS TRUE
    ) AS line_total_mismatch_rows,

    COUNT(*) FILTER (
        WHERE has_negative_quantity IS TRUE
    ) AS negative_quantity_rows,

    COUNT(*) FILTER (
        WHERE gross_sales_amount IS NULL
    ) AS missing_gross_sales_rows,

    COUNT(*) FILTER (
        WHERE net_sales_amount IS NULL
    ) AS missing_net_sales_rows,

    COUNT(*) FILTER (
        WHERE gross_sales_amount IS NOT NULL
            AND net_sales_amount IS NOT NULL
            AND net_sales_amount > gross_sales_amount
    ) AS rows_where_net_exceeds_gross

FROM gold.fact_order_items;


-- ============================================================
-- 3. ORDER-LEVEL RECONCILIATION
-- Expected grain: One row per order.
-- Sales metrics include only eligible sales rows.
-- ============================================================

WITH order_totals AS (
    SELECT
        order_id,

        COUNT(*) AS eligible_order_item_count,

        SUM(gross_sales_amount) AS gross_sales,

        SUM(net_sales_amount) AS net_sales,

        SUM(quantity) AS units

    FROM gold.fact_order_items

    WHERE is_valid_for_sales IS TRUE
        AND order_id IS NOT NULL

    GROUP BY order_id
)

SELECT
    COUNT(*) AS orders_with_eligible_sales,

    SUM(eligible_order_item_count) AS eligible_order_items,

    SUM(units) AS eligible_units,

    SUM(gross_sales) AS eligible_gross_sales,

    SUM(net_sales) AS eligible_net_sales,

    ROUND(
        SUM(net_sales) / NULLIF(COUNT(*), 0),
        2
    ) AS average_net_sales_per_order

FROM order_totals;


-- ============================================================
-- 4. PAYMENT METRIC VALIDATION
-- Expected grain: One row per payment transaction.
-- ============================================================

SELECT
    COUNT(*) AS payment_transactions,

    COUNT(DISTINCT payment_id) AS distinct_payment_ids,

    COUNT(*) FILTER (
        WHERE payment_id IS NULL
    ) AS missing_payment_ids,

    COUNT(*) FILTER (
        WHERE amount IS NULL
    ) AS missing_payment_amounts,

    COUNT(*) FILTER (
        WHERE amount < 0
    ) AS negative_payment_amounts,

    SUM(amount) AS total_payment_amount,

    COUNT(*) FILTER (
        WHERE is_successful_payment IS TRUE
    ) AS successful_transactions,

    COUNT(*) FILTER (
        WHERE is_successful_payment IS FALSE
    ) AS unsuccessful_transactions,

    COUNT(*) FILTER (
        WHERE is_successful_payment IS NULL
    ) AS unknown_payment_success_rows,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_successful_payment IS TRUE
        ) / NULLIF(
            COUNT(*) FILTER (
                WHERE is_successful_payment IS NOT NULL
            ),
            0
        ),
        2
    ) AS payment_success_rate_pct,

    COUNT(*) FILTER (
        WHERE payment_status IS NULL
    ) AS missing_payment_status_rows,

    COUNT(*) FILTER (
        WHERE has_transaction_reference IS FALSE
    ) AS missing_transaction_reference_rows

FROM gold.fact_payments;


-- ============================================================
-- 5. RETURN AND REFUND VALIDATION
-- Expected grain: One row per return record.
-- ============================================================

SELECT
    COUNT(*) AS return_records,

    COUNT(DISTINCT return_id) AS distinct_return_ids,

    COUNT(*) FILTER (
        WHERE return_id IS NULL
    ) AS missing_return_ids,

    SUM(return_quantity) AS total_returned_units,

    SUM(refund_amount) AS total_refunds,

    COUNT(*) FILTER (
        WHERE refund_amount < 0
    ) AS negative_refund_records,

    COUNT(*) FILTER (
        WHERE refund_amount IS NULL
    ) AS missing_refund_records,

    COUNT(*) FILTER (
        WHERE return_quantity < 0
    ) AS negative_return_quantity_records,

    COUNT(*) FILTER (
        WHERE has_invalid_return_quantity IS TRUE
    ) AS invalid_return_quantity_records,

    COUNT(*) FILTER (
        WHERE has_invalid_return_quantity IS NULL
    ) AS unknown_return_quantity_validity_rows,

    COUNT(*) FILTER (
        WHERE is_return_approved IS TRUE
    ) AS approved_return_records,

    COUNT(*) FILTER (
        WHERE has_refund IS TRUE
    ) AS records_with_refunds

FROM gold.fact_returns;


-- ============================================================
-- 6. SHIPPING METRIC VALIDATION
-- Expected grain: One row per shipment.
-- ============================================================

SELECT
    COUNT(*) AS total_shipments,

    COUNT(DISTINCT shipment_id) AS distinct_shipment_ids,

    COUNT(*) FILTER (
        WHERE shipment_id IS NULL
    ) AS missing_shipment_ids,

    COUNT(*) FILTER (
        WHERE is_delivered IS TRUE
    ) AS delivered_shipments,

    COUNT(*) FILTER (
        WHERE is_delivered IS FALSE
    ) AS not_delivered_shipments,

    COUNT(*) FILTER (
        WHERE is_delivered IS NULL
    ) AS unknown_delivery_status_rows,

    COUNT(*) FILTER (
        WHERE is_delivery_delayed IS TRUE
    ) AS delayed_shipments,

    COUNT(*) FILTER (
        WHERE is_delivery_delayed IS FALSE
    ) AS not_delayed_shipments,

    COUNT(*) FILTER (
        WHERE is_delivery_delayed IS NULL
    ) AS unknown_delay_status_rows,

    COUNT(*) FILTER (
        WHERE delivery_days IS NULL
    ) AS missing_delivery_durations,

    COUNT(*) FILTER (
        WHERE delivery_days < 0
    ) AS negative_delivery_durations,

    ROUND(
        AVG(delivery_days),
        2
    ) AS average_delivery_days_all_shipments,

    ROUND(
        AVG(delivery_days) FILTER (
            WHERE is_delivered IS TRUE
        ),
        2
    ) AS average_delivery_days_for_delivered_shipments,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_delivery_delayed IS TRUE
        ) / NULLIF(
            COUNT(*) FILTER (
                WHERE is_delivery_delayed IS NOT NULL
            ),
            0
        ),
        2
    ) AS delayed_shipment_rate_pct

FROM gold.fact_shipments;


-- ============================================================
-- 7. ORDER-ITEM KEY COMPLETENESS
-- Use actual business key names from the Gold model.
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS missing_order_ids,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
    ) AS missing_customer_ids,

    COUNT(*) FILTER (
        WHERE product_id IS NULL
    ) AS missing_product_ids,

    COUNT(*) FILTER (
        WHERE order_date_key IS NULL
    ) AS missing_order_date_keys,

    COUNT(*) FILTER (
        WHERE order_date IS NULL
    ) AS missing_order_dates

FROM gold.fact_order_items;


-- ============================================================
-- 8. METRIC RECONCILIATION SUMMARY
-- Aggregate each fact independently to prevent join fan-out.
-- Sales values use sales-eligible order-item rows.
-- Payment and return amounts retain their source definitions.
-- ============================================================

WITH sales_metrics AS (
    SELECT
        COUNT(DISTINCT order_id) FILTER (
            WHERE is_valid_for_sales IS TRUE
        ) AS orders_with_eligible_sales,

        SUM(gross_sales_amount) FILTER (
            WHERE is_valid_for_sales IS TRUE
        ) AS eligible_gross_sales,

        SUM(net_sales_amount) FILTER (
            WHERE is_valid_for_sales IS TRUE
        ) AS eligible_net_sales,

        SUM(quantity) FILTER (
            WHERE is_valid_for_sales IS TRUE
        ) AS eligible_units_sold

    FROM gold.fact_order_items
),

payment_metrics AS (
    SELECT
        COUNT(*) AS payment_transactions,

        SUM(amount) AS total_payment_amount,

        COUNT(*) FILTER (
            WHERE is_successful_payment IS TRUE
        ) AS successful_payments,

        COUNT(*) FILTER (
            WHERE is_successful_payment IS NOT NULL
        ) AS payments_with_known_success_status

    FROM gold.fact_payments
),

return_metrics AS (
    SELECT
        COUNT(*) AS return_records,

        SUM(refund_amount) AS total_refunds,

        SUM(return_quantity) AS returned_units,

        COUNT(*) FILTER (
            WHERE is_return_approved IS TRUE
        ) AS approved_return_records

    FROM gold.fact_returns
),

shipping_metrics AS (
    SELECT
        COUNT(*) AS total_shipments,

        COUNT(*) FILTER (
            WHERE is_delivered IS TRUE
        ) AS delivered_shipments,

        COUNT(*) FILTER (
            WHERE is_delivery_delayed IS TRUE
        ) AS delayed_shipments,

        AVG(delivery_days) AS average_delivery_days

    FROM gold.fact_shipments
)

SELECT
    s.orders_with_eligible_sales,
    s.eligible_gross_sales,
    s.eligible_net_sales,
    s.eligible_units_sold,

    p.payment_transactions,
    p.total_payment_amount,
    p.successful_payments,
    p.payments_with_known_success_status,

    r.return_records,
    r.total_refunds,
    r.returned_units,
    r.approved_return_records,

    sh.total_shipments,
    sh.delivered_shipments,
    sh.delayed_shipments,
    ROUND(sh.average_delivery_days, 2)
        AS average_delivery_days

FROM sales_metrics AS s
CROSS JOIN payment_metrics AS p
CROSS JOIN return_metrics AS r
CROSS JOIN shipping_metrics AS sh;
