# Leadership Dashboard

---

## Overview

The Leadership Dashboard provides a high-level view of e-commerce
performance for business leaders and management. It summarizes sales,
order activity, purchasing customers, product performance, and changes
in sales over time.

The dashboard is part of the E-Commerce Analytics Engineering project.
It uses analytics-ready Gold-layer data in PostgreSQL, transformed with
dbt, and is presented in Power BI.

---

## Target Persona

**Primary audience:** Business leaders, executives, and management.

## Business Questions

This dashboard is designed to answer:

- What sales value is represented in the current dataset?
- How many distinct orders and purchasing customers are represented?
- How many units were sold?
- What is the average sales value per order?
- Which product categories contribute the most sales?
- Which products have the highest sales?
- How is monthly sales performance changing?
- What does month-over-month sales growth indicate?

---

## Dashboard Contents

### KPI Cards

The dashboard includes these headline metrics:

- **Total Orders** --- distinct eligible orders, not the number of
  order-item rows.
- **Purchasing Customers** --- distinct customers with eligible sales.
- **Units Sold** --- quantity from order items that meet the sales
  eligibility rules.
- **Gross Sales** --- quantity multiplied by unit price, subject to
  the agreed eligibility rules.
- **Net Sales** --- use the definition documented in the semantic
  layer and Power BI measure. In the current project, the
  `net_sales_amount` field has been observed to behave like the final
  line total including tax; do not describe it as sales excluding tax
  unless the model is changed.
- **Average Order Value** --- net sales divided by distinct eligible
  orders, provided both measures use consistent filters and
  definitions.

---

### Visuals

1.  **Monthly Net Sales Trend**\
    Shows sales by chronological month to make trends and changes over
    time visible.

2.  **Net Sales by Product Category**\
    Compares sales contribution across product categories.

3.  **Top Products by Net Sales**\
    Highlights products with the largest recorded sales amounts.

4.  **Month-over-Month Sales Growth**\
    Compares the current month's sales with the previous month's sales.
    Interpret the measure only after verifying the date relationship,
    time context, and zero/blank handling.

---

## Data Sources

The dashboard is backed by the Gold reporting layer. Main models used by
the project include:

- `gold.fact_order_items`
- `gold.dim_customers`
- `gold.dim_products`
- `gold.dim_date`

The actual schema names in PostgreSQL may be `analytics_gold` rather
than `gold`, depending on the dbt schema configuration. Confirm the
active database and Power BI table names before editing queries.

---

## SQL Backing Queries

The leadership dashboard query file is:

```text
dashboards/leadership/dashboard_queries.sql
```

The project context records six query sections in that file:

1.  Executive KPI summary.
2.  Monthly sales trend.
3.  Sales by product category.
4.  Top 10 products.
5.  Month-over-month/year-over-year growth.
6.  Three-month rolling average.

The product/category joins were corrected to join the fact and dimension
tables on the product key:

```sql
f.product_id = p.product_id
```

Before submission, verify that each visual's measure and filters match
the corresponding SQL query. Compilation or successful execution of a
query does not, by itself, prove that the Power BI visual uses the same
definition.

---

## Metric Definitions and Assumptions

### Sales eligibility

The recorded project rules require valid quantity and financial inputs
and a reconciled line total. The Gold model includes
`is_valid_for_sales` to identify records eligible for sales reporting.

Use the eligibility flag consistently for sales and units. Invalid rows are retained for audit and their financial measures are null under the recorded model design.

---

### Gross sales and line total

The documented calculation is:

```text
Gross sales = quantity × unit_price

Calculated final line total
    = (quantity × unit_price)
      - discount_amount
      + tax_amount
```

The recorded `line_total` is retained for reconciliation against the
calculated value. Confirm the agreed business definition of "Net Sales"
before presenting it externally. A final line total that includes tax
can be greater than gross sales before discounts and tax; that
difference alone does not establish a data error.

---

### Order count

Count distinct `order_id` values. An order can contain multiple
order-item rows, so counting fact rows would overstate order volume.

---

### Purchasing customers

Count distinct `customer_id` values among eligible sales records.

---

### Average Order Value

Use:

```text
Average Order Value = Net Sales / Total Orders
```

This is meaningful only when the numerator and denominator use
compatible filters, eligibility rules, and the same reporting period.

---

### Time comparisons

Month-over-month growth is:

```text
(Current month sales - Previous month sales)
÷ Previous month sales
```

Confirm the implementation handles a missing or zero previous-month
value and uses a chronological date field. Year-over-year growth should
only be reported where sufficient historical periods exist.

---

## Previously Recorded Validation Results

The following values were recorded during an earlier validation session
and are included as historical context. Re-run the queries against the
current database before treating them as final results.

Metric Previously recorded value

---

Total orders 320
Purchasing customers 109
Units across all order-item rows 1,976
Units across eligible sales rows 1,975
Gross sales 25,281,271.32
Current line-total-based net sales 25,347,841.41
Average net sales per order 79,212.00

Two order-item records were previously flagged as invalid for sales.
Therefore, the total quantity across all rows differs from the eligible
quantity. Financial metrics should follow the eligibility rules and the
agreed definition of net sales.

---

## Limitations

- The data is synthetic/generated and should not be presented as
  actual business performance.
- Historical counts and totals may change if the generator, source
  data, or dbt models change.
- The current `net_sales_amount` behaves like a final line total
  including tax; document this explicitly.
- The dataset is relatively small and is intended for demonstration
  rather than statistically representative business conclusions.
- Month-over-month and year-over-year metrics depend on correct date
  relationships and adequate date coverage.
- A rolling average smooths historical data; it is not a future
  forecast by itself.

---

## Related Files

- SQL queries: `dashboards/leadership/dashboard_queries.sql`
- Operations dashboard: `dashboards/operations/`
- Semantic layer: `semantic_layer/`
- Gold dbt models: `ecommerce_dbt/models/gold/`
- Metric definitions: `docs/metric_definitions.md` and
  `semantic_layer/metric_definitions.md`
- Main project documentation: `README.md`
