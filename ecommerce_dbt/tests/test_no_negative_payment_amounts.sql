
-- Test: Payment amounts must not be negative.
-- Expected result: Zero rows returned.

SELECT
    payment_id,
    payment_amount
FROM {{ ref('fact_payments') }}
WHERE payment_amount < 0
