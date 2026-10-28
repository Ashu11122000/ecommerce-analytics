
-- Test: Payment amounts must not be negative.
-- Expected result: Zero rows returned.

SELECT
    payment_id,
    amount
FROM {{ ref('fact_payments') }}
WHERE amount < 0
