# Operations Dashboard

---

## Overview

The Operations Dashboard focuses on operational performance across
orders, payments, returns, and shipments. It is intended to help
analysts identify status distributions, monitor payment outcomes,
understand return patterns, and review delivery performance.

The dashboard is part of the E-Commerce Analytics Engineering project.
It uses the project's Gold-layer reporting models in PostgreSQL,
transformed with dbt and presented through Power BI.

---

## Target Personas

**Primary audience:** Operations analysts, payment analysts,
shipping/logistics teams, and customer-service teams.

## Business Questions

The dashboard is designed to answer:

- What is the distribution of order statuses?
- How are payments distributed across statuses such as paid, refunded,
  pending, and failed?
- What is the payment success rate in the current dataset?
- Which return reasons occur most frequently?
- How many shipments have been delivered, delayed, or remain in other
  statuses?
- How many units have been returned?
- What is the total recorded refund amount?
- What is the average delivery duration among shipments with available
  delivery dates?

---

## Dashboard Contents

### KPI Cards

The dashboard includes the following headline metrics:

- **Payment Success Rate** --- successful payment records divided by
  all payment records, according to the model's
  `is_successful_payment` logic.
- **Delivered Shipments** --- shipment records marked as delivered.
- **Delayed Shipments** --- shipments flagged as delayed. Interpret
  alongside the known/unknown delay-status counts.
- **Returned Units** --- total return quantity at the return-record
  grain.
- **Total Refunded Amount** --- sum of recorded refund amounts.
- **Average Delivery Days** --- average delivery duration for
  shipments with a valid delivery duration.

---

### Visuals

1.  **Order Status Distribution**\
    Shows the distribution of orders by order status. Count distinct
    orders rather than order-item rows.

2.  **Payment Status Analysis**\
    Shows payment records grouped by payment status. Payment records and
    orders are different entities, so payment counts should not be
    labeled as order counts.

3.  **Returns by Reason**\
    Compares return records by reason. Interpret the chart at the
    return-record grain unless the query explicitly counts distinct
    orders or items.

4.  **Shipping Performance by Status**\
    Shows shipment counts by shipment status and supports operational
    review of delivery progress.

---

## Data Sources

The dashboard is backed by the project's Gold-layer facts. The
documented models include:

- `fact_order_items`
- `fact_payments`
- `fact_returns`
- `fact_shipments`
- `dim_date`

The project context records the following query file:

```text
dashboards/operations/dashboard_queries.sql
```

The two previously documented query sections are:

1.  **Order Status Distribution** --- groups by `order_status`, counts
    distinct orders, sums quantity, and sums the current net-sales
    amount.
2.  **Monthly Payment Performance** --- joins payment dates to
    `dim_date` and groups by year, month, payment method, and payment
    status.

The dashboard's returns and shipment visuals should be mapped to their
corresponding SQL queries in the final query file or documented query
mapping. Do not claim that a visual has a specific SQL backing query
until that mapping is verified.

---

## Metric Definitions and Assumptions

### Payment success rate

The recorded calculation is:

```text
Successful payment records / Total payment records
```

A previous validation recorded 224 successful payment records out of 320
payment rows, giving a 70% payment success rate. Re-run the query before
treating these figures as current.

This metric is **not** an order conversion rate.

---

### Order status

Count distinct `order_id` values when reporting order status. A single
order may contain multiple order-item rows, so counting fact rows can
overstate order volume.

---

### Returned units and refunds

- Returned units are measured using the return quantity.
- Total refunded amount is the sum of refund amounts in the return
  fact.
- Return-record counts, returned-item counts, and returned-order
  counts are different measures and should not be used
  interchangeably.

---

### Shipment delivery duration

Average delivery days should use only shipments with valid
delivery-duration values. Undelivered shipments may not have a delivery
duration and should not be silently treated as zero days.

---

### Delay rate and unknown statuses

A prior validation recorded 45 delayed and 120 not-delayed shipments
among 165 shipments with known delay status:

```text
Known-status delay rate = 45 / (45 + 120) = 27.27%
```

The same validation recorded 125 shipments with unknown delay flags and
missing delivery durations. Therefore, 27.27% is the rate among
shipments with known delay status, not among all shipments. Always
disclose the denominator and missing-status limitation.

---

## Previously Recorded Validation Results

These values were observed during an earlier validation session and must
be checked against the current database before final submission.

Metric Previously recorded value

---

Payment records 320
Successful payments 224
Payment success rate 70%
Return records 30
Returned units 61
Total refund amount 767,215.84
Shipment records 290
Delivered shipments 165
Shipments not delivered 125
Delayed shipments with known status 45
Not-delayed shipments with known status 120
Shipments with unknown delay flags 125
Average delivery duration for delivered shipments 3.89 days

---

## SQL Backing Queries

The main query file is:

```text
dashboards/operations/dashboard_queries.sql
```

Before submitting:

- Confirm the order-status query counts distinct orders.
- Confirm the payment query groups on the intended payment date,
  payment method, and payment status.
- Map the return-reason visual to the return analysis query.
- Map the shipping visual and delivery KPIs to the shipment analysis
  query.
- Check that SQL query outputs match the Power BI visuals under
  equivalent filters.
- Document any filters, null handling, or exclusions.

## Limitations and Risks

- The data is synthetic/generated and does not represent real
  operational performance.
- Historical row counts and metric values may change after
  regenerating data or rebuilding models.
- Payment success rate is based on payment records, not orders or
  website conversion events.
- Payment totals, sales totals, and refunds represent different
  business events and should not be assumed to reconcile
  automatically.
- The recorded dataset contains missing shipment delay flags and
  delivery durations for 125 shipments.
- The delay rate should use only shipments with known delay status and
  should disclose its denominator.
- Average delivery duration applies only to records with valid
  duration values.
- The observed one-to-one relationship between returns and order items
  reflects the current sample data and may not hold in a production
  business.
- The return-date relationship to the date dimension was recorded as
  inactive in Power BI. Verify that measures use the correct date
  role.
- Small sample sizes limit the strength of conclusions drawn from
  operational patterns.

---


## Related Files

- Operations SQL: `dashboards/operations/dashboard_queries.sql`
- Leadership dashboard: `dashboards/leadership/`
- Gold dbt models: `ecommerce_dbt/models/gold/`
- Semantic layer: `semantic_layer/`
- Main project documentation: `README.md`
