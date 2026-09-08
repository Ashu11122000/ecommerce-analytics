
/*
    Data Quantity Analysis

    Purpose:
    - Analyze product quantities sold
    - Identify negative or invalid quantities
    - Analyze returned quantities
    - Calculate total, average, minimum, and maximum quantities
    - Identify products with the highest quantities
    - Identify orders with unusual quantities
*/

WITH quantity_summary AS (

    SELECT
        COUNT(*) AS total_order_items,
        SUM(quantity) AS total_quantity,
        ROUND(AVG(quantity), 2) AS average_quantity,
        MIN(quantity) AS minimum_quantity,
        MAX(quantity) AS maximum_quantity,

        COUNT(*) FILTER (
            WHERE quantity < 0
        ) AS negative_quantity_records,

        COUNT(*) FILTER (
            WHERE quantity = 0
        ) AS zero_quantity_records,

        SUM(returned_quantity) AS total_returned_quantity,

        COUNT(*) FILTER (
            WHERE returned_quantity > 0
        ) AS order_items_with_returns

    FROM {{ ref('fact_order_items') }}

),

product_quantity_summary AS (

    SELECT
        product_id,
        SUM(quantity) AS total_quantity_sold,
        SUM(returned_quantity) AS total_quantity_returned,
        COUNT(*) AS number_of_order_lines,
        ROUND(AVG(quantity), 2) AS average_quantity_per_order_line,
        MAX(quantity) AS maximum_quantity_in_single_order_line
        
    FROM {{ ref('fact_order_items') }}

    GROUP BY product_id

)

SELECT
    qs.total_order_items,
    qs.total_quantity,
    qs.average_quantity,
    qs.minimum_quantity,
    qs.maximum_quantity,
    qs.negative_quantity_records,
    qs.zero_quantity_records,
    qs.total_returned_quantity,
    qs.order_items_with_returns,

    (
        SELECT product_id
        FROM product_quantity_summary
        ORDER BY total_quantity_sold DESC
        LIMIT 1
    ) AS highest_quantity_product_id,

    (
        SELECT total_quantity_sold
        FROM product_quantity_summary
        ORDER BY total_quantity_sold DESC
        LIMIT 1
    ) AS highest_quantity_sold

FROM quantity_summary AS qs;
