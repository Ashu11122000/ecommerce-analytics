
SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    tax_amount,
    line_total,
    returned_quantity,

    -- Calculate the expected line total from the source components
    (
        (quantity * unit_price)
        - discount_amount
        + tax_amount
    ) AS calculated_line_total,

    -- Difference between source and calculated line total
    ROUND(
        line_total
        - (
            (quantity * unit_price)
            - discount_amount
            + tax_amount
        ),
        2
    ) AS line_total_variance,

    -- Identify incorrect line totals
    CASE
        WHEN ABS(
            line_total
            - (
                (quantity * unit_price)
                - discount_amount
                + tax_amount
            )
        ) > 0.01
        THEN TRUE
        ELSE FALSE
    END AS is_line_total_mismatch,

    -- Identify invalid negative quantities
    CASE
        WHEN quantity < 0 THEN TRUE
        ELSE FALSE
    END AS has_negative_quantity,

    -- Identify whether this item has been returned
    CASE
        WHEN returned_quantity > 0 THEN TRUE
        ELSE FALSE
    END AS has_return,

    -- Calculate return percentage
    CASE
        WHEN quantity > 0
        THEN ROUND(
            returned_quantity::NUMERIC / quantity,
            4
        )
        ELSE NULL
    END AS return_rate,

    updated_at,
    ingested_at,
    loaded_at,

    {{ transformed_timestamp() }} AS transformed_at

FROM {{ ref('bronze_order_items') }}