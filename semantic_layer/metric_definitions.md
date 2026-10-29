# Metric Definitions — E-Commerce Analytics Engineering

**Purpose:** Establish a consistent, auditable definition for metrics used by the Gold reporting layer, semantic layer, SQL analyses, and Power BI dashboards.

> **Implementation note:** This document describes the intended metric contract based on the project context. Before treating a metric as production-ready, reconcile its formula and column names with the current dbt models and PostgreSQL schema. Historical row counts and totals are not guaranteed to match the current database. In particular, verify whether `net_sales_amount` includes tax; do not describe it as sales excluding tax unless the implementation proves that.

## 1. Metric governance rules

1. **One definition per metric.** Reuse the same formula in SQL, dbt, semantic-layer definitions, and Power BI.
2. **Declare the grain.** State the row-level grain before aggregating a fact table.
3. **Name the date field.** Use the business date intended for the metric (for example, order date for sales, payment date for payment performance, shipment/delivery date for logistics).
4. **Handle invalid data explicitly.** Do not silently include invalid order items in sales measures. Keep invalid records available for data-quality analysis.
5. **Avoid fact-to-fact fan-out.** Aggregate payments, returns, and shipments to a compatible grain before combining them with order-item sales.
6. **Document the denominator.** Rates must say which records are included and which are excluded.
7. **Distinguish zero from unknown.** Missing, invalid, or unclassified data should not automatically become zero.
8. **Label time comparisons.** State whether periods are calendar months, complete weeks, rolling windows, or partial periods.
9. **Keep monetary units consistent.** Confirm currency and tax/discount treatment before combining amounts. Do not sum multiple currencies without conversion.
10. **Separate descriptive smoothing from forecasting.** A rolling average summarizes recent history; it is not automatically a prediction of future sales.

## 2. Core sales and order metrics

| Metric                    | Definition / formula                                                                                            | Recommended grain and date                                      | Inclusion / caveats                                                                                                                                                           |
| ------------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Total orders              | Count distinct `order_id`.                                                                                      | Order; use order date.                                          | Count orders once, not once per order item. Decide and document whether cancelled/test orders are included.                                                                   |
| Purchasing customers      | Count distinct `customer_id` with at least one qualifying order.                                                | Customer over the selected period; use order date.              | State whether cancelled or invalid orders qualify.                                                                                                                            |
| Gross sales               | Sum eligible item-level gross sales according to the implemented Gold formula.                                  | `fact_order_items` row per `order_item_id`; order date.         | Exclude invalid items using the documented eligibility flag. Confirm whether gross sales is `quantity * unit_price` before discount/tax or another project-specific formula.  |
| Sales amount / line total | Sum eligible line-level amounts using one canonical field (such as `line_total` or a validated derived amount). | Order item; order date.                                         | Do not mix source `line_total`, `calculated_line_total`, and another total in the same measure. Reconcile differences first.                                                  |
| Net sales                 | Sum the project’s canonical net sales field over eligible items.                                                | Order item; order date.                                         | Confirm discount, tax, refund, and return treatment. Historical implementation suggested `net_sales_amount` may include tax; do not assume “net of tax” without verification. |
| Average order value (AOV) | Eligible sales amount divided by distinct qualifying orders.                                                    | Order; order date.                                              | Aggregate item amounts to order grain before dividing. Do not average item-level amounts or count orders once per item. Specify which sales amount is the numerator.          |
| Units sold                | Sum eligible `quantity`.                                                                                        | Order item; order date.                                         | Exclude invalid/negative quantities; document treatment of returned units. Usually sales units are gross sold units, with returned units reported separately.                 |
| Discount amount           | Sum validated discount amounts for eligible items.                                                              | Order item; order date.                                         | Confirm whether discount is stored as amount or rate and whether it is already reflected in `line_total`.                                                                     |
| Tax amount                | Sum validated item tax amounts for eligible items.                                                              | Order item; order date.                                         | Ensure tax is not added twice if the canonical line total already includes tax.                                                                                               |
| Category sales            | Sum the selected canonical sales measure grouped by product category.                                           | Order item joined many-to-one to product dimension; order date. | Confirm product dimension key is unique; use the same sales eligibility and amount rules as headline sales.                                                                   |
| Product sales ranking     | Rank products by the selected canonical sales measure.                                                          | Product over selected period; order date.                       | Define tie handling and whether invalid items, returns, or cancellations are excluded.                                                                                        |

