
-- ============================================================
-- Test: Eligible sales records must reconcile with their
-- calculated line totals within a tolerance of 0.01.
--
-- Expected result: Zero rows returned.
--
-- Invalid source records remain available for data-quality
-- analysis but are excluded from eligible sales reporting.
-- ============================================================

SELECT
    order_item_id,
    line_total,
    calculated_line_total,
    line_total_variance,
    is_line_total_mismatch,
    is_valid_for_sales
FROM {{ ref('fact_order_items') }}
WHERE is_valid_for_sales = TRUE
  AND (
      line_total IS NULL
      OR calculated_line_total IS NULL
      OR ABS(
          line_total - calculated_line_total
      ) > 0.01
  )
