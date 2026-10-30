
-- ============================================================
-- Model: silver_orders
-- Layer: Silver
-- Grain: One row per order (order_id)
--
-- Purpose:
--   Clean and enrich order data from the Bronze layer.
--   Add financial calculations, business-friendly status
--   classifications, payment flags, and ingestion monitoring.
--
-- Transformations:
--   1. Calculate ingestion delay in calendar days.
--   2. Derive the order amount before tax.
--   3. Estimate gross order value before discounts and tax.
--   4. Identify discounts and shipping charges.
--   5. Group order statuses for reporting.
--   6. Identify successful payment statuses.
--   7. Flag late-arriving orders.
-- ============================================================

WITH orders_base AS (

    -- Step 1: Select order attributes from Bronze.
    -- Calculate ingestion delay as a calendar-day difference.
    SELECT
        -- Order identifiers and dates
        order_id,
        customer_id,
        order_date,

        -- Source order attributes
        order_status,
        payment_status,
        shipping_method,

        -- Original financial fields
        shipping_cost,
        discount_amount,
        tax_amount,
        total_amount,

        -- Sales attributes
        sales_channel,
        currency,

        -- Source lineage
        updated_at,
        ingested_at,
        loaded_at,

        -- Calendar-day difference between order creation
        -- and ingestion into the data platform.
        CASE
            WHEN order_date IS NOT NULL
                 AND ingested_at IS NOT NULL
            THEN ingested_at::DATE - order_date::DATE
            ELSE NULL
        END AS ingestion_delay_days

    FROM {{ ref('bronze_orders') }}

),

orders_classified AS (

    -- Step 2: Add derived financial metrics and classifications.
    SELECT
        *,

        -- Recorded order total excluding tax.
        -- Assumes total_amount includes tax.
        CASE
            WHEN total_amount IS NOT NULL
                 AND tax_amount IS NOT NULL
            THEN ROUND(
                (total_amount - tax_amount)::NUMERIC,
                2
            )
            ELSE NULL
        END AS amount_before_tax,

        -- Estimated gross order value before discount and tax.
        -- Assumes the discount is deducted from the recorded total.
        CASE
            WHEN total_amount IS NOT NULL
                 AND tax_amount IS NOT NULL
                 AND discount_amount IS NOT NULL
            THEN ROUND(
                (
                    total_amount
                    - tax_amount
                    + discount_amount
                )::NUMERIC,
                2
            )
            ELSE NULL
        END AS gross_order_value,

        -- Identify whether a positive discount was applied.
        CASE
            WHEN discount_amount IS NULL THEN NULL
            WHEN discount_amount > 0 THEN TRUE
            ELSE FALSE
        END AS has_discount,

        -- Identify whether a positive shipping charge exists.
        CASE
            WHEN shipping_cost IS NULL THEN NULL
            WHEN shipping_cost > 0 THEN TRUE
            ELSE FALSE
        END AS has_shipping_cost,

        -- Normalize source order statuses into reporting groups.
        CASE
            WHEN LOWER(TRIM(order_status)) IN (
                'delivered',
                'completed'
            )
                THEN 'Completed'

            WHEN LOWER(TRIM(order_status)) IN (
                'shipped',
                'in transit',
                'in_transit'
            )
                THEN 'In Progress'

            WHEN LOWER(TRIM(order_status)) IN (
                'pending',
                'processing'
            )
                THEN 'Pending'

            WHEN LOWER(TRIM(order_status)) IN (
                'cancelled',
                'canceled'
            )
                THEN 'Cancelled'

            WHEN LOWER(TRIM(order_status)) IN (
                'returned',
                'refunded'
            )
                THEN 'Returned'

            WHEN order_status IS NULL
                 OR TRIM(order_status) = ''
                THEN 'Unknown'

            -- Preserve unrecognized statuses for investigation.
            ELSE 'Other'
        END AS order_status_group,

        -- Identify payment statuses indicating successful payment.
        -- Payment success does not imply order completion.
        CASE
            WHEN LOWER(TRIM(payment_status)) IN (
                'paid',
                'completed',
                'success',
                'successful'
            )
                THEN TRUE

            WHEN payment_status IS NULL
                 OR TRIM(payment_status) = ''
                THEN NULL

            ELSE FALSE
        END AS is_payment_successful,

        -- Flag orders ingested more than seven elapsed days
        -- after the order timestamp.
        -- Missing timestamps produce an unknown flag.
        CASE
            WHEN order_date IS NULL
                 OR ingested_at IS NULL
                THEN NULL

            WHEN ingested_at > order_date + INTERVAL '7 days'
                THEN TRUE

            ELSE FALSE
        END AS is_late_arriving

    FROM orders_base

)

-- Step 3: Return the final enriched Silver model.
SELECT
    -- Order identifiers and source attributes
    order_id,
    customer_id,
    order_date,
    order_status,
    payment_status,
    shipping_method,

    -- Original financial fields
    shipping_cost,
    discount_amount,
    tax_amount,
    total_amount,

    -- Sales attributes
    sales_channel,
    currency,

    -- Derived financial metrics
    amount_before_tax,
    gross_order_value,

    -- Business flags and status classification
    has_discount,
    has_shipping_cost,
    order_status_group,
    is_payment_successful,

    -- Ingestion monitoring
    is_late_arriving,
    ingestion_delay_days,

    -- Source lineage
    updated_at,
    ingested_at,
    loaded_at,

    -- Transformation execution timestamp.
    -- For a view, this value can change between query executions.
    {{ transformed_timestamp() }} AS transformed_at

FROM orders_classified
