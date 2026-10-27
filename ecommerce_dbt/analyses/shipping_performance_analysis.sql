
/*
    Analysis: Shipping Performance Analysis

    Purpose:
      1. Measure shipment volume and delivery performance.
      2. Calculate average delivery time.
      3. Identify delayed and invalid shipments.
      4. Analyze delivery speed and shipping methods.
      5. Compare monthly shipment counts with the previous month.

    Source:
      gold.fact_shipments

    Grain:
      One row per month, shipping method, and shipment status.

    Notes:
      - Shipment counts represent shipment records, not distinct orders.
      - Delivery metrics use available delivery_days values.
      - Shipments without a shipped_date_key are excluded from
        this monthly report.
*/

WITH shipment_base AS (

    SELECT
        shipment_id,
        order_id,
        shipped_date_key,
        shipping_method,
        shipment_status,
        shipment_status_group,
        shipped_at,
        delivered_at,
        delivery_days,
        is_delivered,
        delivery_speed,
        is_delivery_delayed

    FROM gold.fact_shipments
),

monthly_shipping AS (

    SELECT
        DATE_TRUNC(
            'month',
            TO_DATE(shipped_date_key::TEXT, 'YYYYMMDD')
        )::DATE AS shipping_month,

        COALESCE(
            NULLIF(TRIM(shipping_method), ''),
            'Unknown'
        ) AS shipping_method,

        COALESCE(
            NULLIF(TRIM(shipment_status), ''),
            'Unknown'
        ) AS shipment_status,

        COUNT(*) AS shipment_count,

        COUNT(DISTINCT order_id) AS distinct_order_count,

        COUNT(*) FILTER (
            WHERE is_delivered IS TRUE
        ) AS delivered_shipment_count,

        COUNT(*) FILTER (
            WHERE is_delivered IS FALSE
        ) AS undelivered_shipment_count,

        COUNT(*) FILTER (
            WHERE is_delivered IS NULL
        ) AS unknown_delivery_flag_count,

        AVG(delivery_days) FILTER (
            WHERE delivery_days >= 0
        ) AS average_delivery_days,

        MIN(delivery_days) FILTER (
            WHERE delivery_days >= 0
        ) AS minimum_delivery_days,

        MAX(delivery_days) FILTER (
            WHERE delivery_days >= 0
        ) AS maximum_delivery_days,

        COUNT(*) FILTER (
            WHERE is_delivery_delayed IS TRUE
        ) AS delayed_shipment_count,

        COUNT(*) FILTER (
            WHERE delivery_speed = 'Fast'
        ) AS fast_delivery_count,

        COUNT(*) FILTER (
            WHERE delivery_speed = 'Standard'
        ) AS standard_delivery_count,

        COUNT(*) FILTER (
            WHERE delivery_speed = 'Slow'
        ) AS slow_delivery_count,

        COUNT(*) FILTER (
            WHERE delivery_speed = 'Unknown'
        ) AS unknown_delivery_speed_count,

        COUNT(*) FILTER (
            WHERE delivery_speed = 'Invalid'
        ) AS invalid_delivery_speed_count,

        COUNT(*) FILTER (
            WHERE shipped_at IS NULL
        ) AS missing_shipped_timestamp_count,

        COUNT(*) FILTER (
            WHERE is_delivered IS TRUE
              AND delivered_at IS NULL
        ) AS delivered_without_timestamp_count

    FROM shipment_base

    WHERE shipped_date_key IS NOT NULL

    GROUP BY
        1,
        2,
        3
),

shipping_trends AS (

    SELECT
        shipping_month,
        shipping_method,
        shipment_status,
        shipment_count,
        distinct_order_count,
        delivered_shipment_count,
        undelivered_shipment_count,
        unknown_delivery_flag_count,
        average_delivery_days,
        minimum_delivery_days,
        maximum_delivery_days,
        delayed_shipment_count,
        fast_delivery_count,
        standard_delivery_count,
        slow_delivery_count,
        unknown_delivery_speed_count,
        invalid_delivery_speed_count,
        missing_shipped_timestamp_count,
        delivered_without_timestamp_count,

        LAG(shipment_count) OVER (
            PARTITION BY shipping_method, shipment_status
            ORDER BY shipping_month
        ) AS previous_month_shipment_count,

        LAG(shipping_month) OVER (
            PARTITION BY shipping_method, shipment_status
            ORDER BY shipping_month
        ) AS previous_shipping_month

    FROM monthly_shipping
),

shipping_growth AS (

    SELECT
        shipping_month,
        shipping_method,
        shipment_status,
        shipment_count,
        distinct_order_count,
        delivered_shipment_count,
        undelivered_shipment_count,
        unknown_delivery_flag_count,
        average_delivery_days,
        minimum_delivery_days,
        maximum_delivery_days,
        delayed_shipment_count,
        fast_delivery_count,
        standard_delivery_count,
        slow_delivery_count,
        unknown_delivery_speed_count,
        invalid_delivery_speed_count,
        missing_shipped_timestamp_count,
        delivered_without_timestamp_count,
        previous_month_shipment_count,

        CASE
            WHEN previous_shipping_month =
                 (shipping_month - INTERVAL '1 month')::DATE
            THEN shipment_count - previous_month_shipment_count
            ELSE NULL
        END AS mom_shipment_count_change,

        CASE
            WHEN previous_shipping_month =
                 (shipping_month - INTERVAL '1 month')::DATE
             AND previous_month_shipment_count <> 0
            THEN
                (
                    (
                        shipment_count - previous_month_shipment_count
                    )::NUMERIC
                    / NULLIF(previous_month_shipment_count, 0)
                ) * 100
            ELSE NULL
        END AS mom_shipment_count_growth_pct

    FROM shipping_trends
)

SELECT
    shipping_month,
    shipping_method,
    shipment_status,

    shipment_count,
    distinct_order_count,

    delivered_shipment_count,
    undelivered_shipment_count,
    unknown_delivery_flag_count,

    ROUND(average_delivery_days::NUMERIC, 2)
        AS average_delivery_days,

    minimum_delivery_days,
    maximum_delivery_days,

    delayed_shipment_count,

    ROUND(
        100.0 * delayed_shipment_count
        / NULLIF(shipment_count, 0),
        2
    ) AS delayed_shipment_pct,

    ROUND(
        100.0 * delivered_shipment_count
        / NULLIF(
            delivered_shipment_count + undelivered_shipment_count,
            0
        ),
        2
    ) AS delivery_completion_pct,

    fast_delivery_count,
    standard_delivery_count,
    slow_delivery_count,
    unknown_delivery_speed_count,
    invalid_delivery_speed_count,

    missing_shipped_timestamp_count,
    delivered_without_timestamp_count,

    previous_month_shipment_count,
    mom_shipment_count_change,
    mom_shipment_count_growth_pct

FROM shipping_growth

ORDER BY
    shipping_month,
    shipment_count DESC,
    shipping_method,
    shipment_status;
