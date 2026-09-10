# E-Commerce Analytics Engineering Project

## Project Overview

This project is an end-to-end **Data Engineering and Analytics Engineering** project built using **PostgreSQL** and **dbt Core**.

The project simulates a small but realistic e-commerce analytics pipeline where raw transactional data is loaded into PostgreSQL and transformed into analytics-ready datasets using dbt.

The complete pipeline follows an **ELT (Extract, Load, Transform)** approach and implements:

- Raw OLTP-style source tables.
- dbt source definitions.
- Bronze, Silver, and Gold transformation layers.
- Dimensional modeling.
- A Star Schema.
- Dimension and fact tables.
- Data quality testing.
- Generic and custom dbt tests.
- Incremental processing.
- Late-arriving data handling.
- Backfill strategy.
- Source freshness configuration.
- Reusable dbt macros.
- Analytical SQL queries.
- Data lineage through dbt model dependencies.
- Audit and technical timestamps.

The final Gold layer provides analytics-ready tables for reporting, dashboards, and business analysis.

---

# Project Objectives

The main goal is to build a simple but realistic analytics engineering pipeline.

The project performs the following steps:

1. Creates a PostgreSQL database.
2. Creates raw OLTP-style source tables.
3. Generates and loads mock e-commerce transactional data.
4. Defines raw source tables in dbt.
5. Transforms raw data into the Bronze layer.
6. Cleans, standardizes, and enriches data in the Silver layer.
7. Builds analytics-ready dimension and fact tables in the Gold layer.
8. Applies data quality tests.
9. Implements incremental processing for the order-item fact.
10. Simulates late-arriving and updated data.
11. Documents a backfill strategy.
12. Runs analytical SQL queries on the Gold layer.
13. Validates the project using dbt commands such as `dbt parse`, `dbt run`, `dbt test`, and `dbt build`.

---

# Technology Stack

| Technology | Purpose |
| --- | --- |
| PostgreSQL | Local relational database, raw source store, and transformation destination |
| dbt Core | SQL-based transformation and analytics engineering framework |
| dbt-postgres | PostgreSQL adapter for dbt |
| Python | Mock data generation and local development environment |
| SQL | Data definition, data loading, transformation, and analytics |
| Jinja | dbt templating and reusable logic |
| Git | Version control |
| GitHub | Remote repository hosting |
| PowerShell | Local development environment |

---

# Project Architecture

```text
                         MOCK / OLTP-STYLE DATA
                                  │
                                  ▼
                         ┌─────────────────┐
                         │   PostgreSQL    │
                         │                 │
                         │   RAW LAYER     │
                         │                 │
                         │ customers       │
                         │ products        │
                         │ orders          │
                         │ order_items     │
                         │ payments        │
                         │ shipments       │
                         │ returns         │
                         └────────┬────────┘
                                  │
                                  │ dbt source()
                                  ▼
                         ┌─────────────────┐
                         │  BRONZE LAYER   │
                         │                 │
                         │ Basic cleaning  │
                         │ Standardization │
                         │ Audit metadata  │
                         └────────┬────────┘
                                  │
                                  │ dbt ref()
                                  ▼
                         ┌─────────────────┐
                         │  SILVER LAYER   │
                         │                 │
                         │ Cleaned data    │
                         │ Business rules │
                         │ Derived fields │
                         │ DQ logic        │
                         └────────┬────────┘
                                  │
                                  │ dbt ref()
                                  ▼
                         ┌─────────────────┐
                         │   GOLD LAYER    │
                         │                 │
                         │ Dimensions      │
                         │ Facts           │
                         │ Analytics-ready │
                         └────────┬────────┘
                                  │
                                  ▼
                         Analytics / BI / SQL
```

The major transformation flow is:

```text
RAW
 ↓
BRONZE
 ↓
SILVER
 ↓
GOLD
```

Cross-cutting engineering concerns include:

```text
Data Quality
     │
Lineage
     │
Freshness
     │
Incremental Processing
     │
Late-Arriving Data
     │
Backfills
     │
Audit Metadata
```

---

# Data Engineering Lifecycle

```text
Data Generation
      ↓
Data Ingestion
      ↓
Raw Storage
      ↓
Data Transformation
      ↓
Data Cleaning
      ↓
Business Logic
      ↓
Dimensional Modeling
      ↓
Data Quality Testing
      ↓
Analytics-Ready Tables
      ↓
Business Analysis
```

---

# ELT Architecture

This project follows the **ELT workflow**:

```text
Extract
   │
   ▼
Mock E-Commerce Data
   │
   ▼
Load
   │
   ▼
PostgreSQL RAW Tables
   │
   ▼
Transform
   │
   ▼
dbt Models
   │
   ▼
Bronze → Silver → Gold
```

Unlike a traditional ETL workflow, transformation is performed after the data has been loaded into PostgreSQL.

In this project:

- Python generates the mock source data.
- SQL loads the data into PostgreSQL.
- dbt performs the transformations inside PostgreSQL.

---

# PostgreSQL Database

The local PostgreSQL database is:

```text
ecommerce_analytics
```

The database contains the raw schema and dbt-generated schemas:

```text
ecommerce_analytics
│
├── raw
├── analytics_bronze
├── analytics_silver
└── analytics_gold
```

