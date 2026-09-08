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

    -- Calculate the order amount before tax
    total_amount - tax_amount AS amount_before_tax,

    -- Calculate the expected total from order components
    (
        total_amount
        - tax_amount
        + discount_amount
    ) AS gross_order_value,

    -- Identify orders that contain a discount
    CASE
        WHEN discount_amount > 0 THEN TRUE
        ELSE FALSE
    END AS has_discount,

    -- Identify orders that contain a shipping charge
    CASE
        WHEN shipping_cost > 0 THEN TRUE
        ELSE FALSE
    END AS has_shipping_cost,

    -- Group orders into business-friendly status categories
    CASE
        WHEN LOWER(order_status) IN ('delivered', 'completed')
            THEN 'Completed'
        WHEN LOWER(order_status) IN ('shipped', 'in transit')
            THEN 'In Progress'
        WHEN LOWER(order_status) IN ('pending', 'processing')
            THEN 'Pending'
        WHEN LOWER(order_status) IN ('cancelled', 'canceled')
            THEN 'Cancelled'
        WHEN LOWER(order_status) IN ('returned', 'refunded')
            THEN 'Returned'
        ELSE 'Other'
    END AS order_status_group,

    -- Identify successful/completed payments
    CASE
        WHEN LOWER(payment_status) IN ('paid', 'completed', 'success', 'successful')
            THEN TRUE
        ELSE FALSE
    END AS is_payment_successful,

    -- Identify orders that arrived late into the data platform
    CASE
        WHEN ingested_at > order_date + INTERVAL '7 days'
            THEN TRUE
        ELSE FALSE
    END AS is_late_arriving,

    -- Number of days between order creation and ingestion
    EXTRACT(
        DAY FROM (ingested_at - order_date)
    )::INTEGER AS ingestion_delay_days,

    updated_at,
    ingested_at,
    loaded_at,

    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_orders') }}
