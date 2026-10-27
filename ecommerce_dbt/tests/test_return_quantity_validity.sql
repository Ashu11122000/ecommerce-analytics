
-- Test: Return quantities must not be negative.
-- Expected result: Zero rows returned.
--
-- Assumes fact_returns contains return_id and return_quantity.

SELECT
    return_id,
    return_quantity
FROM {{ ref('fact_returns') }}
WHERE return_quantity < 0