Because dbt combines the configured target schema with model-level schema configuration, the generated schemas are named `analytics_bronze`, `analytics_silver`, and `analytics_gold` in the current project.

---

# Database Schemas

## Raw

```text
raw
```

Tables:

```text
raw.customers
raw.products
raw.orders
raw.order_items
raw.payments
raw.shipments
raw.returns
```

These simulate an **OLTP-style e-commerce source system**.

## Bronze

```text
analytics_bronze
```

Models:

```text
bronze_customers
bronze_products
bronze_orders
bronze_order_items
bronze_payments
bronze_shipments
bronze_returns
```

Bronze models are dbt views.

## Silver

```text
analytics_silver
```

Models:

```text
silver_customers
silver_products
silver_orders
silver_order_items
silver_payments
silver_shipments
silver_returns
```

Silver models are dbt views.

## Gold

```text
analytics_gold
```

Models:

```text
dim_customers
dim_products
dim_date
fact_order_items
fact_payments
```

Gold contains analytics-ready dimensional models. `fact_order_items` is incremental; the other Gold models are tables.

---

# Raw Data Model

The current Raw layer contains **seven source tables**.

## `raw.customers`

Stores customer information.

```text
customer_id
customer_name
email
phone
gender
date_of_birth
city
state
country
postal_code
customer_segment
customer_status
signup_date
updated_at
ingested_at
```

Primary key:

```text
customer_id
```

## `raw.products`

Stores product information.

```text
product_id
product_name
category
subcategory
brand
supplier_id
cost_price
selling_price
stock_quantity
reorder_level
product_status
launch_date
updated_at
ingested_at
```

Primary key:

```text
product_id
```

## `raw.orders`

Stores order-level information.

```text
order_id
customer_id
order_date
order_status
payment_status
shipping_method
shipping_cost
discount_amount
tax_amount
total_amount
sales_channel
currency
updated_at
ingested_at
```

Primary key:

```text
order_id
```

Foreign key:

```text
customer_id → raw.customers.customer_id
```

## `raw.order_items`

Stores individual product lines within orders.

```text
order_item_id
order_id
product_id
quantity
unit_price
discount_amount
tax_amount
line_total
returned_quantity
updated_at
ingested_at
```

Primary key:

```text
order_item_id
```

Foreign keys:

```text
order_id   → raw.orders.order_id
product_id → raw.products.product_id
```

## `raw.payments`

Stores payment transactions.

```text
payment_id
order_id
payment_date
payment_method
payment_status
amount
transaction_reference
updated_at
ingested_at
```

Primary key:

```text
payment_id
```

Foreign key:

```text
order_id → raw.orders.order_id
```

## `raw.shipments`

Stores shipment information.

```text
shipment_id
order_id
shipping_method
shipment_status
shipped_at
delivered_at
delivery_city
delivery_state
updated_at
ingested_at
```

Primary key:

```text
shipment_id
```

Foreign key:

```text
order_id → raw.orders.order_id
```

## `raw.returns`

Stores product return information.

```text
return_id
order_item_id
return_date
return_reason
return_quantity
refund_amount
return_status
updated_at
ingested_at
```

Primary key:

```text
return_id
```

Foreign key:

```text
order_item_id → raw.order_items.order_item_id
```

---

# OLTP-Style Source Model

```text
customers
    │
    │ customer_id
    ▼
orders
    │
    │ order_id
    ▼
order_items
    │
    ├──────────────► products
    │
    └──────────────► returns

orders
  │
  ├──────────────► payments
  │
  └──────────────► shipments
```

Business relationships:

- One customer can place many orders.
- One order can contain many order items.
- One product can appear in many order items.
- One order can have a payment record.
- One order can have a shipment record.
- An order item can have a return record.

---

# Controlled Source Data Volume

The current generated RAW dataset contains:

| Table | Records |
| --- | ---: |
| `customers` | **120** |
| `products` | **500** |
| `orders` | **320** |
| `order_items` | **632** |
| `payments` | **320** |
| `shipments` | **290** |
| `returns` | **30** |

The `order_items` count is 632 because the generator creates multiple product lines per order.

The generator uses random seed:

```text
42
```

This makes the mock dataset reproducible.

---

# Controlled Data Quality Scenarios

The generated source data demonstrates:

| Scenario | Current Result |
| --- | --- |
| NULL customer phones | **7 records** |
| Inconsistent product category casing | **1 record** |
| Negative quantities | **0 records** |
| Incorrect line total | **1 record** |
| Late-arriving order | **order_id = 320** |
| Updated order | **order_id = 10** |

The negative-quantity scenario was removed from the generator so that the final positive-value custom test passes.

The incorrect line-total scenario remains intentionally so the Silver layer can demonstrate reconciliation logic.

---

# Medallion Architecture

The project uses a simplified **Medallion Architecture**:

```text
RAW
 ↓
BRONZE
 ↓
SILVER
 ↓
GOLD
```

Each layer has a different responsibility.

## Raw

The Raw layer stores source data close to its original structure.

Responsibilities:

- Store ingested data.
- Preserve source-level structure.
- Represent transactional data.
- Provide the starting point for dbt transformations.
- Preserve ingestion and update metadata.

## Bronze

Responsibilities:

- Read source tables through `source()`.
- Perform basic cleaning.
- Standardize values.
- Handle simple NULL/default cases where appropriate.
- Preserve source-oriented structure.
- Add technical metadata.
- Provide a controlled interface between Raw and downstream models.