## 3. Customer metrics

| Metric                  | Definition / formula                                                                                                            | Recommended grain and date             | Inclusion / caveats                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| New customers           | Distinct customers whose first qualifying order date falls in the selected period.                                              | Customer; first qualifying order date. | Requires a consistent first-order definition and enough historical data.                                  |
| Repeat customers        | Distinct customers with at least two qualifying orders in the selected period or lifetime, depending on the stated question.    | Customer; order date.                  | State explicitly whether repeat means within the period or across all history.                            |
| Repeat purchase rate    | Repeat customers divided by customers with at least one qualifying order in the same defined cohort/period.                     | Customer; selected period/cohort.      | The numerator and denominator must use the same qualification rules.                                      |
| Customer lifetime sales | Sum eligible sales across all qualifying orders for each customer.                                                              | Customer; order date.                  | Use a customer-level aggregate; avoid joining unaggregated payments/returns into the same rowset.         |
| Customer retention rate | Customers from a defined prior-period cohort who return in the current period divided by customers in that prior-period cohort. | Customer cohort; period pair.          | Define cohort, period length, and qualifying activity. Do not equate repeat purchase rate with retention. |

## 4. Payment metrics

| Metric               | Definition / formula                                                              | Recommended grain and date            | Inclusion / caveats                                                                                                                                                                 |
| -------------------- | --------------------------------------------------------------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Payment records      | Count payment records at payment grain.                                           | One row per payment ID; payment date. | Do not call this “orders” unless there is exactly one payment per order.                                                                                                            |
| Successful payments  | Count payment records whose normalized status is the project’s successful status. | Payment; payment date.                | Confirm exact status values and normalization.                                                                                                                                      |
| Payment success rate | Successful payment records divided by all eligible payment attempts.              | Payment; payment date.                | Document treatment of pending, cancelled, refunded, and unknown statuses. If one order has multiple attempts, this is an attempt-level rate, not an order-level rate.               |
| Payment amount       | Sum payment amounts for a clearly defined set of statuses.                        | Payment; payment date.                | State whether failed, pending, refunded, and partially captured payments are included. Never add payment amount directly to order-item sales as if it were another sales component. |

## 5. Returns and refunds

| Metric               | Definition / formula                                                                  | Recommended grain and date                                  | Inclusion / caveats                                                                                                                                                              |
| -------------------- | ------------------------------------------------------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Return records       | Count distinct return IDs.                                                            | Return; return date.                                        | One order may have multiple return records; document return status filters.                                                                                                      |
| Returned units       | Sum returned quantity for valid return records.                                       | Return item/return record; return date.                     | Ensure return quantity is not duplicated by joining to multiple order items or payments.                                                                                         |
| Refund amount        | Sum validated refund amounts for qualifying return/refund records.                    | Return/refund; refund date when available.                  | Confirm whether refund amounts are positive values and whether cancelled/rejected returns are excluded.                                                                          |
| Return rate by units | Returned units divided by eligible units sold for a compatible product/period/cohort. | Product or order item; aligned sales/return period.         | Returns may occur later than sales. Prefer cohort-based or explicitly lag-aware analysis. Do not divide returns in a period by sales in an unrelated period without labeling it. |
| Orders with returns  | Count distinct orders linked to at least one qualifying return.                       | Order; order date or return date depending on the question. | State the date basis and return-status eligibility.                                                                                                                              |

## 6. Shipping and fulfillment metrics

