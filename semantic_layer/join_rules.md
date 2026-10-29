# Semantic Layer: Join Rules

## 1. Purpose

This document defines safe join paths and grain-aware rules for the E-Commerce Analytics Engineering reporting layer. The goal is to prevent duplicated rows, inflated metrics, dropped records, and inconsistent results across SQL analyses and dashboards.

These rules describe the intended reporting contract based on the project's documented model design. Before treating a relationship as guaranteed, verify the actual dbt model SQL, keys, tests, and PostgreSQL constraints.

## 2. Core Principles

1. **Know the grain before joining.** Identify what one row represents in every source model.
2. **Validate key uniqueness.** A dimension key used for a many-to-one join must be unique on the dimension side.
3. **Use explicit join keys.** Avoid joining only on names, labels, or non-unique descriptive attributes.
4. **Preserve the intended fact grain.** A join should not unexpectedly increase the number of fact rows.
5. **Do not combine raw-grain facts casually.** Multiple fact tables can have different grains and cardinalities.
6. **Handle unmatched keys deliberately.** Decide whether to retain, map to an unknown member, or exclude unmatched records, and document that choice.
7. **Apply metric filters consistently.** Eligibility rules, status filters, and date selection should be consistent with the metric definition.
8. **Reconcile additive measures after joins.** Compare totals before and after a join to detect fan-out.

## 3. Core Models and Expected Grain

| Model              | Expected grain                                                      | Common identifier                      | Notes                                                    |
| ------------------ | ------------------------------------------------------------------- | -------------------------------------- | -------------------------------------------------------- |
| `dim_customers`    | One row per customer, unless historical versions are modeled        | `customer_id`                          | Verify uniqueness before joining                         |
| `dim_products`     | One row per product, unless historical versions are modeled         | `product_id`                           | Use transaction price from the fact for historical sales |
| `dim_date`         | One row per calendar date                                           | Date key or date column as implemented | Confirm date coverage and uniqueness                     |
| `fact_order_items` | One row per `order_item_id`                                         | `order_item_id`                        | Primary sales and item-level analysis fact               |
| `fact_payments`    | Payment-level only if implemented with one row per payment record   | Model-defined payment key              | Multiple payments or attempts per order may exist        |
| `fact_returns`     | Return-level only if implemented with one row per return record     | Model-defined return key               | Multiple returns per item/order may exist                |
| `fact_shipments`   | Shipment-level only if implemented with one row per shipment record | Model-defined shipment key             | Multiple shipments per order may exist                   |

The grain and identifiers for payment, return, and shipment models must be confirmed from the actual model SQL. If those models are absent, do not treat them as available relations.

## 4. Recommended Fact-to-Dimension Joins

### 4.1 Order items to customers

Typical join, if the key exists in both models:

```sql
SELECT
    f.order_item_id,
    f.order_id,
    f.customer_id,
    c.city
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_customers AS c
    ON f.customer_id = c.customer_id;
```

Rules:

- Confirm `dim_customers.customer_id` is unique and non-null.
- Prefer `LEFT JOIN` when unmatched fact rows must remain visible for data-quality analysis.
- Use `INNER JOIN` only when the business definition explicitly excludes unmatched customers and the exclusion is documented.
- Check whether the join changes the fact-row count.
- If the fact has no `customer_id`, join through a validated order model or use the actual key path in the current schema. Do not invent a column.

### 4.2 Order items to products

Typical join:

```sql
SELECT
    f.order_item_id,
    f.order_id,
    f.product_id,
    p.product_name,
    p.category,
    f.quantity,
    f.unit_price
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_products AS p
    ON f.product_id = p.product_id;
```

Rules:

- Confirm `dim_products.product_id` is unique and non-null.
- Use the fact's transaction-level `unit_price` for historical sales calculations.
- Use the product dimension for descriptive attributes such as product name and category.
- Do not substitute the current catalog `price` for the historical transaction price unless the metric is explicitly catalog-price based.
- Investigate unmatched product keys rather than silently removing those fact rows.

### 4.3 Facts to the date dimension

Use the business date that matches the question and the key exposed by the current model. For example, if the fact has an `order_date` and `dim_date` has a calendar `date_day` column:

```sql
SELECT
    f.order_item_id,
    d.year,
    d.month_number,
    d.year_month
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_date AS d
    ON f.order_date::date = d.date_day;
```

This is an illustrative pattern only. Replace `date_day`, `year`, `month_number`, and `year_month` with the actual columns. If the model uses a surrogate date key, join on that key instead.