Examples:

```sql
TRIM()
LOWER()
INITCAP()
COALESCE()
NULLIF()
```

Example:

```sql
LOWER(TRIM(email))
```

This removes surrounding whitespace and standardizes email casing.

Bronze generally contains minimal business logic.

## Silver

Responsibilities:

- Clean and standardize data.
- Apply business rules.
- Create derived business attributes.
- Calculate analytical helper metrics.
- Add data-quality indicators.
- Prepare reusable datasets for Gold.

Examples:

```text
customer_age
age_group
customer_tenure_days
customer_status_group
profit_amount
profit_margin_pct
stock_status
price_band
order_status_group
is_payment_successful
is_late_arriving
ingestion_delay_days
calculated_line_total
line_total_variance
is_line_total_mismatch
has_negative_quantity
has_return
return_rate
payment_status_group
delivery_days
delivery_speed
is_delivery_delayed
```

## Gold

The Gold layer contains analytics-ready models:

```text
dim_customers
dim_products
dim_date
fact_order_items
fact_payments
```

It is designed for reporting, BI, dashboards, aggregation, and business analysis.

---

# Gold Dimensional Model

## `dim_customers`

Purpose:

```text
Who is the customer?
```

Important fields:

```text
customer_id
customer_name
email
gender
age_group
city
state
country
postal_code
customer_segment
customer_status_group
signup_date
customer_age
customer_tenure_days
is_active_customer
customer_lifecycle_stage
ingested_at
loaded_at
transformed_at
modeled_at
```

## `dim_products`

Purpose:

```text
What product is involved?
```

Important fields:

```text
product_id
product_name
category
subcategory
brand
supplier_id
cost_price
selling_price
profit_amount
profit_margin_pct
profit_margin_band
stock_quantity
reorder_level
stock_status
price_band
product_status
is_active_product
launch_date
ingested_at
loaded_at
transformed_at
modeled_at
```

## `dim_date`

Purpose:

```text
When did the business event happen?
```

Important fields:

```text
date_key
full_date
year
quarter
month
month_name
week_of_year
day_of_month
day_of_week
day_name
is_weekend
is_month_end
quarter_label
month_label
modeled_at
```

The date key uses:

```text
YYYYMMDD
```

For example:

```text
20260910
```

The current date dimension is generated from the minimum and maximum order dates in `silver_orders`.

---

# Fact Tables

## `fact_order_items`

This is the primary sales fact.

### Grain

> **One row represents one product line within one order.**

Example:

```text
Order 1001
    ├── Product A
    ├── Product B
    └── Product C
```

creates three rows in:

```text
fact_order_items
```

### Keys

```text
order_item_id
order_id
customer_id
product_id
order_date_key
```

### Measures

```text
quantity
unit_price
discount_amount
tax_amount
line_total
calculated_line_total
net_sales_amount
gross_sales_amount
```

### Data-quality fields

```text
line_total_variance
is_line_total_mismatch
has_negative_quantity
returned_quantity
has_return
return_rate
```

### Technical fields

```text
updated_at
ingested_at
loaded_at
transformed_at
modeled_at
```

## Sales Calculations

Gross sales:

```text
quantity × unit_price
```

Net line amount including tax:

```text
(quantity × unit_price)
- discount_amount
+ tax_amount
```

The source `line_total` is retained so that it can be reconciled against the calculated value.

## `fact_payments`

Represents payment transactions.

Important fields:

```text
payment_id
order_id
payment_date_key
payment_method
payment_status
payment_status_group
amount
is_successful_payment
has_transaction_reference
payment_amount_band
payment_update_delay_days
updated_at
ingested_at
loaded_at
transformed_at
modeled_at
```

---

# Star Schema

```text
                         dim_customers
                              │
                              │ customer_id
                              ▼
                       fact_order_items
                       /       │                             /        │                             ▼         ▼         ▼
              dim_products  dim_date   measures
                 product_id  date_key
```

The Gold layer also contains:

```text
fact_payments
      │
      └── dim_date
```

The Star Schema provides a business-friendly analytical structure.

---

# Why Gold Is Less Normalized

The Raw/OLTP-style model separates entities to support transactional consistency.

The Gold layer is designed for analytical access.

Therefore Gold intentionally uses a dimensional and more denormalized structure:

```text
Dimensions
    +
Facts
```

The objective is analytical usability and efficient access rather than minimizing every repeated attribute.

---

# dbt Project Structure

