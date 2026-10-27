
/*
    Analysis: Data Quantity Analysis

    Purpose:
    - Analyze quantities recorded in Gold order-item facts.
    - Identify negative, zero, and missing ordered quantities.
    - Analyze returned quantities and return-related data-quality issues.
    - Calculate overall quantity statistics.
    - Identify the product with the highest total recorded quantity.
    - Flag order lines above a configurable quantity threshold.

    Grain:
    - Overall summary: one row for the entire fact table.
    - Product summary: one row per product_id, calculated internally.
    - Final output: one row containing overall statistics and
      the product with the highest total recorded quantity.

    Important assumptions:
    - All order statuses are included.
    - Quantities represent recorded order-item quantities, not
      necessarily completed or fulfilled sales.
    - Negative quantities are preserved and reported.
    - A quantity greater than the configured threshold is flagged.
    - Product ranking uses net recorded quantity, including
      negative quantities where present.
    - This analysis is read-only and does not create a table.
*/

WITH analysis_parameters AS (

    -- Configure the threshold for unusually high order quantities.
    -- Change this value if the business defines another threshold.
    SELECT
        10::NUMERIC AS unusually_high_quantity_threshold

),

order_item_data AS (

    -- Step 1: Read order-item measures and quality indicators.
    SELECT
        order_item_id,
        order_id,
        product_id,
        quantity,
        returned_quantity,
        has_negative_quantity,
        has_excess_returned_quantity

    FROM {{ ref('fact_order_items') }}

),

/* ------------------------------------------------------------
   1. Overall quantity statistics
   ------------------------------------------------------------ */
quantity_summary AS (

    SELECT
        COUNT(*) AS total_order_items,

        COUNT(quantity) AS order_items_with_quantity,

        COALESCE(
            SUM(quantity),
            0
        ) AS total_quantity,

        ROUND(
            AVG(quantity)::NUMERIC,
            2
        ) AS average_quantity,

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

        COALESCE(
            SUM(returned_quantity),
            0
        ) AS total_returned_quantity,

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
            WHERE has_excess_returned_quantity IS TRUE
        ) AS excess_returned_quantity_records,

        COUNT(*) FILTER (
            WHERE quantity > p.unusually_high_quantity_threshold
        ) AS unusually_high_quantity_records,

        p.unusually_high_quantity_threshold

    FROM order_item_data

    CROSS JOIN analysis_parameters AS p

    GROUP BY
        p.unusually_high_quantity_threshold

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

        COUNT(quantity) AS order_lines_with_quantity,

        ROUND(
            AVG(quantity)::NUMERIC,
            2
        ) AS average_quantity_per_order_line,

        MAX(quantity) AS maximum_quantity_in_single_order_line

    FROM order_item_data

    GROUP BY
        product_id

),

/* ------------------------------------------------------------
   3. Rank products by total recorded quantity
   Tie-break using product_id for repeatable results.
   ------------------------------------------------------------ */
ranked_products AS (

    SELECT
        product_id,
        total_quantity_ordered,
        total_quantity_returned,
        number_of_order_lines,
        order_lines_with_quantity,
        average_quantity_per_order_line,
        maximum_quantity_in_single_order_line,

        ROW_NUMBER() OVER (
            ORDER BY
                total_quantity_ordered DESC NULLS LAST,
                product_id ASC NULLS LAST
        ) AS product_rank

    FROM product_quantity_summary

),

/* ------------------------------------------------------------
   4. Select the highest-ranked product
   ------------------------------------------------------------ */
highest_quantity_product AS (

    SELECT
        product_id AS highest_quantity_product_id,

        total_quantity_ordered AS highest_quantity_product_total,

        total_quantity_returned AS highest_quantity_product_returned,

        number_of_order_lines AS highest_quantity_product_order_lines,

        order_lines_with_quantity
            AS highest_quantity_product_lines_with_quantity,

        average_quantity_per_order_line
            AS highest_quantity_product_average_quantity,

        maximum_quantity_in_single_order_line
            AS highest_quantity_in_single_order_line

    FROM ranked_products

    WHERE product_rank = 1

)

/* ------------------------------------------------------------
   5. Final single-row analysis result
   ------------------------------------------------------------ */
SELECT
    -- Overall order-item statistics.
    qs.total_order_items,
    qs.order_items_with_quantity,
    qs.total_quantity,
    qs.average_quantity,
    qs.minimum_quantity,
    qs.maximum_quantity,

    -- Ordered-quantity quality checks.
    qs.negative_quantity_records,
    qs.zero_quantity_records,
    qs.missing_quantity_records,

    -- Returned-quantity statistics and quality checks.
    qs.total_returned_quantity,
    qs.order_items_with_returns,
    qs.negative_returned_quantity_records,
    qs.missing_returned_quantity_records,
    qs.excess_returned_quantity_records,

    -- Configured high-quantity rule.
    qs.unusually_high_quantity_threshold,
    qs.unusually_high_quantity_records,

    -- Highest-ranked product statistics.
    hp.highest_quantity_product_id,
    hp.highest_quantity_product_total,
    hp.highest_quantity_product_returned,
    hp.highest_quantity_product_order_lines,
    hp.highest_quantity_product_lines_with_quantity,
    hp.highest_quantity_product_average_quantity,
    hp.highest_quantity_in_single_order_line

FROM quantity_summary AS qs

LEFT JOIN highest_quantity_product AS hp
    ON TRUE
