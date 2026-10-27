
/*
    Analysis: Return Analysis

    Purpose:
      1. Summarize returns by month, status, and reason.
      2. Calculate returned quantities and refund amounts.
      3. Identify invalid quantities and refund data.
      4. Analyze approved returns and refunds.
      5. Compare monthly return counts with the previous month.

    Sources:
      gold.fact_returns
      gold.fact_order_items

    Grain:
      One row per month, return status, and return reason.

    Notes:
      - Each source return record is counted once.
      - Refund totals are aggregated from fact_returns.
      - Return counts are not the same as returned order counts.
*/

WITH return_base AS (

    SELECT
        return_id,
        order_item_id,
        return_date_key,
        return_reason,
        return_status,
        return_status_group,
        return_quantity,
        refund_amount,
        refund_per_unit,
        is_return_approved,
        has_refund,
        has_invalid_return_quantity,
        update_delay_hours

    FROM gold.fact_returns
),

monthly_returns AS (

    SELECT
        DATE_TRUNC(
            'month',
            TO_DATE(return_date_key::TEXT, 'YYYYMMDD')
        )::DATE AS return_month,

        COALESCE(
            NULLIF(TRIM(return_status), ''),
            'Unknown'
        ) AS return_status,

        COALESCE(
            NULLIF(TRIM(return_reason), ''),
            'Unknown'
        ) AS return_reason,

        COUNT(*) AS return_count,

        COUNT(DISTINCT order_item_id) AS affected_order_item_count,

        SUM(return_quantity) AS total_returned_quantity,

        SUM(refund_amount) AS total_refund_amount,

        AVG(refund_amount) AS average_refund_amount,

        AVG(refund_per_unit) AS average_refund_per_unit,

        COUNT(*) FILTER (
            WHERE is_return_approved IS TRUE
        ) AS approved_return_count,

        COUNT(*) FILTER (
            WHERE is_return_approved IS FALSE
        ) AS unapproved_return_count,

        COUNT(*) FILTER (
            WHERE has_refund IS TRUE
        ) AS returns_with_refund_count,

        COUNT(*) FILTER (
            WHERE has_refund IS FALSE
        ) AS returns_without_refund_count,

        COUNT(*) FILTER (
            WHERE has_invalid_return_quantity IS TRUE
        ) AS invalid_return_quantity_count,

        COUNT(*) FILTER (
            WHERE return_quantity < 0
        ) AS negative_return_quantity_count,

        COUNT(*) FILTER (
            WHERE refund_amount < 0
        ) AS negative_refund_count,

        COUNT(*) FILTER (
            WHERE refund_amount IS NULL
        ) AS missing_refund_count,

        AVG(update_delay_hours) AS average_update_delay_hours

    FROM return_base

    WHERE return_date_key IS NOT NULL

    GROUP BY
        1,
        2,
        3
),

return_trends AS (

    SELECT
        return_month,
        return_status,
        return_reason,
        return_count,
        affected_order_item_count,
        total_returned_quantity,
        total_refund_amount,
        average_refund_amount,
        average_refund_per_unit,
        approved_return_count,
        unapproved_return_count,
        returns_with_refund_count,
        returns_without_refund_count,
        invalid_return_quantity_count,
        negative_return_quantity_count,
        negative_refund_count,
        missing_refund_count,
        average_update_delay_hours,

        LAG(return_count) OVER (
            PARTITION BY return_status, return_reason
            ORDER BY return_month
        ) AS previous_month_return_count,

        LAG(return_month) OVER (
            PARTITION BY return_status, return_reason
            ORDER BY return_month
        ) AS previous_return_month

    FROM monthly_returns
),

return_growth AS (

    SELECT
        return_month,
        return_status,
        return_reason,
        return_count,
        affected_order_item_count,
        total_returned_quantity,
        total_refund_amount,
        average_refund_amount,
        average_refund_per_unit,
        approved_return_count,
        unapproved_return_count,
        returns_with_refund_count,
        returns_without_refund_count,
        invalid_return_quantity_count,
        negative_return_quantity_count,
        negative_refund_count,
        missing_refund_count,
        average_update_delay_hours,
        previous_month_return_count,

        CASE
            WHEN previous_return_month =
                 (return_month - INTERVAL '1 month')::DATE
            THEN return_count - previous_month_return_count
            ELSE NULL
        END AS mom_return_count_change,

        CASE
            WHEN previous_return_month =
                 (return_month - INTERVAL '1 month')::DATE
             AND previous_month_return_count <> 0
            THEN
                (
                    (
                        return_count - previous_month_return_count
                    )::NUMERIC
                    / NULLIF(previous_month_return_count, 0)
                ) * 100
            ELSE NULL
        END AS mom_return_count_growth_pct

    FROM return_trends
)

SELECT
    return_month,
    return_status,
    return_reason,

    return_count,
    affected_order_item_count,
    total_returned_quantity,

    total_refund_amount,
    average_refund_amount,
    average_refund_per_unit,

    approved_return_count,
    unapproved_return_count,
    returns_with_refund_count,
    returns_without_refund_count,

    invalid_return_quantity_count,
    negative_return_quantity_count,
    negative_refund_count,
    missing_refund_count,

    average_update_delay_hours,

    previous_month_return_count,
    mom_return_count_change,
    mom_return_count_growth_pct,

    ROUND(
        100.0 * approved_return_count
        / NULLIF(
            approved_return_count + unapproved_return_count,
            0
        ),
        2
    ) AS approval_rate_pct,

    ROUND(
        100.0 * returns_with_refund_count
        / NULLIF(return_count, 0),
        2
    ) AS refund_coverage_pct

FROM return_growth

ORDER BY
    return_month,
    return_count DESC,
    return_status,
    return_reason;
