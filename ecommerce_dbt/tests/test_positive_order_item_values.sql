
/*
    Custom dbt Data Test: Positive Order Item Values

    Purpose:
    - Verify that every order item has a quantity greater than zero.
    - Verify that every order item has a unit price greater than zero.
    - Return any order items that violate either rule.

    Expected result:
    - 0 rows returned means the test passes.
    - 1 or more rows returned means the test fails.

    Important:
    - This test treats zero and negative values as invalid.
    - NULL values are not caught by these comparisons alone.
      Use explicit NULL checks if the columns are nullable.
*/

SELECT
    order_item_id,
    order_id,
    quantity,
    unit_price
FROM {{ ref('fact_order_items') }}
WHERE quantity IS NULL
   OR quantity <= 0
   OR unit_price IS NULL
   OR unit_price <= 0