```text
ecommerce-analytics-engineering/
│
├── .venv/
├── .gitignore
├── README.md
├── requirements.txt
│
├── docs/
│   ├── architecture.md
│   ├── data_model.md
│   └── backfill_strategy.md
│
├── sql/
│   ├── 01_create_database.sql
│   ├── 02_create_raw_tables.sql
│   ├── 03_insert_raw_data.sql
│   ├── 04_add_ingested_at.sql
│   └── analytics_queries.sql
│
├── scripts/
│   └── generate_raw_data.py
│
└── ecommerce_dbt/
    │
    ├── dbt_project.yml
    ├── packages.yml
    │
    ├── models/
    │   ├── sources/
    │   │   └── sources.yml
    │   │
    │   ├── bronze/
    │   │   ├── bronze_customers.sql
    │   │   ├── bronze_products.sql
    │   │   ├── bronze_orders.sql
    │   │   ├── bronze_order_items.sql
    │   │   ├── bronze_payments.sql
    │   │   ├── bronze_shipments.sql
    │   │   ├── bronze_returns.sql
    │   │   └── bronze_schema.yml
    │   │
    │   ├── silver/
    │   │   ├── silver_customers.sql
    │   │   ├── silver_products.sql
    │   │   ├── silver_orders.sql
    │   │   ├── silver_order_items.sql
    │   │   ├── silver_payments.sql
    │   │   ├── silver_shipments.sql
    │   │   ├── silver_returns.sql
    │   │   └── silver_schema.yml
    │   │
    │   └── gold/
    │       ├── dimensions/
    │       │   ├── dim_customers.sql
    │       │   ├── dim_products.sql
    │       │   └── dim_date.sql
    │       │
    │       ├── facts/
    │       │   ├── fact_order_items.sql
    │       │   └── fact_payments.sql
    │       │
    │       └── gold_schema.yml
    │
    ├── macros/
    │   ├── add_audit_columns.sql
    │   ├── generate_timestamp.sql
    │   ├── modeled_timestamp.sql
    │   └── transformed_timestamp.sql
    │
    ├── tests/
    │   └── test_positive_order_item_values.sql
    │
    └── analyses/
        └── data_quantity_analysis.sql
```

Generated directories such as `target/`, `logs/`, and `dbt_packages/` may exist locally but should not be treated as source code.

---

# dbt Sources

Source configuration:

```text
ecommerce_dbt/models/sources/sources.yml
```

Configured source tables:

```text
customers
products
orders
order_items
payments
shipments
returns
```

Example:

```jinja
{{ source('raw', 'customers') }}
```

This references:

```text
raw.customers
```

Source definitions provide:

- Clear source documentation.
- Dependency information.
- Source-level testing.
- Freshness configuration.
- Lineage visibility.

---

# dbt Model Dependencies

```text
source()
   ↓
Bronze
   ↓
ref()
   ↓
Silver
   ↓
ref()
   ↓
Gold
```

Example:

```text
raw.orders
    ↓
bronze_orders
    ↓
silver_orders
    ↓
fact_order_items
```

Another example:

```text
raw.products
    ↓
bronze_products
    ↓
silver_products
    ↓
dim_products
    ↓
fact_order_items
```

dbt automatically uses these dependencies to determine build order.

---

# `source()` vs `ref()`

## `source()`

Used for external/source relations:

```sql
{{ source('raw', 'orders') }}
```

## `ref()`

Used for another dbt model:

```sql
{{ ref('silver_orders') }}
```

`ref()` creates a dependency between dbt models and allows dbt to build them in the correct order and expose lineage.

---

# dbt Configuration

The project uses:

```yaml
models:
  ecommerce_dbt:
    bronze:
      +schema: bronze
      +materialized: view

    silver:
      +schema: silver
      +materialized: view

    gold:
      +schema: gold
      +materialized: table
```

Therefore:

```text
Bronze → view
Silver → view
Gold → table
```

`fact_order_items` overrides the Gold default and uses incremental materialization.

---

# dbt Materializations

The project uses:

- **View** for Bronze.
- **View** for Silver.
- **Table** for most Gold models.
- **Incremental** for `fact_order_items`.

Views are useful for lightweight transformation layers.

Tables are useful for persisted analytics-ready Gold models.

Incremental materialization is useful for continuously growing transactional facts.

---

# Incremental Processing

The Gold fact table:

```text
analytics_gold.fact_order_items
```

is implemented as an incremental dbt model.

Configuration:

```sql
{{
    config(
        materialized='incremental',
        unique_key='order_item_id'
    )
}}
```

The model processes eligible new or changed source records rather than rebuilding the complete fact on every normal incremental run.

---

# Current Incremental Strategy

The current model uses both:

```text
ingested_at
updated_at
```

Conceptually:

```sql
WHERE
    oi.ingested_at > MAX(ingested_at)
OR
    oi.updated_at > MAX(updated_at)
```

This allows records with newer ingestion timestamps or newer update timestamps to qualify for processing.

The strategy is suitable for demonstrating incremental processing but is intentionally simpler than a production CDC implementation.

---

# Important Incremental Limitation

Independent maximum timestamp comparisons can have edge cases with out-of-order records and updates.

A production implementation could use:

- Lookback windows.
- Watermarks.
- CDC.
- MERGE strategies.
- More robust source-specific change tracking.
- Better handling of late updates.

---

# Full Refresh

Use:

```powershell
dbt run --full-refresh
```

For Gold:

```powershell
dbt run --select gold --full-refresh
```

A full refresh is useful when:

- Transformation logic changes significantly.
- Historical data needs correction.
- Incremental state is stale or corrupted.
- Incremental logic changes.
- A complete historical rebuild is required.

The project used a Gold full refresh after regenerating RAW data to ensure the incremental fact did not retain stale records from the previous RAW state.

---

# Late-Arriving Data

The project simulates:

```text
order_id = 320
```

with:

```text
order_date  = 2026-08-01 10:00:00
updated_at  = 2026-09-06 09:30:00
ingested_at = 2026-09-07 08:15:00
```

This demonstrates:

```text
Business Event Time
        ≠
Ingestion Time
```

A pipeline must account for records arriving after their business event date.

