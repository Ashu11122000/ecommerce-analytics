# Model Grain — E-Commerce Analytics Engineering

**Purpose:** Document what one row represents in each reporting model, its expected key, supported dimensions, and the aggregation rules needed to keep metrics consistent across dbt, SQL, the semantic layer, and Power BI.

> **Verification note:** This is a proposed grain contract based on the project context available so far. Confirm model names, physical schemas, columns, and uniqueness in the current dbt project and PostgreSQL database before treating any item as verified. The project has used `analytics_gold` in prior SQL examples, but the current configured schema may differ.

## 1. What “grain” means

The grain is the business meaning of one row in a table. Declare it before defining measures or joining tables.

Examples:

- One row per order item.
- One row per customer.
- One row per product.
- One row per calendar date.
- One row per payment attempt or payment record.
- One row per return record.
- One row per shipment record.

A table can contain many columns, but its grain must still be unambiguous. If a model mixes multiple grains, aggregates can be duplicated and dashboard totals can become incorrect.

## 2. Gold model grain contract

| Model              | Expected grain                                                        | Candidate primary/unique key              | Typical dimensions                                                              | Common measures / attributes                                                            |
| ------------------ | --------------------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `dim_customers`    | One row per customer represented in the reporting model               | `customer_id`                             | Customer segment, geography, signup/acquisition attributes if present           | Descriptive attributes; customer counts should normally use distinct customer IDs       |
| `dim_products`     | One row per product represented in the reporting model                | `product_id`                              | Category, subcategory, brand, product attributes if present                     | Descriptive attributes; not a sales fact table                                          |
| `dim_date`         | One row per calendar date                                             | `date_key` or unique date column          | Date, day, week, month, quarter, year attributes                                | Calendar attributes; no additive business measures expected                             |
| `fact_order_items` | One row per order item / order line                                   | `order_item_id`                           | Order date, customer, product, order status, sales channel, currency if present | Quantity, unit price, discount, tax, line total, validated sales amounts, quality flags |
| `fact_payments`    | One row per payment record/attempt                                    | Payment ID (actual column name to verify) | Payment date, payment status, payment method, order/customer keys if present    | Payment amount, payment status and attempt attributes                                   |
| `fact_returns`     | One row per return record (or return line, depending on source/model) | Return ID or return-line ID (verify)      | Return date, return reason/status, order/product keys if present                | Returned quantity, refund amount, return status                                         |
| `fact_shipments`   | One row per shipment record                                           | Shipment ID (verify)                      | Shipment date, delivery date, shipping status/carrier if present                | Ship/delivery dates, delivery duration, delay classification                            |

**Important:** The fact models above are expected contracts, not proof that the current database has these exact tables. If the source has one row per return line rather than one row per return, update the return grain and unique key accordingly.

## 3. Grain by model — detailed contract

### 3.1 `dim_customers`

- **Expected grain:** one row per `customer_id`.
- **Unique key:** `customer_id`.
- **Purpose:** provide stable customer attributes for slicing facts.
- **Permitted joins:** many fact rows to one customer row.
- **Measures:** customer counts should generally be `COUNT(DISTINCT customer_id)` unless the source/model explicitly represents one row per customer and the filter context preserves that grain.
- **Validation:** no null customer keys; no duplicate customer keys; customer foreign keys in facts should resolve to a dimension row or an explicitly documented unknown member.
- **Potential caveat:** if the model is a Type 2 slowly changing dimension, the grain may instead be one row per customer version, with a surrogate key and effective dates. Do not use the one-row-per-customer rule if the implementation is Type 2.

### 3.2 `dim_products`

- **Expected grain:** one row per `product_id`.
- **Unique key:** `product_id`.
- **Purpose:** provide product attributes such as category and product name for reporting.
- **Permitted joins:** many fact rows to one product row.
- **Validation:** unique/non-null product key; every required product foreign key should match a dimension row or documented unknown member.
- **Caveat:** if product history is versioned, verify whether the dimension is Type 1 or Type 2 before joining by product key.

### 3.3 `dim_date`

- **Expected grain:** one row per calendar date.
- **Unique key:** `date_key` and/or a unique date column, depending on implementation.
- **Purpose:** standardize time attributes for month/week/quarter/year reporting.
- **Permitted joins:** many fact rows to one date row using the correct role-playing date key.
- **Validation:** no duplicate date rows; continuous calendar coverage for the reporting range; date key matches its represented date.
- **Caveat:** different facts can require different date roles: order date, payment date, return date, shipment date, and delivery date. Do not apply order date to payment or logistics metrics unless that is the explicitly chosen business definition.

### 3.4 `fact_order_items`

- **Expected grain:** one row per `order_item_id`.
- **Unique key:** `order_item_id`.
- **Purpose:** line-level sales, quantity, product/category analysis, and item-level quality checks.
- **Typical measures:** quantity, unit price, discount amount, tax amount, source line total, calculated line total, and approved sales amount fields.
- **Eligibility:** use the project’s validated sales eligibility flag (for example, `is_valid_for_sales`) if implemented. Keep invalid rows available for quality analysis rather than silently dropping them from every model.
- **Aggregation rules:**
  - Use `COUNT(DISTINCT order_id)` for order counts from item grain.
  - Use `COUNT(DISTINCT customer_id)` for purchasing customers.
  - Sum quantities and sales only after applying the approved eligibility rules.
  - Do not average line-level amounts to calculate AOV; divide a chosen sales total by distinct qualifying orders.
- **Potential issue:** an order can contain multiple items. Counting rows as orders will overcount orders. Summing an order-level value repeated on each item row will also overcount it.

### 3.5 `fact_payments`

