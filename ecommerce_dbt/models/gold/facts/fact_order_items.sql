{{
    config(
        materialized='incremental',
        unique_key='order_item_id'
    )
}}

SELECT
    -- Fact grain
    oi.order_item_id,

    -- Dimension keys
    oi.order_id,
    o.customer_id,
    oi.product_id,
    TO_CHAR(o.order_date::DATE, 'YYYYMMDD')::INTEGER AS order_date_key,

    -- Transaction attributes
    o.order_date,
    o.order_status,
    o.sales_channel,
    o.currency,

    -- Product transaction values
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    oi.tax_amount,

    -- Source line total
    oi.line_total,

    -- Silver-calculated line total
    oi.calculated_line_total,

    -- Difference between source and calculated value
    oi.line_total_variance,

    -- Data-quality flags
    oi.is_line_total_mismatch,
    oi.has_negative_quantity,

    -- Return information
    oi.returned_quantity,
    oi.has_return,
    oi.return_rate,

    -- Net sales amount
    (
        oi.quantity * oi.unit_price
        - oi.discount_amount
        + oi.tax_amount
    ) AS net_sales_amount,

    -- Gross sales before discount
    oi.quantity * oi.unit_price AS gross_sales_amount,

    -- Technical lineage timestamps
    oi.updated_at,
    oi.ingested_at,
    oi.loaded_at,
    oi.transformed_at,

    {{ modeled_timestamp() }} AS modeled_at

FROM {{ ref('silver_order_items') }} AS oi

INNER JOIN {{ ref('silver_orders') }} AS o
    ON oi.order_id = o.order_id

{% if is_incremental() %}

WHERE oi.ingested_at > (
    SELECT COALESCE(
        MAX(ingested_at),
        '1900-01-01'::timestamp
    )
    FROM {{ this }}
)

{% endif %}
