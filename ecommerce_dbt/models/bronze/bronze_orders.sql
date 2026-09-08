SELECT
    order_id,
    customer_id,
    order_date,
    INITCAP(TRIM(order_status)) AS order_status,
    INITCAP(TRIM(payment_status)) AS payment_status,
    INITCAP(TRIM(shipping_method)) AS shipping_method,
    COALESCE(shipping_cost, 0.00) AS shipping_cost,
    COALESCE(discount_amount, 0.00) AS discount_amount,
    COALESCE(tax_amount, 0.00) AS tax_amount,
    total_amount,
    INITCAP(TRIM(sales_channel)) AS sales_channel,
    UPPER(TRIM(currency)) AS currency,
    updated_at,
    ingested_at,

    CURRENT_TIMESTAMP AS loaded_at

FROM {{ source('raw', 'orders') }}