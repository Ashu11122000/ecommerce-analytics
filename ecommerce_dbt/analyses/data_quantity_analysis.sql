
/*
    Data Quantity Analysis

    Purpose:
    - Analyze product quantities across order items.
    - Identify negative, zero, and missing quantities.
    - Analyze returned quantities and invalid return records.
    - Calculate total, average, minimum, and maximum quantities.
    - Identify the product with the highest total ordered quantity.
    - Identify order lines with unusually high quantities.

    Grain:
    - Overall summary: one row for the entire fact table.
    - Product summary: one row per product_id, calculated internally.
    - Final output: one row containing overall statistics and the
      product with the highest total ordered quantity.

    Important assumptions:
    - Quantity totals include all order statuses in fact_order_items.
    - These quantities represent ordered quantities, not necessarily
      completed or fulfilled sales.
    - Returned quantities are assumed to be non-negative.
    - A high quantity is flagged using a configurable threshold below.
*/

WITH order_item_data AS (

    SELECT
        order_item_id,
        order_id,
        product_id,
        quantity,
        returned_quantity
    FROM {{ ref('fact_order_items') }}

),

/* ------------------------------------------------------------
   1. Overall quantity statistics
   ------------------------------------------------------------ */
quantity_summary AS (

    SELECT
        COUNT(*) AS total_order_items,

        COUNT(quantity) AS order_items_with_quantity,

        COALESCE(SUM(quantity), 0) AS total_quantity,

        ROUND(AVG(quantity), 2) AS average_quantity,

        MIN(quantity) AS minimum_quantity,

        MAX(quantity) AS maximum_quantity,

        COUNT(*) FILTER (
            WHERE quantity < 0
        ) AS negative_quantity_records,

        COUNT(*) FILTER (
            WHERE quantity = 0
        ) AS zero_quantity_records,

        COUNT(*) FILTER (
            WHERE quantity IS NULL
        ) AS missing_quantity_records,

        COALESCE(SUM(returned_quantity), 0)
            AS total_returned_quantity,

        COUNT(*) FILTER (
            WHERE returned_quantity > 0
        ) AS order_items_with_returns,

        COUNT(*) FILTER (
            WHERE returned_quantity < 0
        ) AS negative_returned_quantity_records,

        COUNT(*) FILTER (
            WHERE returned_quantity IS NULL
        ) AS missing_returned_quantity_records,

        COUNT(*) FILTER (
            WHERE quantity > 10
        ) AS unusually_high_quantity_records

    FROM order_item_data

),

/* ------------------------------------------------------------
   2. Product-level quantity statistics
   ------------------------------------------------------------ */
product_quantity_summary AS (

    SELECT
        product_id,

        SUM(quantity) AS total_quantity_ordered,

        SUM(returned_quantity) AS total_quantity_returned,

        COUNT(*) AS number_of_order_lines,

        ROUND(AVG(quantity), 2)
            AS average_quantity_per_order_line,

        MAX(quantity)
            AS maximum_quantity_in_single_order_line

    FROM order_item_data

    GROUP BY product_id

),

/* ------------------------------------------------------------
   3. Rank products by total ordered quantity
   Tie-break using product_id for repeatable results.
   ------------------------------------------------------------ */
ranked_products AS (

    SELECT
        product_id,
        total_quantity_ordered,
        total_quantity_returned,
        number_of_order_lines,
        average_quantity_per_order_line,
        maximum_quantity_in_single_order_line,

        ROW_NUMBER() OVER (
            ORDER BY
                total_quantity_ordered DESC NULLS LAST,
                product_id ASC NULLS LAST
        ) AS product_rank

    FROM product_quantity_summary

),

highest_quantity_product AS (

    SELECT
        product_id AS highest_quantity_product_id,
        total_quantity_ordered AS highest_quantity_sold,
        total_quantity_returned AS highest_quantity_product_returned,
        number_of_order_lines AS highest_quantity_product_order_lines,
        maximum_quantity_in_single_order_line
            AS highest_quantity_in_single_order_line

    FROM ranked_products

    WHERE product_rank = 1

)

/* ------------------------------------------------------------
   4. Final single-row analysis result
   ------------------------------------------------------------ */
SELECT
    qs.total_order_items,
    qs.order_items_with_quantity,
    qs.total_quantity,
    qs.average_quantity,
    qs.minimum_quantity,
    qs.maximum_quantity,

    qs.negative_quantity_records,
    qs.zero_quantity_records,
    qs.missing_quantity_records,

    qs.total_returned_quantity,
    qs.order_items_with_returns,
    qs.negative_returned_quantity_records,
    qs.missing_returned_quantity_records,

    qs.unusually_high_quantity_records,

    hp.highest_quantity_product_id,
    hp.highest_quantity_sold,
    hp.highest_quantity_product_returned,
    hp.highest_quantity_product_order_lines,
    hp.maximum_quantity_in_single_order_line

FROM quantity_summary AS qs

LEFT JOIN highest_quantity_product AS hp
    ON TRUE
