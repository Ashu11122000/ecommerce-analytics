
/*
    Analysis: Payment Analysis

    Purpose:
      1. Summarize payments by status and payment method.
      2. Calculate successful and unsuccessful payment totals.
      3. Analyze payment amounts and average payment value.
      4. Identify payments with missing references or negative amounts.
      5. Compare monthly payment counts with the previous month.

    Source:
      gold.fact_payments

    Grain:
      One row per month, payment status, and payment method.

    Notes:
      - Uses the Gold fact_payments model.
      - Successful payment amounts are based on is_successful_payment.
      - Payment counts represent payment transactions, not distinct orders.
*/

WITH payment_base AS (

    SELECT
        payment_id,
        order_id,
        payment_date_key,
        payment_method,
        payment_status,
        payment_status_group,
        amount,
        is_successful_payment,
        has_transaction_reference,
        payment_amount_band

    FROM gold.fact_payments
),

monthly_payment_summary AS (

    SELECT
        DATE_TRUNC(
            'month',
            TO_DATE(payment_date_key::TEXT, 'YYYYMMDD')
        )::DATE AS payment_month,

        COALESCE(
            NULLIF(TRIM(payment_status), ''),
            'Unknown'
        ) AS payment_status,

        COALESCE(
            NULLIF(TRIM(payment_method), ''),
            'Unknown'
        ) AS payment_method,

        COUNT(*) AS payment_count,

        COUNT(DISTINCT order_id) AS distinct_order_count,

        COUNT(*) FILTER (
            WHERE is_successful_payment IS TRUE
        ) AS successful_payment_count,

        COUNT(*) FILTER (
            WHERE is_successful_payment IS FALSE
        ) AS unsuccessful_payment_count,

        COUNT(*) FILTER (
            WHERE is_successful_payment IS NULL
        ) AS unknown_success_flag_count,

        SUM(amount) AS total_payment_amount,

        SUM(amount) FILTER (
            WHERE is_successful_payment IS TRUE
        ) AS successful_payment_amount,

        SUM(amount) FILTER (
            WHERE is_successful_payment IS FALSE
        ) AS unsuccessful_payment_amount,

        AVG(amount) AS average_payment_amount,

        COUNT(*) FILTER (
            WHERE amount < 0
        ) AS negative_amount_count,

        COUNT(*) FILTER (
            WHERE amount IS NULL
        ) AS missing_amount_count,

        COUNT(*) FILTER (
            WHERE has_transaction_reference IS FALSE
               OR has_transaction_reference IS NULL
        ) AS missing_reference_count

    FROM payment_base

    WHERE payment_date_key IS NOT NULL

    GROUP BY
        1,
        2,
        3
),

payment_trends AS (

    SELECT
        payment_month,
        payment_status,
        payment_method,
        payment_count,
        distinct_order_count,
        successful_payment_count,
        unsuccessful_payment_count,
        unknown_success_flag_count,
        total_payment_amount,
        successful_payment_amount,
        unsuccessful_payment_amount,
        average_payment_amount,
        negative_amount_count,
        missing_amount_count,
        missing_reference_count,

        LAG(payment_count) OVER (
            PARTITION BY payment_status, payment_method
            ORDER BY payment_month
        ) AS previous_month_payment_count,

        LAG(payment_month) OVER (
            PARTITION BY payment_status, payment_method
            ORDER BY payment_month
        ) AS previous_payment_month

    FROM monthly_payment_summary
),

payment_growth AS (

    SELECT
        payment_month,
        payment_status,
        payment_method,
        payment_count,
        distinct_order_count,
        successful_payment_count,
        unsuccessful_payment_count,
        unknown_success_flag_count,
        total_payment_amount,
        successful_payment_amount,
        unsuccessful_payment_amount,
        average_payment_amount,
        negative_amount_count,
        missing_amount_count,
        missing_reference_count,
        previous_month_payment_count,

        CASE
            WHEN previous_payment_month =
                 (payment_month - INTERVAL '1 month')::DATE
            THEN payment_count - previous_month_payment_count
            ELSE NULL
        END AS mom_payment_count_change,

        CASE
            WHEN previous_payment_month =
                 (payment_month - INTERVAL '1 month')::DATE
             AND previous_month_payment_count <> 0
            THEN
                (
                    (
                        payment_count - previous_month_payment_count
                    )::NUMERIC
                    / NULLIF(previous_month_payment_count, 0)
                ) * 100
            ELSE NULL
        END AS mom_payment_count_growth_pct

    FROM payment_trends
)

SELECT
    payment_month,
    payment_status,
    payment_method,

    payment_count,
    distinct_order_count,

    successful_payment_count,
    unsuccessful_payment_count,
    unknown_success_flag_count,

    total_payment_amount,
    successful_payment_amount,
    unsuccessful_payment_amount,
    average_payment_amount,

    negative_amount_count,
    missing_amount_count,
    missing_reference_count,

    previous_month_payment_count,
    mom_payment_count_change,
    mom_payment_count_growth_pct,

    ROUND(
        100.0 * successful_payment_count
        / NULLIF(
            successful_payment_count + unsuccessful_payment_count,
            0
        ),
        2
    ) AS payment_success_rate_pct

FROM payment_growth

ORDER BY
    payment_month,
    payment_count DESC,
    payment_status,
    payment_method;