---

# Updated Data Simulation

The project also simulates an updated order:

```text
order_id = 10
```

with:

```text
updated_at = 2026-09-05 11:00:00
ingested_at = 2026-09-05 12:00:00
```

This demonstrates that an incremental pipeline must account for changed records, not only newly inserted records.

---

# Backfill

A backfill means reprocessing historical data.

Examples:

```text
Historical data was missing
        ↓
Historical data arrives
        ↓
Historical data is processed
```

or:

```text
Transformation logic was incorrect
        ↓
Logic is fixed
        ↓
Historical data is reprocessed
```

The project documents a backfill strategy in:

```text
docs/backfill_strategy.md
```

A complete rebuild can be performed using:

```powershell
dbt run --full-refresh
```

---

# Ingestion Time vs Business Time

Important timestamps:

```text
order_date
ingested_at
updated_at
```

`order_date` represents the business event.

`ingested_at` represents when the record entered the raw pipeline/database.

`updated_at` represents when the source record was last changed.

These fields support:

- Incremental processing.
- Late-arriving data handling.
- Freshness monitoring.
- Troubleshooting.
- Auditability.

---

# Audit Columns

The project uses:

```text
ingested_at
loaded_at
transformed_at
modeled_at
```

These fields provide technical metadata about the movement and processing of data through the pipeline.

---

# Data Quality

Data quality validation covers:

- Required fields.
- Key uniqueness.
- Referential integrity.
- Business rules.
- Invalid quantities.
- Monetary reconciliation.
- Source freshness.

---

# dbt Generic Tests

The project uses common dbt tests such as:

```text
not_null
unique
relationships
```

Additional accepted-value or business-rule tests can be added where required.

---

# Not Null Tests

Example:

```yaml
- name: customer_id
  data_tests:
    - not_null
```

This validates that the field contains no NULL values.

---

# Unique Tests

Example:

```yaml
- name: customer_id
  data_tests:
    - not_null
    - unique
```

This validates identifier uniqueness.

---

# Relationship Tests

Examples:

```text
silver_order_items.order_id
          ↓
silver_orders.order_id
```

```text
silver_orders.customer_id
          ↓
silver_customers.customer_id
```

```text
silver_order_items.product_id
          ↓
silver_products.product_id
```

Gold relationships include:

```text
fact_order_items.customer_id
          ↓
dim_customers.customer_id
```

```text
fact_order_items.product_id
          ↓
dim_products.product_id
```

```text
fact_order_items.order_date_key
          ↓
dim_date.date_key
```

```text
fact_payments.payment_date_key
          ↓
dim_date.date_key
```

Relationship tests help detect orphan records.

---

# Singular Data Test

The current custom test is:

```text
tests/test_positive_order_item_values.sql
```

It checks:

```sql
WHERE quantity <= 0
   OR unit_price <= 0
```

A dbt test passes when the test query returns zero violating records.

The negative quantity scenario was removed from the generator so that this test passes against the final dataset.

---

# Incorrect Line Total Detection

One source order-item record intentionally contains an incorrect `line_total`.

The Silver layer calculates:

```text
calculated_line_total
```

using:

```text
(quantity × unit_price)
- discount_amount
+ tax_amount
```

It then calculates:

```text
line_total_variance
```

and flags material differences using:

```text
is_line_total_mismatch
```

This demonstrates reconciliation-style data quality logic.

---

# Source Freshness

Source freshness is configured in:

```text
ecommerce_dbt/models/sources/sources.yml
```

The configured timestamp field is:

```text
ingested_at
```

The conceptual thresholds are:

```text
Warning → 24 hours
Error   → 48 hours
```

Run:

```powershell
dbt source freshness
```

Freshness monitoring identifies whether upstream source data is arriving within the expected period.

---

# Data Lineage

Lineage describes where data originated and how it moves through downstream models.

Example:

```text
raw.orders
     ↓
bronze_orders
     ↓
silver_orders
     ↓
fact_order_items
```

Another:

```text
raw.products
     ↓
bronze_products
     ↓
silver_products
     ↓
dim_products
     ↓
fact_order_items
```

dbt tracks dependencies through:

```jinja
{{ source() }}
```

and:

```jinja
{{ ref() }}
```

---

# DAG

The dbt project forms a Directed Acyclic Graph (DAG).

Example:

```text
raw.orders
     ↓
bronze_orders
     ↓
silver_orders
     ↓
fact_order_items
```

Each dependency is represented as an edge in the graph.

dbt uses the graph to determine execution order.

---

# Jinja and dbt

dbt combines SQL with Jinja templating.

Examples:

```jinja
{{ ref('silver_orders') }}
```

and:

```jinja
{% if is_incremental() %}
```

Jinja makes dbt models dynamic and reusable.

---

# Macros

The project contains:

```text
macros/add_audit_columns.sql
macros/generate_timestamp.sql
macros/modeled_timestamp.sql
macros/transformed_timestamp.sql
```

Macros provide reusable SQL/Jinja logic.

They are useful for:

- Reducing repeated code.
- Standardizing patterns.
- Improving maintainability.
- Reusing logic across models.

Not every business transformation should be a macro; macros are most useful when logic is genuinely reusable.

---

# Analytical SQL

The Gold layer can answer questions such as:

