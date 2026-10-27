
-- ============================================================
-- Analysis: customer_analysis
-- Layer: Gold / Analytics
--
-- Purpose:
--   Analyze customer segments, lifecycle stages, purchasing
--   behavior, and customer-level sales measures.
--
-- Output grain:
--   One row per customer_id.
--
-- Sources:
--   dim_customers
--   fact_order_items
--
-- Important assumptions:
--   - Sales measures follow fact_order_items definitions.
--   - net_sales_amount includes tax and subtracts discounts.
--   - Monetary amounts must not be combined across currencies.
--   - Order-item counts are not the same as distinct order counts.
--   - Customer activity is inherited from dim_customers.
-- ============================================================

WITH customer_order_metrics AS (

    -- Step 1: Aggregate order-item data to customer grain
    -- before joining it to the customer dimension.
    SELECT
        f.customer_id,

        COUNT(DISTINCT f.order_id) AS distinct_order_count,

        COUNT(f.order_item_id) AS order_item_count,

        SUM(f.quantity) AS total_units_ordered,

        SUM(f.returned_quantity) AS total_units_returned,

        SUM(f.gross_sales_amount) AS gross_sales_amount,

        SUM(f.net_sales_amount) AS net_sales_amount,

        MIN(f.order_date::DATE) AS first_order_date,

        MAX(f.order_date::DATE) AS most_recent_order_date,

        COUNT(*) FILTER (
            WHERE f.is_line_total_mismatch IS TRUE
        ) AS line_total_mismatch_count,

        COUNT(*) FILTER (
            WHERE f.has_negative_quantity IS TRUE
        ) AS negative_quantity_item_count

    FROM {{ ref('fact_order_items') }} AS f

    WHERE f.customer_id IS NOT NULL

    GROUP BY
        f.customer_id

),

customer_analysis_base AS (

    -- Step 2: Preserve every customer, including those
    -- who have no matching order-item records.
    SELECT
        c.customer_id,
        c.customer_name,
        c.gender,
        c.age_group,
        c.city,
        c.state,
        c.country,
        c.customer_segment,
        c.customer_status_group,
        c.customer_lifecycle_stage,
        c.customer_age,
        c.customer_tenure_days,
        c.is_active_customer,
        c.signup_date,

        COALESCE(
            m.distinct_order_count,
            0
        ) AS distinct_order_count,

        COALESCE(
            m.order_item_count,
            0
        ) AS order_item_count,

        COALESCE(
            m.total_units_ordered,
            0
        ) AS total_units_ordered,

        COALESCE(
            m.total_units_returned,
            0
        ) AS total_units_returned,

        m.gross_sales_amount,
        m.net_sales_amount,

        m.first_order_date,
        m.most_recent_order_date,

        COALESCE(
            m.line_total_mismatch_count,
            0
        ) AS line_total_mismatch_count,

        COALESCE(
            m.negative_quantity_item_count,
            0
        ) AS negative_quantity_item_count

    FROM {{ ref('dim_customers') }} AS c

    LEFT JOIN customer_order_metrics AS m
        ON c.customer_id = m.customer_id

)

-- Step 3: Add customer-level analytical classifications.
SELECT
    customer_id,
    customer_name,
    gender,
    age_group,
    city,
    state,
    country,
    customer_segment,
    customer_status_group,
    customer_lifecycle_stage,
    customer_age,
    customer_tenure_days,
    is_active_customer,
    signup_date,

    distinct_order_count,
    order_item_count,
    total_units_ordered,
    total_units_returned,

    gross_sales_amount,
    net_sales_amount,

    first_order_date,
    most_recent_order_date,

    -- Identify whether the customer has any recorded orders.
    CASE
        WHEN distinct_order_count = 0
            THEN 'No Recorded Orders'
        ELSE 'Has Recorded Orders'
    END AS purchase_status,

    -- Calculate the calendar-day difference between
    -- signup and first recorded order.
    CASE
        WHEN signup_date IS NOT NULL
         AND first_order_date IS NOT NULL
         AND first_order_date >= signup_date
        THEN first_order_date - signup_date
        ELSE NULL
    END AS days_to_first_order,

    -- Returned-unit ratio. Negative or zero quantities
    -- are not used as the denominator.
    CASE
        WHEN total_units_ordered > 0
        THEN ROUND(
            total_units_returned::NUMERIC
            / NULLIF(total_units_ordered::NUMERIC, 0),
            4
        )
        ELSE NULL
    END AS returned_unit_ratio,

    -- Average recorded net transaction amount per distinct
    -- order. This is not necessarily recognized revenue.
    CASE
        WHEN distinct_order_count > 0
        THEN ROUND(
            net_sales_amount::NUMERIC
            / NULLIF(distinct_order_count, 0),
            2
        )
        ELSE NULL
    END AS average_net_amount_per_order,

    line_total_mismatch_count,
    negative_quantity_item_count

FROM customer_analysis_base

ORDER BY
    net_sales_amount DESC NULLS LAST,
    distinct_order_count DESC,
    customer_id;