Rules:

- Confirm the date dimension contains one row per date.
- Confirm all relevant fact dates are covered.
- Do not join a timestamp to a date column without deliberately handling the time component and time zone.
- Use order date for order/sales trends, payment date for payment trends, return date for returns trends, and shipment/delivery date for logistics trends when those fields are available.
- Sort month labels using a chronological date or numeric key, not alphabetically.

## 5. Joining Orders and Order Items

An order commonly has multiple order-item rows. Therefore, the relationship from orders to order items is typically one-to-many.

```text
orders (one row per order)
        |
        | order_id
        v
order_items (one row per order item)
```

Rules:

- `COUNT(*)` after joining orders to order items counts order-item rows, not distinct orders.
- Use `COUNT(DISTINCT order_id)` for an order count when the intended grain is one order.
- Sum item-level quantities and sales at the order-item grain only after confirming the eligibility and financial rules.
- If order-level attributes are repeated on each order-item row, do not sum those repeated order-level amounts across item rows.
- Confirm that each order item maps to at most one intended order record.

## 6. Critical Rule: Do Not Join Multiple Facts at Raw Grain Without Controlling Cardinality

Payment, return, shipment, and order-item facts may represent different business events and may have different grains.

Example of a dangerous pattern:

```sql
-- Avoid this pattern unless cardinality is proven and controlled.
SELECT
    oi.order_id,
    SUM(oi.line_total) AS sales_amount,
    SUM(p.payment_amount) AS payment_amount,
    SUM(s.shipping_cost) AS shipping_cost
FROM analytics_gold.fact_order_items AS oi
LEFT JOIN analytics_gold.fact_payments AS p
    ON oi.order_id = p.order_id
LEFT JOIN analytics_gold.fact_shipments AS s
    ON oi.order_id = s.order_id
GROUP BY oi.order_id;
```

If an order has 3 item rows, 2 payment rows, and 2 shipment rows, the combined join can produce up to 12 rows for that order. The join can inflate each measure.

### Safer approach: aggregate each fact to a common grain first

The following example is illustrative. Replace identifiers and measure names with the actual columns in your models:

```sql
WITH sales_by_order AS (
    SELECT
        order_id,
        SUM(line_total) AS sales_amount
    FROM analytics_gold.fact_order_items
    GROUP BY order_id
),
payments_by_order AS (
    SELECT
        order_id,
        SUM(payment_amount) AS payment_amount
    FROM analytics_gold.fact_payments
    GROUP BY order_id
),
shipments_by_order AS (
    SELECT
        order_id,
        COUNT(*) AS shipment_count
    FROM analytics_gold.fact_shipments
    GROUP BY order_id
)
SELECT
    s.order_id,
    s.sales_amount,
    p.payment_amount,
    sh.shipment_count
FROM sales_by_order AS s
LEFT JOIN payments_by_order AS p
    ON s.order_id = p.order_id
LEFT JOIN shipments_by_order AS sh
    ON s.order_id = sh.order_id;
```

This pattern is safe only if each CTE produces no more than one row per `order_id`, the selected measures are appropriate at that grain, and the actual models contain the referenced columns. Returns should be aggregated separately as well when they are part of the result.

## 7. Joining Returns to Order Items

A return may be linked to an order item, an order, or another source identifier depending on the source model.

Rules:

- Use the validated return-to-item or return-to-order key path defined by the actual models.
- Confirm whether more than one return record can exist for a single order item.
- If multiple returns per item are possible, aggregate return quantities and refunds to the intended grain before joining to order-item sales.
- Distinguish the count of return records from the count of returned items, returned units, and returned orders.
- Document which return statuses qualify for refund and returned-unit metrics.
- Do not assume that every return record represents an approved or completed refund.

If return data is aggregated to order-item grain, validate that the aggregate has no more than one row per `order_item_id` before joining it to `fact_order_items`.

## 8. Joining Shipments to Orders or Order Items

A shipment may represent an order, a partial order, or a split shipment. Do not assume one shipment per order without validating the source model.

Rules:

- Use the actual shipment key and order relationship defined in the current model.
- Calculate shipment counts and delivery metrics at shipment grain.
- Calculate order counts distinctly if a shipment report is grouped by order.
- If shipment measures are joined to order-item rows, aggregate shipments to order grain first where appropriate.
- Exclude missing delivery durations from an average only if that is the documented metric definition; report coverage or unknown counts where useful.
- Calculate delay rate using the explicitly documented denominator, such as shipments with known delay classification.