| Metric                    | Definition / formula                                                                    | Recommended grain and date                                   | Inclusion / caveats                                                                                             |
| ------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| Shipment records          | Count distinct shipment IDs.                                                            | Shipment; shipment creation date.                            | Do not assume one shipment per order.                                                                           |
| Delivered shipments       | Count distinct shipments classified as delivered.                                       | Shipment; delivery date or shipment date, stated explicitly. | Confirm normalized status values.                                                                               |
| Delayed shipments         | Count shipments classified as delayed using the project’s explicit rule/status.         | Shipment; shipment/delivery date.                            | Document whether delay is a source status or calculated from promised vs actual delivery date.                  |
| Delay rate                | Delayed shipments divided by shipments with a known delayed/not-delayed classification. | Shipment; shipment/delivery date.                            | Exclude unknown/unclassified statuses from denominator and report them separately.                              |
| Average delivery duration | Average elapsed days between ship date and delivery date for valid delivered shipments. | Shipment; delivery date.                                     | Exclude missing dates and negative durations; document timezone and whether calendar or business days are used. |

## 7. Data-quality metrics

| Metric                   | Definition / formula                                                                                                             | Recommended grain and date           | Inclusion / caveats                                                                                     |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Invalid order items      | Count order-item rows failing the documented sales eligibility rules.                                                            | Order item; order date.              | Keep a reason-level breakdown where possible.                                                           |
| Line-total mismatches    | Count rows where source line total differs from the validated calculated amount beyond the agreed tolerance (historically 0.01). | Order item; order date.              | Confirm the calculation formula and rounding policy before use.                                         |
| Negative-quantity rows   | Count order-item rows where quantity is less than zero.                                                                          | Order item; order date.              | Do not silently convert negative values to zero.                                                        |
| Unmatched dimension keys | Count fact rows without a matching dimension row for a required foreign key.                                                     | Fact row; associated business date.  | Distinguish legitimate unknown/late-arriving dimension members from true referential-integrity defects. |
| Duplicate fact keys      | Count duplicate occurrences of the declared unique fact identifier.                                                              | Fact row.                            | For `fact_order_items`, expected unique key is `order_item_id`.                                         |
| Reconciliation variance  | Difference between two clearly identified measures, e.g. source line total and calculated line total.                            | Order item or aggregate; order date. | Keep sign convention and tolerance consistent.                                                          |

## 8. Time comparisons, growth, and trend metrics

| Metric                        | Definition / formula                                                                             | Recommended grain and date                | Inclusion / caveats                                                                                                                                                   |
| ----------------------------- | ------------------------------------------------------------------------------------------------ | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Month-over-month (MoM) change | Current complete calendar-month value minus previous complete calendar-month value.              | Month; metric’s documented date field.    | Compare equivalent, complete periods. Handle prior value zero/null explicitly.                                                                                        |
| MoM growth rate               | `(current period value - prior period value) / prior period value * 100`.                        | Month.                                    | If prior period is zero or null, return NULL/“not applicable”, not infinity or an arbitrary zero.                                                                     |
| Week-over-week (WoW) growth   | Same formula using consecutive, consistently defined weeks.                                      | Week; state week start and timezone.      | Compare complete weeks; do not compare partial current week with a full prior week without a warning.                                                                 |
| Year-over-year (YoY) growth   | `(current period value - same period previous year value) / prior-year value * 100`.             | Month/year or equivalent calendar period. | Account for missing periods and calendar differences; do not infer YoY where history is insufficient.                                                                 |
| Rolling 3-month average       | Average of the current and two preceding monthly values, using a clearly defined monthly series. | Month.                                    | Decide whether months with no sales count as zero or are missing. This is smoothing, not by itself a forecast.                                                        |
| Forecast                      | A future-period estimate produced by a named method, such as rolling average or linear trend.    | Future period.                            | Document training window, horizon, method, limitations, and whether output is a true out-of-sample estimate. Do not label a historical rolling average as a forecast. |
| Anomaly / spike               | A value meeting an explicit threshold or statistical rule compared with a baseline.              | Metric-period (e.g. daily or monthly).    | Define baseline, threshold, minimum history, seasonality handling, and whether the result is a flag for review rather than proof of an issue.                         |

## 9. Recommended canonical Power BI / semantic-layer measures

