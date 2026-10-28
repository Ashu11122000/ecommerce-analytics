
-- ============================================================
-- Test: Eligible sales records must have valid positive values.
--
-- Expected result: Zero rows returned.
--
-- Business rule:
--   Only records marked is_valid_for_sales = TRUE are
--   required to have positive quantities and non-negative
--   gross and net sales measures.
--
-- Invalid source records remain in the fact table for auditing.
-- ============================================================

SELECT
    order_item_id,
    quantity,
    gross_sales_amount,
    net_sales_amount,
    is_valid_for_sales
FROM {{ ref('fact_order_items') }}
WHERE is_valid_for_sales = TRUE
  AND (
      quantity <= 0
      OR gross_sales_amount IS NULL
      OR gross_sales_amount < 0
      OR net_sales_amount IS NULL
      OR net_sales_amount < 0
  )