```text
How much revenue was generated?
Which products sell the most?
Which customers generate the most sales?
What are daily sales trends?
Which products have high return rates?
Which payment methods perform best?
Which orders are delayed?
```

The project contains analytical SQL in:

```text
sql/analytics_queries.sql
```

and:

```text
ecommerce_dbt/analyses/data_quantity_analysis.sql
```

---

# Customer Sales Analysis

Example:

```sql
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.net_sales_amount) AS total_sales
FROM analytics_gold.fact_order_items AS f
JOIN analytics_gold.dim_customers AS c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_sales DESC;
```

This demonstrates:

- Fact-to-dimension joins.
- Aggregations.
- `COUNT(DISTINCT ...)`.
- `SUM()`.
- `GROUP BY`.
- Analytical reporting.

---

# Product Performance Analysis

Example:

```sql
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(f.quantity) AS total_quantity_sold,
    SUM(f.net_sales_amount) AS total_revenue
FROM analytics_gold.fact_order_items AS f
JOIN analytics_gold.dim_products AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY total_revenue DESC;
```

---

# Daily Sales Analysis

Example:

```sql
SELECT
    DATE(order_date) AS order_day,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS total_items_sold,
    SUM(net_sales_amount) AS total_revenue
FROM analytics_gold.fact_order_items
GROUP BY DATE(order_date)
ORDER BY order_day;
```

---

# Quantity Analysis

The project contains:

```text
ecommerce_dbt/analyses/data_quantity_analysis.sql
```

It examines:

- Total order items.
- Total quantity.
- Average quantity.
- Minimum quantity.
- Maximum quantity.
- Negative quantities.
- Zero quantities.
- Returned quantities.
- Products with the highest quantity sold.
- Unusual quantity patterns.

---

# dbt Commands

## Version

```powershell
dbt --version
```

## Dependencies

```powershell
dbt deps
```

## Environment / Connection

```powershell
dbt debug
```

## Parse

```powershell
dbt parse
```

## Run all models

```powershell
dbt run
```

## Run a layer

```powershell
dbt run --select bronze
dbt run --select silver
dbt run --select gold
```

## Run a model

```powershell
dbt run --select fact_order_items
```

## Run upstream dependencies

```powershell
dbt run --select +fact_order_items
```

## Run tests

```powershell
dbt test
```

## Test Gold

```powershell
dbt test --select gold
```

## Build

```powershell
dbt build
```

## Full refresh

```powershell
dbt run --full-refresh
```

## Gold full refresh

```powershell
dbt run --select gold --full-refresh
```

## Compile

```powershell
dbt compile
```

## Compile one model

```powershell
dbt compile --select silver_orders
```

## Source freshness

```powershell
dbt source freshness
```

---

# Recommended End-to-End Execution

```text
1. Generate source data
        ↓
2. Load RAW into PostgreSQL
        ↓
3. Validate source counts and relationships
        ↓
4. dbt deps
        ↓
5. dbt debug
        ↓
6. dbt parse
        ↓
7. dbt run
        ↓
8. dbt test
        ↓
9. dbt source freshness
        ↓
10. dbt build
        ↓
11. Run analytical SQL
```

For a complete dbt model-and-test workflow:

```powershell
dbt build
```

---

# Environment Setup

## Create Virtual Environment

```powershell
py -3.12 -m venv .venv
```

## Activate

```powershell
.\.venv\Scripts\Activate.ps1
```

## Install Dependencies

```powershell
pip install -r requirements.txt
```

## Verify

```powershell
dbt --version
```

---

# PostgreSQL Setup

Create the database using:

```text
sql/01_create_database.sql
```

Create Raw tables:

```text
sql/02_create_raw_tables.sql
```

Generate mock data:

```powershell
python scripts\generate_raw_data.py
```

Load generated SQL:

```powershell
psql -U postgres -d ecommerce_analytics --single-transaction -v ON_ERROR_STOP=1 -f sql_insert_raw_data.sql
```

The generated data is validated for:

- Record counts.
- Relationships.
- Timestamps.
- Controlled data-quality scenarios.
- SQL generation.

---

# Running dbt

Move into:

```powershell
cd ecommerce_dbt
```

Then:

```powershell
dbt deps
dbt debug
dbt parse
dbt build
```

---

# End-to-End Lineage

```text
Python Generator
       │
       ▼
Generated SQL
       │
       ▼
PostgreSQL RAW
       │
       │ source()
       ▼
Bronze
       │
       │ ref()
       ▼
Silver
       │
       │ ref()
       ▼
Gold
       │
       ├── dim_customers
       ├── dim_products
       ├── dim_date
       ├── fact_order_items
       └── fact_payments
       │
       ▼
Analytics
```

---

# Data Engineering vs Analytics Engineering

## Data Engineering aspects

- Source data generation.
- Data ingestion.
- PostgreSQL storage.
- Raw data modeling.
- Data quality.
- Freshness.
- Incremental processing.
- Late-arriving data.
- Backfills.
- Audit metadata.

## Analytics Engineering aspects

- dbt models.
- Layered transformations.
- SQL business logic.
- Dimensional modeling.
- Star Schema.
- Fact and dimension design.
- dbt tests.
- Macros.
- Lineage.
- Analytics-ready datasets.

---

# Important Engineering Concepts

## OLTP

The Raw layer simulates an OLTP-style source:

