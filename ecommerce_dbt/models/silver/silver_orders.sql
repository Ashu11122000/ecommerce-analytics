
-- ============================================================
-- Model: silver_orders
-- Layer: Silver
-- Purpose:
--   Clean and enrich order data from the Bronze layer.
--   Add financial calculations, business-friendly status
--   classifications, payment flags, and ingestion monitoring.
--
-- Grain:
--   One row per order (order_id).
--
-- Important assumptions:
--   1. total_amount is the recorded order total.
--   2. amount_before_tax = total_amount - tax_amount.
--   3. gross_order_value = amount_before_tax + discount_amount.
--   4. Orders ingested more than seven days after order_date
--      are flagged as late-arriving.
--   5. Financial definitions must be validated against the
--      source data generation logic before dashboard use.
-- ============================================================

WITH orders_base AS (

    -- Step 1: Select order attributes from the Bronze model.
    -- Calculate ingestion delay as a calendar-day difference.
    SELECT
        order_id,
        customer_id,
        order_date,
        order_status,
        payment_status,
        shipping_method,
        shipping_cost,
        discount_amount,
        tax_amount,
        total_amount,
        sales_channel,
        currency,
        updated_at,
        ingested_at,
        loaded_at,

        -- Number of calendar days between order creation
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

    -- Step 2: Add financial metrics and business classifications.
    SELECT
        *,

        -- Calculate the recorded order total excluding tax.
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

        -- Estimate gross order value before discounts and tax.
        -- Assumes discount_amount is deducted from the total
        -- and needs to be added back to calculate gross value.
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
        -- Preserve NULL when the discount amount is unknown.
        CASE
            WHEN discount_amount IS NULL THEN NULL
            WHEN discount_amount > 0 THEN TRUE
            ELSE FALSE
        END AS has_discount,

        -- Identify whether the order has a positive shipping charge.
        -- Preserve NULL when the shipping cost is unknown.
        CASE
            WHEN shipping_cost IS NULL THEN NULL
            WHEN shipping_cost > 0 THEN TRUE
            ELSE FALSE
        END AS has_shipping_cost,

        -- Standardize order statuses into reporting categories.
        -- These groups simplify dashboard filtering and reporting.
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

            -- Treat missing or blank statuses separately.
            WHEN order_status IS NULL
                OR TRIM(order_status) = ''
                THEN 'Unknown'

            -- Retain unrecognized values for investigation.
            ELSE 'Other'
        END AS order_status_group,

        -- Identify payment statuses that indicate success.
        -- A successful payment does not necessarily mean
        -- the order itself has been completed.
        CASE
            WHEN LOWER(TRIM(payment_status)) IN (
                'paid',
                'completed',
                'success',
                'successful'
            )
                THEN TRUE

            -- Do not treat missing payment information as failure.
            WHEN payment_status IS NULL
                OR TRIM(payment_status) = ''
                THEN NULL

            ELSE FALSE
        END AS is_payment_successful,

        -- Flag an order when ingestion happened more than
        -- seven days after the order date.
        -- This is a monitoring rule, not proof of a data error.
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
    -- Order identifiers and descriptive attributes.
    order_id,
    customer_id,
    order_date,
    order_status,
    payment_status,
    shipping_method,

    -- Financial source fields.
    shipping_cost,
    discount_amount,
    tax_amount,
    total_amount,
    sales_channel,
    currency,

    -- Derived financial metrics.
    amount_before_tax,
    gross_order_value,

    -- Business flags and standardized status.
    has_discount,
    has_shipping_cost,
    order_status_group,
    is_payment_successful,

    -- Data ingestion monitoring fields.
    is_late_arriving,
    ingestion_delay_days,

    -- Source and ingestion audit timestamps.
    updated_at,
    ingested_at,
    loaded_at,

    -- Record the time this transformation query executes.
    -- In a view, this value can change when the view is queried.
    {{ transformed_timestamp() }} AS transformed_at

FROM orders_classified
