
/*
    Test: Positive Order Amount

    Purpose:
    - Verify that every order has a positive total amount.
    - A failed test returns the rows that violate the rule.

    Expected result:
    - 0 rows returned.
*/

SELECT
    order_id,
    total_amount
FROM {{ ref('silver_orders') }}
WHERE total_amount IS NULL
   OR total_amount <= 0