Use the current verified model names. The following DAX is illustrative and must be adjusted to actual table/column names and relationships.

```DAX
Total Orders =
DISTINCTCOUNT ( fact_order_items[order_id] )

Purchasing Customers =
DISTINCTCOUNT ( fact_order_items[customer_id] )

Units Sold =
CALCULATE (
    SUM ( fact_order_items[quantity] ),
    fact_order_items[is_valid_for_sales] = TRUE ()
)

Eligible Sales Amount =
CALCULATE (
    SUM ( fact_order_items[net_sales_amount] ),
    fact_order_items[is_valid_for_sales] = TRUE ()
)

Average Order Value =
DIVIDE ( [Eligible Sales Amount], [Total Orders] )

Payment Success Rate =
DIVIDE ( [Successful Payments], [Eligible Payment Attempts] )

MoM Sales Growth % =
DIVIDE (
    [Eligible Sales Amount] - [Prior Month Sales Amount],
    [Prior Month Sales Amount]
)
```

## **Important DAX notes**

- `Total Orders` from an order-item fact counts an order once with `DISTINCTCOUNT`, but only counts orders represented in that fact. If orders with zero items or cancelled-only orders must be counted, use a suitable order-grain fact/table.
- `Purchasing Customers` from the order-item fact counts customers represented in that fact; it is not necessarily all registered customers.
- The sales measure assumes `net_sales_amount` is the approved canonical sales measure. Confirm its tax/discount/return treatment first.
- `Payment Success Rate` needs payment-grain measures and should not be calculated on a duplicated join to order items.
- The MoM measure requires a continuous/appropriate date dimension, a proper relationship, and a prior-month measure. DAX is a template, not guaranteed drop-in code.

## 10. Example SQL patterns

### Eligible sales by month

```sql
SELECT
    DATE_TRUNC('month', order_date)::date AS sales_month,
    SUM(net_sales_amount) AS eligible_sales_amount
FROM analytics_gold.fact_order_items
WHERE is_valid_for_sales = TRUE
GROUP BY 1
ORDER BY 1;
```

### MoM growth with zero-safe division

```sql
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date)::date AS sales_month,
        SUM(net_sales_amount) AS sales_amount
    FROM analytics_gold.fact_order_items
    WHERE is_valid_for_sales = TRUE
    GROUP BY 1
),
with_prior AS (
    SELECT
        sales_month,
        sales_amount,
        LAG(sales_amount) OVER (ORDER BY sales_month) AS prior_month_sales
    FROM monthly_sales
)
SELECT
    sales_month,
    sales_amount,
    prior_month_sales,
    sales_amount - prior_month_sales AS mom_change,
    (sales_amount - prior_month_sales)
        / NULLIF(prior_month_sales, 0) AS mom_growth_rate
FROM with_prior
ORDER BY sales_month;
```

### Payment success rate

```sql
SELECT
    COUNT(*) FILTER (WHERE LOWER(payment_status) = 'successful') AS successful_payment_attempts,
    COUNT(*) FILTER (
        WHERE LOWER(payment_status) IN ('successful', 'failed', 'declined')
    ) AS eligible_payment_attempts,
    COUNT(*) FILTER (WHERE LOWER(payment_status) = 'successful')::numeric
        / NULLIF(
            COUNT(*) FILTER (
                WHERE LOWER(payment_status) IN ('successful', 'failed', 'declined')
            ),
            0
        ) AS payment_success_rate
FROM analytics_gold.fact_payments;
```

Verify status values (`successful`, `failed`, `declined`) against current data before using this query.

## 11. Metric ownership and change control

- **Data engineering / dbt:** owns grain, model keys, eligibility flags, source reconciliation, and data-quality rules.
- **Analytics / semantic layer:** owns approved metric names, formulas, date semantics, and join-safe aggregations.
- **Dashboard author:** uses approved metrics; does not create conflicting local variants without documenting them.
- **Change procedure:** update the definition, model implementation, tests, SQL backing the visual, Power BI measure, and README together.
- **Versioning:** when formulas change, record the date, reason, affected dashboards, and whether historical values will change.