- Transaction-oriented.
- Frequent inserts and updates.
- Entity-oriented tables.
- Relational constraints.

## OLAP

The Gold layer is designed for analytical workloads:

- Aggregations.
- Reporting.
- Fact/dimension analysis.
- Business intelligence.

## ETL vs ELT

ETL:

```text
Extract
 ↓
Transform
 ↓
Load
```

ELT:

```text
Extract
 ↓
Load
 ↓
Transform
```

This project follows ELT.

## Normalization

The Raw/OLTP-style model separates entities such as:

```text
customers
orders
order_items
products
```

This reduces unnecessary duplication and supports transactional integrity.

## Denormalization

The Gold layer intentionally uses a dimensional structure optimized for analytics.

---

# Referential Integrity

Examples:

```text
orders.customer_id
      ↓
customers.customer_id
```

```text
order_items.product_id
      ↓
products.product_id
```

```text
order_items.order_id
      ↓
orders.order_id
```

Relationship tests validate these dependencies in dbt models.

---

# Idempotency

A production pipeline should be safe to rerun without creating unintended duplicate business records.

Conceptually:

```text
Run pipeline
     ↓
Run pipeline again
     ↓
No unintended duplicate business records
```

The incremental model's `unique_key` supports controlled incremental behavior, but complete idempotency depends on the entire ingestion and transformation design.

---

# Slowly Changing Dimensions

The current project does **not** implement a full SCD Type 2 design.

However, customer attributes such as:

```text
customer_status
customer_segment
city
```

could require historical tracking in a production warehouse.

A future SCD Type 2 implementation could preserve multiple versions of a customer's attributes using effective dates and current-row indicators.

---

# Schema Evolution

Production source systems can change:

```text
New column
Column rename
Data type change
Column removal
```

The pipeline should have a strategy for detecting and handling these changes.

The current project uses explicit SQL schemas and dbt models, so source schema changes should be reviewed rather than assumed to be automatically safe.

---

# Performance and Scalability

The current project is intentionally small and local.

For larger datasets, important considerations include:

- Incremental processing.
- Query optimization.
- Appropriate indexes.
- Efficient joins.
- Avoiding unnecessary full rebuilds.
- Partitioning or clustering in warehouse systems.
- Efficient source ingestion.
- Appropriate materializations.

---

# Production Improvements

If this project were moved to production, possible improvements include:

- Production-grade CDC.
- Robust incremental watermarks.
- Lookback windows.
- Targeted historical backfills.
- Slowly Changing Dimensions.
- dbt snapshots.
- Source contracts.
- Automated orchestration.
- CI/CD.
- Deployment automation.
- Monitoring and alerting.
- Data observability.
- Cloud warehouse deployment.
- Partitioning/clustering for large data.
- More comprehensive anomaly detection.
- Centralized secrets management.

---

# Security and Git Practices

The following should not be committed:

```text
.venv/
target/
logs/
dbt_packages/
profiles.yml
.env
```

These can contain:

- Local dependencies.
- Generated dbt artifacts.
- Environment-specific configuration.
- Database credentials.

---

# Recommended `.gitignore`

```gitignore
# Python virtual environment
.venv/

# Python cache
__pycache__/
*.pyc

# Environment variables
.env

# dbt generated files
ecommerce_dbt/target/
ecommerce_dbt/logs/
ecommerce_dbt/dbt_packages/

# dbt profile credentials
profiles.yml
```

---

# Assignment Requirements Mapping

| Assignment Requirement | Status | Current Implementation |
| --- | --- | --- |
| Git repository | Completed | Project repository |
| Local PostgreSQL database | Completed | `ecommerce_analytics` |
| Raw source tables | Completed | 7 e-commerce source tables |
| Mock data ingestion | Completed | Python generator + SQL insert script |
| dbt project | Completed | `ecommerce_dbt` |
| Source definitions | Completed | `models/sources/sources.yml` |
| Bronze layer | Completed | 7 Bronze models |
| Silver layer | Completed | 7 Silver models |
| Gold layer | Completed | 3 dimensions + 2 facts |
| Fact tables | Completed | `fact_order_items`, `fact_payments` |
| Dimension tables | Completed | `dim_customers`, `dim_products`, `dim_date` |
| Dimensional modeling | Completed | Star Schema |
| Data quality tests | Completed | Generic and custom dbt tests |
| Custom data test | Completed | Positive order-item value validation |
| Incremental processing | Completed | `fact_order_items` |
| Late-arriving data | Completed | `order_id = 320` |
| Updated source data | Completed | `order_id = 10` |
| Backfill strategy | Completed | `docs/backfill_strategy.md` |
| Data freshness | Completed | Source freshness configuration |
| dbt macros | Completed | Audit/timestamp macros |
| Analytical SQL | Completed | Customer, product, daily, and quantity analysis |
| Data lineage | Completed | `source()` / `ref()` dependencies |
| Full-refresh validation | Completed | Gold full-refresh successfully executed |

---

# Project Validation Status

The current project has successfully completed:

```text
RAW data generation
        ↓
RAW database loading
        ↓
Bronze transformation
        ↓
Silver transformation
        ↓
Gold transformation
        ↓
Gold full-refresh
        ↓
Data-quality validation workflow
```

The latest successful Gold full-refresh produced:

```text
dim_customers       120
dim_date            251
dim_products        500
fact_order_items    632
fact_payments       320
```

