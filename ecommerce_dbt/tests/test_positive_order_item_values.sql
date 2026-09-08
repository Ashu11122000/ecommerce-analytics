/*
    Test: Positive Order Item Values

    Purpose:
    - Verify that every order item has a positive quantity.
    - Verify that every order item has a positive unit price.
    - A failed test returns rows that violate either rule.

    Expected result:
    - 0 rows returned.
*/

SELECT
    order_item_id,
    order_id,
    quantity,
    unit_price
FROM {{ ref('fact_order_items') }}
WHERE quantity <= 0
    OR unit_price <= 0