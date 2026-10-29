# Semantic Layer: Dimensions

## 1. Purpose

This document defines the business dimensions used to filter, group, and interpret metrics in the E-Commerce Analytics Engineering reporting layer.

Dimensions provide descriptive context for facts. They should be used consistently across SQL analyses, semantic definitions, and dashboards so that the same metric produces comparable results across business views.

The dimension definitions below reflect the project architecture and reporting requirements. Confirm each model and column against the current dbt models and PostgreSQL database before treating it as an implemented schema contract.

## 2. Dimension Inventory

| Dimension           | Expected model                                                                  | Intended grain                                                          | Primary identifier                               | Main analytical use                                           |
| ------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------- |
| Customer            | `dim_customers`                                                                 | One row per customer, unless historical versions are explicitly modeled | `customer_id`                                    | Customer activity, customer counts, sales by customer or city |
| Product             | `dim_products`                                                                  | One row per product, unless historical versions are explicitly modeled  | `product_id`                                     | Product performance, category analysis, units sold            |
| Date                | `dim_date`                                                                      | One row per calendar date                                               | Date key or calendar-date column, as implemented | Daily/monthly trends, MoM/YoY comparisons, date filtering     |
| Order attributes    | Usually sourced through the order-item fact or an order dimension if one exists | Depends on the model; do not assume one row per order without checking  | `order_id` where available                       | Order status and order-level analysis                         |
| Payment attributes  | Usually represented in `fact_payments` or a related payment model               | Payment-level only if the payment model is one row per payment          | Payment identifier defined by the model          | Payment method, payment status, payment success analysis      |
| Return attributes   | Usually represented in `fact_returns` or a related return model                 | Return-level only if the model is one row per return                    | Return identifier defined by the model           | Return reason/status, refund and returned-unit analysis       |
| Shipment attributes | Usually represented in `fact_shipments` or a related shipment model             | Shipment-level only if the shipment model is one row per shipment       | Shipment identifier defined by the model         | Delivery status, delay analysis, delivery duration            |

**Important:** The first three entries are the core descriptive dimensions documented for the reporting layer. Order, payment, return, and shipment fields may be attributes on facts rather than separate dimension tables. Do not refer to them as standalone dimensions unless corresponding models exist.

## 3. Customer Dimension — `dim_customers`

### Purpose

Provides customer context for sales and activity analysis.

### Expected grain

One row per `customer_id`, unless the implementation explicitly stores multiple historical versions of a customer.

### Identifier

- Primary identifier: `customer_id`

### Typical attributes

The actual columns depend on the current model. Expected examples include:

| Attribute        | Description                                       | Example analytical use                           |
| ---------------- | ------------------------------------------------- | ------------------------------------------------ |
| `customer_id`    | Stable customer identifier                        | Count distinct customers; join to eligible facts |
| `customer_name`  | Customer name, if retained in the reporting model | Customer-level reporting where appropriate       |
| `city`           | Customer city, if available                       | Geographic grouping                              |
| `signup_date`    | Date the customer registered, if available        | Signup cohort or acquisition-period analysis     |
| Audit timestamps | Ingestion or modeling metadata, if present        | Pipeline troubleshooting and data lineage        |

Only include personal/contact attributes such as email in analytical models when there is a clear need. Avoid exposing unnecessary personal information in dashboards.

### Relationship rules

- Join a fact to `dim_customers` using the validated customer key, commonly `customer_id`.
- Confirm that `dim_customers.customer_id` is unique before joining.
- If a fact contains a customer key that does not match the dimension, investigate the relationship test failure or document the missing/unknown-customer handling rule.
- When counting customers, use the distinct customer identifier at the intended reporting grain.

### Metrics supported

- Distinct purchasing customers, subject to the selected eligible facts and date filters.
- Sales by customer, where customer-level reporting is permitted.
- Customer activity by city or signup period, if the relevant attributes and dates exist.