- **Expected grain:** one row per payment record or attempt.
- **Unique key:** verify the actual payment identifier.
- **Purpose:** payment status, amount, method, and attempt performance.
- **Aggregation rules:**
  - Count payment attempts at payment grain.
  - Define whether “success rate” is attempt-level or order-level.
  - If an order can have multiple attempts, an attempt-level success rate is not the same as the percentage of orders eventually paid successfully.
  - Do not directly join payment rows to item rows and then sum both facts; pre-aggregate payment metrics to order or reporting-period grain first.
- **Validation:** unique payment key, status-domain checks, nonnegative/valid amounts as appropriate, and reconciliation to source totals.

### 3.6 `fact_returns`

- **Expected grain:** verify whether each row represents a return, return line, or returned product line.
- **Candidate key:** return ID if one row per return; return-line ID if multiple lines per return.
- **Purpose:** returned units, refund amounts, return reasons, and return rates.
- **Aggregation rules:**
  - Count distinct return IDs for return-record counts.
  - Sum returned quantity only at the actual return-line grain.
  - Avoid multiplying return quantities by joining to multiple order-item rows.
  - For return rate, align the sales cohort and return window or clearly label a period-based ratio.
- **Validation:** return keys, valid quantities and amounts, status filters, and matching order/product references.

### 3.7 `fact_shipments`

- **Expected grain:** one row per shipment record.
- **Unique key:** verify the shipment identifier.
- **Purpose:** shipment status, delayed shipments, delivery duration, and fulfillment performance.
- **Aggregation rules:**
  - Count distinct shipment IDs for shipment counts.
  - If orders can split into multiple shipments, do not equate shipment count with order count.
  - Calculate delivery duration only when the relevant dates are present and valid.
  - Define delayed status either from a trusted source classification or an explicit promised-versus-actual date rule.
- **Validation:** unique shipment key, status-domain checks, valid date order, and known treatment of undelivered shipments.

## 4. Safe join cardinalities

| Left model         | Right model      | Expected relationship                               | Safe use                                                               |
| ------------------ | ---------------- | --------------------------------------------------- | ---------------------------------------------------------------------- |
| `fact_order_items` | `dim_customers`  | Many-to-one                                         | Add customer attributes to item-level sales rows                       |
| `fact_order_items` | `dim_products`   | Many-to-one                                         | Add product/category attributes to item-level sales rows               |
| `fact_order_items` | `dim_date`       | Many-to-one                                         | Add calendar attributes using the correct order-date key               |
| `fact_payments`    | `dim_date`       | Many-to-one                                         | Payment trends using payment date                                      |
| `fact_returns`     | `dim_date`       | Many-to-one                                         | Return trends using return date                                        |
| `fact_shipments`   | `dim_date`       | Many-to-one                                         | Shipment/delivery trends using the chosen date role                    |
| `fact_order_items` | `fact_payments`  | Potential one-to-many or many-to-many by order      | Do not raw-join and sum both facts; aggregate payments first           |
| `fact_order_items` | `fact_returns`   | Potential one-to-many or many-to-many by order/item | Use a documented item/order key and aggregate returns before combining |
| `fact_order_items` | `fact_shipments` | Potential one-to-many by order                      | Aggregate shipment facts to order or period grain before combining     |

## 5. Example SQL validation checks

Update schema/table/column names to match the current database.

### 5.1 Duplicate order-item keys

```sql
SELECT order_item_id, COUNT(*) AS row_count
FROM analytics_gold.fact_order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;
```

Expected result: zero rows.

### 5.2 Null order-item keys

```sql
SELECT COUNT(*) AS null_order_item_keys
FROM analytics_gold.fact_order_items
WHERE order_item_id IS NULL;
```

Expected result: `0`.

### 5.3 Product foreign-key coverage

```sql
SELECT COUNT(*) AS unmatched_product_rows
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_products AS p
    ON f.product_id = p.product_id
WHERE f.product_id IS NOT NULL
  AND p.product_id IS NULL;
```

Expected result: zero, except for explicitly documented unknown/late-arriving members.

### 5.4 Customer foreign-key coverage

```sql
SELECT COUNT(*) AS unmatched_customer_rows
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_customers AS c
    ON f.customer_id = c.customer_id
WHERE f.customer_id IS NOT NULL
  AND c.customer_id IS NULL;
```

### 5.5 Check date uniqueness

Use the actual key and column names from the date dimension:

```sql
SELECT date_key, COUNT(*) AS row_count
FROM analytics_gold.dim_date
GROUP BY date_key
HAVING COUNT(*) > 1;
```

### 5.6 Verify row preservation after a dimension join

```sql
WITH base AS (
    SELECT COUNT(*) AS row_count
    FROM analytics_gold.fact_order_items
),
joined AS (
    SELECT COUNT(*) AS row_count
    FROM analytics_gold.fact_order_items AS f
    LEFT JOIN analytics_gold.dim_products AS p
        ON f.product_id = p.product_id
)
SELECT
    base.row_count AS base_rows,
    joined.row_count AS joined_rows,
    joined.row_count - base.row_count AS row_difference
FROM base
CROSS JOIN joined;
```

Expected row difference: zero for a many-to-one dimension join.

## 6. Power BI modeling implications

- Prefer a star schema: dimension tables filter facts through one-to-many relationships.
- Use single-direction filtering from dimensions to facts unless a documented requirement justifies otherwise.
- Use the unique dimension key on the “one” side and fact foreign key on the “many” side.
- Avoid directly relating multiple fact tables to one another.
- Use a dedicated date dimension and mark it as the date table where appropriate.
- If multiple date columns exist in one fact, use role-playing date dimensions or inactive relationships with explicit measures.
- Use distinct-count measures for orders and customers when querying from order-item grain.
- Validate totals in Power BI against a matching PostgreSQL query before publishing.