with:

```text
PASS=5
WARN=0
ERROR=0
SKIP=0
NO-OP=0
REUSED=0
TOTAL=5
```

The project should be revalidated after subsequent code or data changes using:

```powershell
dbt build
```

The exact number of tests and resources can change when test coverage or project configuration changes.

---

# Final Project Outcome

The project implements an end-to-end Data Engineering and Analytics Engineering workflow:

```text
             PostgreSQL RAW
                    │
                    ▼
              dbt Sources
                    │
                    ▼
              Bronze Layer
                    │
                    ▼
              Silver Layer
                    │
                    ▼
               Gold Layer
              /     |                   /      |                   ▼       ▼        ▼
       Customers Products   Date
       Dimension Dimension Dimension
             \      |       /
              \     |      /
               ▼    ▼     ▼
             Order / Payment
                 Facts
                    │
                    ▼
              Data Quality
                    │
                    ▼
              Analytics
```

The project demonstrates the journey from:

```text
Raw Transactional Data
        ↓
Data Ingestion
        ↓
Data Cleaning
        ↓
Business Transformation
        ↓
Data Quality Validation
        ↓
Dimensional Modeling
        ↓
Incremental Processing
        ↓
Late-Arriving Data Handling
        ↓
Analytics-Ready Data
```

---

# Key Concepts Demonstrated

## Data Engineering

- Data sources.
- Data ingestion.
- Data pipelines.
- Data transformation.
- Data storage.
- Data quality.
- Data freshness.
- Incremental processing.
- Late-arriving data.
- Backfills.
- Lineage.
- Audit metadata.

## Databases

- PostgreSQL.
- Relational databases.
- Schemas.
- Tables.
- Primary keys.
- Foreign keys.
- Constraints.
- Referential integrity.
- Relationships.

## SQL

- SELECT.
- INSERT.
- WHERE.
- JOIN.
- GROUP BY.
- HAVING.
- ORDER BY.
- COUNT.
- COUNT(DISTINCT ...).
- SUM.
- AVG.
- CASE.
- COALESCE.
- NULLIF.
- Date and timestamp functions.
- CTEs.
- Aggregations.
- Analytical queries.

## OLTP and OLAP

- OLTP.
- OLAP.
- Operational vs analytical workloads.
- Transactional modeling.
- Analytical modeling.

## ELT

```text
Extract
 ↓
Load
 ↓
Transform
```

## Medallion Architecture

```text
Raw
 ↓
Bronze
 ↓
Silver
 ↓
Gold
```

## dbt

- dbt models.
- `source()`.
- `ref()`.
- `dbt_project.yml`.
- Materializations.
- Views.
- Tables.
- Incremental models.
- Jinja.
- Macros.
- YAML configuration.
- Data tests.
- Source freshness.
- Lineage.
- Compilation.
- Full refresh.
- Model selection.
- `dbt build`.

## Dimensional Modeling

- Fact tables.
- Dimension tables.
- Fact grain.
- Measures.
- Keys.
- Star Schema.
- Analytical modeling.
- Date dimension.

## Data Quality

- Not-null tests.
- Unique tests.
- Relationship tests.
- Singular tests.
- Business-rule validation.
- Reconciliation checks.
- Referential integrity.

## Incremental Processing

- New-record processing.
- Updated-record processing.
- `unique_key`.
- `is_incremental()`.
- Ingestion timestamps.
- Update timestamps.
- Full refresh.
- Incremental limitations.

## Advanced Data Engineering

- Late-arriving data.
- Backfills.
- Source freshness.
- Lineage.
- DAGs.
- Idempotency.
- Schema evolution.
- Slowly Changing Dimensions.
- Scalability.
- Performance.
- Production orchestration and CI/CD concepts.

---

# Future Improvements

The current implementation satisfies the core project requirements, but it can be extended with:

- Slowly Changing Dimensions.
- dbt snapshots.
- More advanced incremental strategies.
- Change Data Capture.
- Lookback windows.
- Targeted backfills.
- Source contracts.
- dbt exposures.
- Additional fact tables.
- Power BI or Tableau dashboards.
- Apache Airflow orchestration.
- GitHub Actions CI/CD.
- Advanced anomaly detection.
- Larger datasets.
- Partitioning/clustering strategies.
- Cloud data warehouse deployment.
- Production monitoring and alerting.

---

# Conclusion

This project demonstrates a complete small-scale **Data Engineering and Analytics Engineering pipeline** using PostgreSQL and dbt.

It starts with OLTP-style e-commerce source data:

```text
customers
products
orders
order_items
payments
shipments
returns
```

and transforms it through:

```text
RAW
 ↓
BRONZE
 ↓
SILVER
 ↓
GOLD
```

The final Gold layer contains:

```text
dim_customers
dim_products
dim_date

fact_order_items
fact_payments
```

The project also demonstrates:

- ELT.
- Medallion architecture.
- Dimensional modeling.
- Star Schema.
- Fact table grain.
- Data quality testing.
- Referential integrity.
- Incremental processing.
- Late-arriving data.
- Backfills.
- Source freshness.
- Audit timestamps.
- dbt macros.
- Data lineage.
- Analytical SQL.
- Debugging and full-refresh workflows.

The implementation has been validated through successful PostgreSQL loading, dbt transformations, Gold full-refresh execution, and data-quality validation.