A customer count from `dim_customers` is not automatically the same as the number of purchasing customers in a period. The latter should normally be calculated from the relevant fact records under the metric's documented filters.

## 4. Product Dimension — `dim_products`

### Purpose

Provides product context for product and category reporting.

### Expected grain

One row per `product_id`, unless historical product versions are explicitly modeled.

### Identifier

- Primary identifier: `product_id`

### Typical attributes

| Attribute        | Description                                | Example analytical use                                        |
| ---------------- | ------------------------------------------ | ------------------------------------------------------------- |
| `product_id`     | Stable product identifier                  | Join fact records to product descriptions                     |
| `product_name`   | Product name, if available                 | Top-products analysis                                         |
| `category`       | Product category, if available             | Category sales and units analysis                             |
| `price`          | Product catalog price, if available        | Product context; not necessarily the actual transaction price |
| Audit timestamps | Ingestion or modeling metadata, if present | Data lineage and troubleshooting                              |

### Relationship rules

- Join the order-item fact to `dim_products` using the validated product key, commonly `product_id`.
- Confirm that the dimension key is unique to prevent fact-row multiplication.
- Use the transaction-level unit price from the fact when calculating historical sales. Do not replace it with the current catalog price unless the metric specifically calls for catalog-price analysis.
- Handle unmatched product identifiers explicitly rather than silently dropping the fact rows.

### Metrics supported

- Sales by product and category.
- Units sold by product and category.
- Top products by an explicitly named sales or quantity metric.
- Product mix and contribution, when the denominator is defined consistently.

## 5. Date Dimension — `dim_date`

### Purpose

Provides a shared calendar for consistent filtering and time-based comparisons.

### Expected grain

One row per calendar date.

### Potential attributes

Use only columns that actually exist in the current dbt model. Common calendar attributes include:

| Attribute        | Description                                              |
| ---------------- | -------------------------------------------------------- |
| Date key         | Surrogate or natural key for the calendar date           |
| Calendar date    | Actual date represented by the row                       |
| Year             | Calendar year                                            |
| Quarter          | Calendar quarter                                         |
| Month number     | Numeric month, 1–12                                      |
| Month name/label | Human-readable month                                     |
| Year-month label | Month label that sorts chronologically                   |
| Week identifier  | Week definition used for WoW comparisons, if implemented |
| Day of week      | Day-of-week grouping, if implemented                     |

### Relationship rules

- Join facts to the date dimension using the date key or date column specified by the model.
- Confirm that the date key is unique and that the dimension covers the reporting period.
- Sort year-month labels by a numeric or date key rather than alphabetically.
- Define the calendar convention for week-based comparisons (for example, ISO week or another explicit convention) before reporting WoW.
- Choose the correct business date for each metric. Order date, payment date, return date, and shipment/delivery date answer different questions.

### Metrics and analyses supported

- Daily, monthly, quarterly, and yearly trends.
- Month-over-month and year-over-year comparisons.
- Week-over-week comparisons if week attributes and matching logic are implemented.
- Rolling averages and forecast features when supported by the relevant date series.

A date dimension does not itself define a forecast. The forecast method, time horizon, and treatment of incomplete periods must be documented separately.

## 6. Order, Payment, Return, and Shipment Attributes

Some reporting fields are not necessarily separate dimensions. They may be attributes in the relevant fact model or be supplied through upstream Silver models. Confirm the current model structure before creating relationships.

### 6.1 Order attributes

Examples include `order_id`, `order_status`, `order_date`, and `sales_channel` where present.

- Use `order_id` to count orders distinctly.
- Order status analysis should count distinct orders, not fact rows, unless the intended measure is explicitly order-item rows.
- Document the status domain and how null, unknown, or unexpected statuses are handled.

### 6.2 Payment attributes

Examples include payment identifier, `payment_method`, payment status, transaction reference, amount, and payment date where present.