## 9. Payment Joins and Success Rate

Payment records should be analyzed at the payment grain unless the business question explicitly requires an order-level summary.

Rules:

- Define which statuses count as successful.
- Define how failed, pending, cancelled, and unknown statuses are treated.
- Calculate payment success rate using payment records with known outcomes if that is the documented denominator.
- Do not describe payment success rate as order conversion rate.
- If calculating the percentage of orders with at least one successful payment, first aggregate to one row per order and define how multiple attempts are handled.
- Avoid summing payment amounts after joining payments to item rows without aggregation.

## 10. Filter Placement and Join Type

Choose join types based on the reporting question:

- **LEFT JOIN:** retains all rows from the primary fact and allows missing dimension relationships to be investigated.
- **INNER JOIN:** retains only matched records; use only when excluding unmatched records is intentional.
- **FULL OUTER JOIN:** can support reconciliation between independent datasets, but requires deliberate treatment of unmatched keys.

A filter on the right-hand table in the `WHERE` clause can turn a `LEFT JOIN` into behavior similar to an inner join. For example:

```sql
-- This can remove fact rows without a matching dimension row.
SELECT ...
FROM fact_order_items AS f
LEFT JOIN dim_products AS p
    ON f.product_id = p.product_id
WHERE p.category = 'Accessories';
```

If the intention is to preserve all fact rows while matching only a filtered subset of dimension records, consider placing the condition in the join predicate. Choose the pattern according to the business question and document the impact.

## 11. Data Quality Checks for Join Safety

Use the following checks, adapting the schema and column names to the actual implementation.

### 11.1 Dimension-key duplicates

```sql
SELECT
    customer_id,
    COUNT(*) AS row_count
FROM analytics_gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Repeat for `product_id` and the date key. A valid dimension primary identifier should return no duplicate groups.

### 11.2 Unmatched customer keys

```sql
SELECT COUNT(*) AS unmatched_fact_rows
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_customers AS d
    ON f.customer_id = d.customer_id
WHERE f.customer_id IS NOT NULL
  AND d.customer_id IS NULL;
```

### 11.3 Unmatched product keys

```sql
SELECT COUNT(*) AS unmatched_fact_rows
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_products AS d
    ON f.product_id = d.product_id
WHERE f.product_id IS NOT NULL
  AND d.product_id IS NULL;
```

### 11.4 Row-count preservation

For a many-to-one fact-to-dimension join, compare the fact row count with the joined row count. An unexpected increase usually indicates duplicate dimension keys or an incorrect join predicate. A decrease can indicate an inner join, filtering, or a mismatch between the assumed and actual grain.

### 11.5 Measure reconciliation

Compare sales, payment amounts, refunds, and shipment counts before and after joins. The totals should change only when the defined business filters or intended aggregation changes them.

## 12. dbt Tests and Documentation

Where applicable, define tests in dbt YAML for:

- `unique` and `not_null` on dimension identifiers.
- `relationships` from fact foreign keys to dimension identifiers.
- Accepted values for status fields where the valid domain is defined.
- Custom tests for business-specific relationship or reconciliation rules.

The tests should reflect the actual intended grain and rules. If unmatched keys are allowed for audit or source-quality reasons, document whether the relationship test is expected to fail, warn, or pass under the current policy.

Keep this file aligned with:

- `semantic_layer/dimensions.md`
- `semantic_layer/model_grain.md`
- `semantic_layer/metric_definitions.md`
- `semantic_layer/metric_validation.sql`
- dbt model SQL and schema YAML files
- Dashboard query files and DAX measures

## 13. Known Limitations

- Schema names and example columns in this document must be checked against the current dbt project. The examples use `analytics_gold` as the historical physical schema name.
- Payment, return, and shipment fact models and their keys must be confirmed before the example joins can run unchanged.
- The data is mock/generated and may not include all real-world cardinality cases.
- A successful join does not prove business correctness; metric formulas and filters still require independent validation.

## 15. Summary

The safest semantic-layer joins preserve the grain of the reporting model, use validated keys, and aggregate different facts before combining them. Customer, product, and date dimensions can enrich order-item facts when their keys are unique and the relationships are tested. Payment, return, and shipment measures must be calculated at their own grains or pre-aggregated to a shared grain before being combined. These controls help keep dashboard metrics consistent and prevent silent double counting.