- Use payment-grain records to calculate payment success rate.
- Define which statuses qualify as successful and which records are excluded as unknown.
- Payment success rate is not the same as order conversion rate.
- Do not sum payment amounts after joining to a higher-cardinality order-item table unless the join has been safely aggregated.

### 6.3 Return attributes

Examples include return identifier, return reason/status, returned quantity, refund amount, and return date where present.

- Calculate return and refund metrics at the return grain before combining with other facts.
- Clearly distinguish returned units, number of return records, and number of returned orders.
- Document whether pending, rejected, or cancelled returns contribute to each metric.

### 6.4 Shipment attributes

Examples include shipment identifier, shipping status, shipment date, delivery date, delivery duration, and delay classification where present.

- Calculate shipment metrics at shipment grain.
- Document how unknown delay classifications and missing delivery durations are treated.
- A delay rate should state its denominator. If only shipments with known delay status are counted, explicitly say so.
- Do not assume one shipment per order unless verified.

## 7. Join and Fan-Out Safeguards

Before joining a dimension to a fact, validate the dimension key's uniqueness. Before joining facts together, confirm the grain of both sides and whether the join is one-to-one, one-to-many, or many-to-many.

Recommended checks include:

1. Confirm the declared primary identifier is unique and non-null.
2. Run dbt relationship tests for expected fact-to-dimension keys.
3. Compare row counts and key counts before and after joins.
4. Reconcile additive measures before and after joining.
5. Aggregate facts to a shared reporting grain before combining multiple fact tables.
6. Preserve or explicitly label unmatched keys rather than silently excluding records.

For example, multiple payment rows and multiple shipment rows for the same order can multiply each other when joined directly. Aggregate each fact to the desired order or date grain first, or use separate measures with safe relationship logic.

## 8. Naming and Semantic Consistency

Use the same dimension names and definitions in SQL, dbt documentation, semantic-layer files, and dashboard labels.

- Use `customer_id`, `product_id`, and `order_id` consistently where those keys exist.
- Distinguish order counts, order-item counts, payment counts, return counts, and shipment counts.
- Use transaction-level fact amounts for historical financial metrics; a current product catalog price is not a substitute.
- Use the date that matches the business question.
- Document filters, status mappings, unknown-value handling, and excluded records alongside each metric.
- Avoid presenting a dimension attribute as available until its presence in the current model has been verified.

## 9. Validation Checklist

Before publishing or changing a dashboard:

- [ ] Confirm each listed dimension model exists in the current dbt project and database.
- [ ] Confirm the dimension's grain and primary identifier from the SQL model.
- [ ] Check primary identifiers for nulls and duplicates.
- [ ] Confirm fact-to-dimension relationships.
- [ ] Confirm the date dimension covers the required dates and sorts correctly.
- [ ] Verify that joins do not increase fact-row counts unexpectedly.
- [ ] Reconcile sales, payment, return, and shipment measures at their intended grains.
- [ ] Confirm dashboard labels match the semantic metric definitions.
- [ ] Update this file when the model schema or business definitions change.

## 10. Known Limitations

- This document describes the intended semantic contract; it is not a substitute for inspecting the current dbt SQL and database schema.
- The project uses generated/mock e-commerce data, so the dimensions and observed distributions may not reflect a production system.
- Some attributes listed as typical or potential may not exist in the current implementation.
- Historical versions of customer or product attributes are not implied unless snapshots or slowly changing dimension logic have been implemented.
- Week-based comparisons require an explicit week convention and verified date logic.
- The grain and relationships of payment, return, and shipment models must be confirmed from their current SQL before they are treated as guaranteed.

## 11. Summary

The core descriptive dimensions are customers, products, and dates. They provide reusable context for filtering and grouping the Gold facts. Order, payment, return, and shipment attributes should be treated according to their actual model placement and grain, rather than assumed to be separate dimensions. Reliable reporting depends on validated keys, safe joins, consistent business definitions, and clear documentation of unavailable or unknown data.
