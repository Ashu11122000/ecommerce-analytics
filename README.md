# E-Commerce Analytics Engineering Project

An end-to-end analytics engineering project that transforms generated
e-commerce data in PostgreSQL into tested, analytics-ready Gold models
using dbt, documents a semantic layer, and delivers three Power BI
dashboards for leadership, operations, and data-quality analysis.

> **Project status:** Core data pipeline, Gold reporting models, SQL
> analysis, semantic-layer documentation/validation, and three Power BI
> dashboard pages have been developed. The final focus is
> reproducibility, metric consistency, CI verification, and submission
> documentation. See [Current Status and Validation](# current-status-and-validation).

## Table of Contents

- [Project Overview](#project-overview)
- [Evaluation Requirements](#evaluation-requirements)
- [Technology Stack](#technology-stack)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Data Sources and Ingestion](#data-sources-and-ingestion)
- [PostgreSQL Schemas](#postgresql-schemas)
- [dbt Transformation Layers](#dbt-transformation-layers)
- [Gold Models and Grain](#gold-models-and-grain)
- [Semantic Layer and Power BI
  Model](#semantic-layer-and-power-bi-model)
- [Metrics and Business Rules](#metrics-and-business-rules)
- [Data Quality and Validation](#data-quality-and-validation)
- [SQL Analysis and Dashboard
  Queries](#sql-analysis-and-dashboard-queries)
- [Power BI Dashboards](#power-bi-dashboards)
- [Time Comparisons, Forecasting, and Anomaly
  Analysis](#time-comparisons-forecasting-and-anomaly-analysis)
- [Incremental Processing, Late Data, and
  Backfills](#incremental-processing-late-data-and-backfills)
- [Source Freshness, Audit Columns, and
  Lineage](#source-freshness-audit-columns-and-lineage)
- [Local Setup](#local-setup)
- [Run the Pipeline](#run-the-pipeline)
- [GitHub Actions CI](#github-actions-ci)
- [Known Limitations and Risks](#known-limitations-and-risks)
- [Final Validation Checklist](#final-validation-checklist)

## Project Overview

This project demonstrates an analytics engineering workflow built around
PostgreSQL and dbt Core. Mock e-commerce data is generated with Python,
loaded into raw PostgreSQL tables, transformed through Bronze, Silver,
and Gold layers, validated with dbt tests and SQL checks, and consumed
by Power BI dashboards.

The pipeline follows **ELT (Extract, Load, Transform)**: data is loaded
into PostgreSQL before dbt performs transformations in the database.

The implementation demonstrates:

- Raw transactional source tables.
- dbt source definitions and model dependencies.
- Bronze, Silver, and Gold transformations.
- Dimensional modeling and a Star Schema.
- Fact-table grain and dimension relationships.
- Generic and custom data quality tests.
- Incremental processing for the order-item fact.
- Late-arriving and updated-record scenarios.
- A documented backfill approach.
- Source freshness configuration.
- Reusable dbt macros and audit timestamps.
- Analytical SQL queries.
- Semantic metric definitions and validation.
- Three Power BI report pages for different audiences.
- A GitHub Actions workflow intended to validate the dbt project.

The dataset is synthetic and is intended for learning and evaluation,
not to represent actual commercial performance.

## Evaluation Requirements

The project is intended to satisfy an assignment requiring:

1.  A Git repository.
2.  Analytics-ready Gold tables derived from dbt models.
3.  Defined metrics and dimensions with documented grain.
4.  A semantic layer or equivalent abstraction.
5.  At least two dashboards for different personas.
6.  A dashboard built using an accepted BI tool; this project uses Power
    BI.
7.  SQL queries backing the dashboard visuals.
8.  Documentation of personas, business questions, metric definitions,
    assumptions, walkthroughs, limitations, and risks.

Stretch goals include time-based comparisons (WoW/MoM/YoY), derived
metrics, a forecast, and anomaly identification. The implementation
includes time-comparison and forecast-analysis SQL files and a
rolling-average Power BI visual. A rolling average is a smoothing
measure, not by itself a future forecast; the final submission should
clearly state whether a separate future forecast has been implemented
and validated.

## Technology Stack

---

Technology Purpose

---

PostgreSQL 17.x Raw data storage and transformation
destination

dbt Core 1.12.3 SQL transformation, model
orchestration, and testing

dbt-postgres 1.11.0 PostgreSQL adapter for dbt

Python Mock data generation and utility
scripts

SQL Data definition, ingestion,
transformation, validation, and
analysis

Jinja dbt templating and reusable macros

Power BI Desktop Semantic model and interactive
dashboards

Git and GitHub Version control and repository
hosting

GitHub Actions Automated CI workflow for dbt
validation

Visual Studio Code Development environment

---

Local repository path used during development:

```text
C:\Users\Ashish\ecommerce-analytics
```

The database used during local validation is named
`ecommerce_analytics`. Local connection settings may vary; do not commit
passwords or private connection details.

## Architecture

```text
Python mock-data generator
          |
          v
Generated SQL / ingestion scripts
          |
          v
PostgreSQL: ecommerce_analytics
          |
          v
Raw schema (source tables)
          |
          | dbt source()
          v
Bronze models (standardization and technical metadata)
          |
          | dbt ref()
          v
Silver models (cleaning, business rules, derived fields, DQ flags)
          |
          | dbt ref()
          v
Gold models (facts and dimensions)
          |
          +--------------------+
          |                    |
          v                    v
SQL analysis and validation   Power BI semantic model
                               |
                               v
                 Leadership / Operations / Data Quality
```

Cross-cutting concerns include data quality, lineage, source freshness,
audit metadata, incremental processing, late-arriving data, and backfill
planning.

## Repository Structure

The structure below reflects the files visible in the current repository
screenshots and the implementation context. Some generated folders and
local files may be present locally but should not be committed.

```text
ecommerce-analytics/
│
├── .github/
│   ├── workflows/
│   │   └── dbt-ci.yml
│   └── profiles.yml                 # Optional CI-only profile; see CI section
│
├── .venv/                           # Local virtual environment; do not commit
│
├── dashboards/
│   ├── leadership/
│   │   ├── dashboard_queries.sql
│   │   └── README.md
│   └── operations/
│       ├── dashboard_queries.sql
│       └── README.md
│
├── docs/
│   ├── anomaly_detection_methodology.md
│   ├── architecture.md
│   ├── backfill_strategy.md
│   ├── dashboard_walkthrough.md
│   ├── data_dictionary.md
│   ├── data_lineage.md
│   ├── data_model.md
│   ├── data_quality.md
│   ├── evaluation_checklist.md
│   ├── forecasting_methodology.md
│   ├── freshness_and_monitoring.md
│   ├── incremental_processing.md
│   ├── known_limitations.md
│   ├── late_arriving_data.md
│   ├── metric_definitions.md
│   ├── model_grain.md
│   └── project_overview.md
│
├── ecommerce_dbt/
│   ├── analyses/
│   │   ├── anomaly_analysis.sql
│   │   ├── customer_analysis.sql
│   │   ├── data_quantity_analysis.sql
│   │   ├── forecast_analysis.sql
│   │   ├── order_status_analysis.sql
│   │   ├── payment_analysis.sql
│   │   ├── return_analysis.sql
│   │   ├── sales_performance_analysis.sql
│   │   ├── shipping_performance_analysis.sql
│   │   └── time_comparison_analysis.sql
│   │
│   ├── macros/
│   │   ├── add_audit_columns.sql
│   │   ├── calculate_date_key.sql
│   │   ├── generate_schema_name.sql
│   │   ├── generate_timestamp.sql
│   │   ├── modeled_timestamp.sql
│   │   ├── safe_divide.sql
│   │   └── transformed_timestamp.sql
│   │
│   ├── models/
│   │   ├── bronze/
│   │   │   ├── bronze_customers.sql
│   │   │   ├── bronze_order_items.sql
│   │   │   ├── bronze_orders.sql
│   │   │   ├── bronze_payments.sql
│   │   │   ├── bronze_products.sql
│   │   │   ├── bronze_returns.sql
│   │   │   ├── bronze_shipments.sql
│   │   │   └── bronze_schema.yml
│   │   │
│   │   ├── silver/
│   │   │   ├── silver_customers.sql
│   │   │   ├── silver_order_items.sql
│   │   │   ├── silver_orders.sql
│   │   │   ├── silver_payments.sql
│   │   │   ├── silver_products.sql
│   │   │   ├── silver_returns.sql
│   │   │   ├── silver_shipments.sql
│   │   │   └── silver_schema.yml
│   │   │
│   │   ├── gold/
│   │   │   ├── dimensions/
│   │   │   │   ├── dim_customers.sql
│   │   │   │   ├── dim_date.sql
│   │   │   │   └── dim_products.sql
│   │   │   ├── facts/
│   │   │   │   ├── fact_order_items.sql
│   │   │   │   ├── fact_payments.sql
│   │   │   │   ├── fact_returns.sql
│   │   │   │   └── fact_shipments.sql
│   │   │   └── gold_schema.yml
│   │   │
│   │   └── sources/
│   │       └── sources.yml
│   │
│   ├── tests/
│   │   ├── test_fact_order_unique_order_id.sql
│   │   ├── test_fact_shipments_valid_delivery_days.sql
│   │   ├── test_gold_revenue_reconciliation.sql
│   │   ├── test_no_duplicate_order_items.sql
│   │   ├── test_no_negative_payment_amounts.sql
│   │   ├── test_order_item_line_total_reconciliation.sql
│   │   ├── test_positive_order_item_values.sql
│   │   └── test_return_quantity_validity.sql
│   │
│   ├── scripts/
│   │   ├── check_database_connection.py
│   │   ├── generate_raw_data.py
│   │   ├── load_raw_data.py
│   │   ├── run_pipeline.py
│   │   └── validate_raw_data.py
│   │
│   ├── dbt_project.yml
│   ├── packages.yml
│   └── package-lock.yml
│
├── semantic_layer/
│   ├── dimensions.md
│   ├── join_rules.md
│   ├── metric_definitions.md
│   ├── metric_validation.sql
│   ├── metrics_catalog.csv
│   ├── model_grain.md
│   └── README.md
│
├── sql/
│   ├── analytics_queries/
│   │   ├── anomaly_analysis.sql
│   │   ├── customer_analysis.sql
│   │   ├── forecast_analysis.sql
│   │   ├── leadership_dashboards.sql
│   │   ├── operations_dashboard.sql
│   │   ├── order_status_analysis.sql
│   │   ├── payment_analysis.sql
│   │   ├── return_analysis.sql
│   │   ├── sales_performance_analysis.sql
│   │   ├── shipping_performance_analysis.sql
│   │   └── time_comparison_analysis.sql
│   ├── 01_create_database.sql
│   ├── 02_create_raw_tables.sql
│   ├── 03_insert_raw_data.sql
│   ├── 04_add_ingested_at.sql
│   └── 05_raw_data_quality_checks.sql
│
├── .env                             # Local secrets; do not commit
├── .gitignore
├── README.md
├── requirements.txt
└── set_dbt_password.bat             # Local helper; review for secrets before tracking
```

**Important:** Treat this as the current documented structure, not a
guarantee that every listed file is present in every checkout. Confirm
the actual files with VS Code or `git status` before submission. The
Power BI file `Ecommerce_Analytics_Dashboard.pbix` is a separate report
artifact and should be included in the repository or delivered
separately according to repository size and submission rules.

Generated dbt directories such as `target/`, `logs/`, and
`dbt_packages/`, Python caches, and the `.venv/` directory are
generated/local artifacts rather than source code.

## Data Sources and Ingestion

The current pipeline uses generated mock e-commerce data rather than an
external production dataset. The generator is designed to make the
sample dataset reproducible and to introduce controlled data-quality and
late-arriving-data scenarios.

The source entities are:

- Customers
- Products
- Orders
- Order items
- Payments
- Shipments
- Returns

The earlier documented generator uses random seed `42`. The current
scripts under `ecommerce_dbt/scripts/` are responsible for generating,
loading, checking the database connection, validating raw data, and
running the pipeline. Review the scripts to confirm the exact execution
order and options before changing the pipeline.

### Previously recorded source row counts

The source-data workflow previously recorded these counts:

Raw table Recorded rows

---

Customers 120
Products 500
Orders 320
Order items 632
Payments 320
Shipments 290
Returns 30

These are historical recorded counts, not guaranteed counts after every
generator run or data change. Validate the current database before using
them in a report.

### Controlled scenarios

The earlier generator documentation records these scenarios:

- Seven customer records with NULL phone values.
- One product with inconsistent category casing.
- One intentionally incorrect line total.
- A late-arriving order (`order_id = 320`).
- An updated order (`order_id = 10`).
- The negative-quantity scenario was removed from the generator for
  the earlier positive-value test.

Later Gold-layer validation identified a negative quantity in a fact
row. Treat this as a reason to re-run current checks rather than
assuming older generator notes and current database results are
identical.

## PostgreSQL Schemas

The database is named:

```text
ecommerce_analytics
```

The intended schemas are:

---

Schema Purpose

---

`raw` Ingested source tables

`analytics_bronze` Source-oriented, lightly
standardized dbt models

`analytics_silver` Cleaned and enriched dbt models

`analytics_gold` Analytics-ready facts and
dimensions

---

The project's `generate_schema_name` macro and dbt configuration
determine the final schema names. Verify `dbt_project.yml`, target
profile, and the macro if schema names differ in another environment.

### Raw tables

```text
raw.customers
raw.products
raw.orders
raw.order_items
raw.payments
raw.shipments
raw.returns
```

The raw tables simulate an OLTP-style source system. Typical
relationships include customers to orders, orders to order items, order
items to products, and orders to payments and shipments.

## dbt Transformation Layers

### Bronze

Bronze models read raw sources using `source()` and provide a consistent
interface to downstream transformations. Typical operations include
trimming and standardizing strings, handling appropriate NULL/default
cases, retaining source-level fields, and adding technical metadata.

Models include:

- `bronze_customers`
- `bronze_products`
- `bronze_orders`
- `bronze_order_items`
- `bronze_payments`
- `bronze_shipments`
- `bronze_returns`

### Silver

Silver models clean, standardize, and enrich the Bronze data. The
documented business and quality fields include customer age/tenure,
product price and stock bands, order-status groups, payment-success
flags, delivery duration, late-arriving-data indicators, calculated line
totals, reconciliation variance, mismatch flags, and return metrics.

Models include:

- `silver_customers`
- `silver_products`
- `silver_orders`
- `silver_order_items`
- `silver_payments`
- `silver_shipments`
- `silver_returns`

### Gold

Gold models provide business-friendly facts and dimensions for
analytical SQL and Power BI. Most Gold models are tables;
`fact_order_items` has been configured as an incremental model. Confirm
current materializations in `dbt_project.yml` and the model files.

## Gold Models and Grain

The following grains describe the intended reporting model. Validate
them against the current model SQL and uniqueness tests before treating
them as enforced production guarantees.

---

Model Intended grain Main purpose

---

`dim_customers` One row per customer Customer segmentation
key and customer attributes

`dim_products` One row per product key Product/category
attributes

`dim_date` One row per calendar Time-based filtering
date key and comparisons

`fact_order_items` One row per order-item Sales, quantities,
ID order-item quality, and
product performance

`fact_payments` One row per payment ID Payment amounts,
methods, and status

`fact_returns` One row per return ID Return quantities,
reasons, statuses, and
refunds

`fact_shipments` One row per shipment ID Shipment status,
delivery duration, and
delay analysis

---

### `fact_order_items`

The principal sales fact includes identifiers and date fields such as
`order_item_id`, `order_id`, `customer_id`, `product_id`,
`order_date_key`, and `order_date`. It also includes
status/channel/currency attributes, quantity and price fields, discount
and tax values, recorded and calculated line totals, variance and
mismatch flags, returned quantities, return indicators, eligibility
flags, financial measures, and technical timestamps.

The intended grain is one product line within one order. Count distinct
`order_id` for order counts; do not treat the number of order-item rows
as the number of orders.

### `fact_payments`

Represents payment transactions. Fields documented in the project
include `payment_id`, `order_id`, `payment_date_key`, `payment_method`,
`payment_status`, `amount`, `is_successful_payment`,
transaction-reference indicators, and technical timestamps.

### `fact_returns`

Represents return records and supports analysis of return date, reason,
quantity, refund amount, and status. Do not assume one return event per
order item as a universal business rule merely because the current
sample data happens to have unique item references.

### `fact_shipments`

Represents shipment records and supports status, shipping method,
shipped/delivered timestamps, delivery location, delivery duration, and
delay analysis.

### Dimensions

- `dim_customers`: customer descriptors and segmentation fields.
- `dim_products`: product descriptors, category, pricing, stock, and
  margin-related fields.
- `dim_date`: date key, full date, year, quarter, month, week, day,
  and calendar flags.

The documented date key format is `YYYYMMDD`. The date dimension was
originally described as being generated from the minimum and maximum
order dates in `silver_orders`; confirm its current SQL and coverage
before relying on it for payment, return, or shipment date analysis.

## Semantic Layer and Power BI Model

The semantic layer documents business-facing dimensions, join rules,
metric definitions, and model grain. The
`semantic_layer/metric_validation.sql` file contains SQL validation
sections for key counts, financial calculations, reconciliation,
payments, returns, shipments, and related checks. `metrics_catalog.csv`
is intended to provide a metric catalogue.

Power BI provides the current reporting semantic model over the Gold
tables. Relationships recorded during model setup include:

- `fact_order_items` to `dim_customers` (many-to-one).
- `fact_order_items` to `dim_products` (many-to-one).
- `fact_order_items` to `dim_date` through the order date key
  (many-to-one).
- `fact_payments` to `dim_date` through the payment date key
  (many-to-one).
- `fact_shipments` to `dim_date` through the shipment date key
  (many-to-one).
- `fact_returns` to `fact_order_items` through `order_item_id`.
- A return-date relationship to `dim_date` was recorded as inactive.

Recheck the saved PBIX model before submission because relationship
names, active states, and cardinalities can change. An inactive
return-date relationship requires explicit handling in measures or an
alternative model design when analyzing by return date. Review the
observed one-to-one returns-to-order-items cardinality if multiple
return events per item should be supported.

### Semantic consistency rules

- Use explicit DAX measures for published metrics.
- Count distinct orders when reporting orders.
- Count distinct customers when reporting purchasing customers.
- Use eligible sales records consistently for eligible financial and
  unit metrics.
- Do not equate payment rows with orders.
- Do not add measures from different fact tables without considering
  grain and possible duplication.
- Document each metric's numerator, denominator, filters, time field,
  and exclusions.
- Distinguish gross sales, sales excluding tax, and final line total.
- Document unknown and missing values rather than silently treating
  them as zero.

## Metrics and Business Rules

Metric names in the Power BI model have included:

- Gross Sales
- Net Sales
- Average Order Value
- Purchasing Customers
- Monthly Net Sales
- MoM Sales Growth
- 3-Month Rolling Average
- Invalid Order Items
- Line Total Mismatches
- Negative Quantity Items
- Latest Monthly Net Sales
- Payment Success Rate
- Total Payments
- Delivered Shipments
- Delayed Shipments
- Returned Units
- Total Refund Amount
- Average Delivery Days
- Monthly Data Quality Issues

Verify the actual DAX definitions in the PBIX and align them with
`semantic_layer/metric_definitions.md` and
`semantic_layer/metrics_catalog.csv` before submission.

### Sales calculations

The documented intended calculation is:

```text
Gross sales = quantity × unit_price

Calculated final line total
    = (quantity × unit_price)
      - discount_amount
      + tax_amount
```

The source `line_total` is retained for reconciliation. The current
model's `net_sales_amount` has been observed to behave like the final
line total, including tax. Therefore, do not label it "net sales
excluding tax" unless the model is changed to follow that definition.

The project should state explicitly whether "Net Sales" means sales
after discounts and before tax, or final line total after tax. Apply the
chosen definition consistently across dbt, SQL, DAX, dashboards, and
documentation.

### Example DAX patterns

These are reference patterns, not a guarantee that they match the exact
measures currently saved in the PBIX. Replace table names with the names
displayed in Power BI and confirm the model columns and Boolean types.

```dax
Total Orders =
CALCULATE(
    DISTINCTCOUNT(gold_fact_order_items[order_id]),
    gold_fact_order_items[is_valid_for_sales] = TRUE()
)
```

```dax
Purchasing Customers =
CALCULATE(
    DISTINCTCOUNT(gold_fact_order_items[customer_id]),
    gold_fact_order_items[is_valid_for_sales] = TRUE()
)
```

```dax
Units Sold =
CALCULATE(
    SUM(gold_fact_order_items[quantity]),
    gold_fact_order_items[is_valid_for_sales] = TRUE()
)
```

```dax
Average Order Value =
DIVIDE([Net Sales], [Total Orders], 0)
```

Average Order Value is meaningful only when `[Net Sales]` and
`[Total Orders]` use compatible eligibility rules and the agreed
financial definition.

## Data Quality and Validation

The project uses dbt generic tests such as `not_null`, `unique`, and
`relationships`, along with singular SQL tests for business rules and
reconciliation. The tests directory includes checks for order-item
uniqueness, valid shipment delivery days, revenue reconciliation,
duplicate order items, negative payment amounts, line-total
reconciliation, positive order-item values, and return quantity
validity.

### Recorded Gold-layer validation results

The following figures were recorded during a prior validation session.
Re-run the SQL against the current database before using them as final
deliverable results.

Check Recorded result

---

`fact_order_items` rows 644
Distinct order-item IDs 644
Eligible-for-sales rows 642
Invalid-for-sales rows 2
Total units across all rows 1,976
Units across eligible rows 1,975
Line-total mismatch rows 2
Negative-quantity rows 1
Eligible orders with sales 320
Gross sales 25,281,271.32
Current line-total-based net sales 25,347,841.41
Average net sales per order 79,212.00
Payment rows 320
Successful payment records 224
Payment success rate 70%
Return rows 30
Returned units 61
Refund total 767,215.84
Shipment rows 290
Delivered shipments 165
Shipments not delivered 125
Delayed shipments with known status 45
Not-delayed shipments with known status 120
Shipments with unknown delay flags 125
Average delivery duration for delivered shipments 3.89 days

### Sales eligibility

The recorded eligibility rules require positive quantity and
non-negative, present financial inputs, a present line total, and
reconciliation between the recorded and calculated line total within a
tolerance of `0.01`. Invalid rows are retained for audit and flagged;
financial measures are null for invalid rows.

### Recorded anomalies

Two example order items were identified in a validation session:

- **Order item 1011:** quantity `-1`, recorded line total `74,608.14`,
  calculated line total `-15,048.54`, variance `89,656.68`; flagged as
  a mismatch and invalid for sales.
- **Order item 1041:** quantity `2`, recorded line total `54,205.32`,
  calculated line total `53,705.32`, variance `500.00`; flagged as a
  mismatch and invalid for sales.

These are historical observed values. Confirm that the current database
still contains the same records before using them as current findings.

### Payment, return, and shipment caveats

- Payment success rate was calculated as 224 successful payment
  records out of 320 payment rows.
- Payment amounts and sales totals represent different business events
  and are not expected to match automatically.
- The recorded return fact had 30 records and 30 distinct order-item
  references; this is a property of the current sample, not
  necessarily a universal business rule.
- The recorded shipment delay rate was `45 / (45 + 120) = 27.27%`,
  using only the 165 shipments with known delay status.
- 125 shipment records had unknown delay flags and missing delivery
  durations in the recorded validation.

## SQL Analysis and Dashboard Queries

The dbt analyses directory contains:

---

File Intended analysis

---

`anomaly_analysis.sql` Unusual values and quality
anomalies

`customer_analysis.sql` Customer purchasing and sales
patterns

`data_quantity_analysis.sql` Row counts, quantity distribution,
and volume checks

`forecast_analysis.sql` Forecast/rolling-average analysis

`order_status_analysis.sql` Order status distribution

`payment_analysis.sql` Payment amounts, methods, and
statuses

`return_analysis.sql` Return quantities, reasons, and
refunds

`sales_performance_analysis.sql` Sales performance

`shipping_performance_analysis.sql` Shipment and delivery performance

`time_comparison_analysis.sql` Time-based comparisons

---

Root-level `sql/analytics_queries/` contains corresponding reporting
queries, including `leadership_dashboards.sql` and
`operations_dashboard.sql`. Dashboard-specific SQL is also stored in
`dashboards/leadership/dashboard_queries.sql` and
`dashboards/operations/dashboard_queries.sql`.

Compilation does not guarantee that every analysis query has been
executed against the current database. Execute the relevant queries and
record the actual results before final submission. Each visual should
map to a documented metric or SQL query.

## Power BI Dashboards

The report contains three pages aimed at different audiences. The PBIX
file is named `Ecommerce_Analytics_Dashboard.pbix` in the project
context; confirm its final location before linking it from the
repository.

### 1. E-Commerce Business & Leadership Overview

**Persona:** Business leaders and management.

**Business questions:**

- What sales value and order volume are represented in the data?
- How many customers purchased?
- Which product categories and products contribute the most sales?
- How does monthly sales performance change?
- What does month-over-month growth indicate?

**Recorded visuals:**

- KPI cards: Total Orders, Purchasing Customers, Units Sold, Gross
  Sales, Net Sales, Average Order Value.
- Monthly Net Sales Trend.
- Net Sales by Product Category.
- Top Products by Net Sales.
- Month-over-Month Sales Growth.

The dashboard uses distinct order counts rather than treating every
order-item line as a separate order. Use the same sales eligibility and
financial definition across all visuals.

### 2. Operations & Analytics

**Persona:** Operations, payment, shipping, and customer-service
analysts.

**Business questions:**

- What is the order-status distribution?
- What are the payment status and success patterns?
- Which return reasons occur most often?
- How many shipments are delivered, delayed, or still in other
  statuses?
- What is the refund amount and observed delivery duration?

**Recorded visuals:**

- KPI cards: Payment Success Rate, Delivered Shipments, Delayed
  Shipments, Returned Units, Total Refunded Amount, Average Delivery
  Days.
- Order Status Distribution.
- Payment Status Analysis.
- Returns by Reason.
- Shipping Performance by Status.

Disclose the unknown shipment-delay status and ensure each metric uses
the correct fact-table grain.

### 3. Data Quality & Forecasting

**Persona:** Analytics engineers and data-quality analysts.

**Business questions:**

- How many order items are invalid?
- How many line totals fail reconciliation?
- Are negative quantities present?
- In which months were quality issues detected?
- How does monthly sales compare with its rolling average?
- Which unusual changes require investigation?

**Recorded visuals:**

- KPI cards: Invalid Order Items, Line Total Mismatches, Negative
  Quantity Items, Latest Monthly Net Sales.
- Monthly Data Quality Issues by Year and Month.
- Monthly Net Sales versus 3-Month Rolling Average.

The X-axis was configured chronologically rather than grouping the same
month name across different years. The rolling-average line is a
historical smoothing metric, not automatically a forecast.

### Dashboard query mapping

Maintain the following mapping in the dashboard walkthrough
documentation:

---

Dashboard Query file

---

Leadership `dashboards/leadership/dashboard_queries.sql`

Operations `dashboards/operations/dashboard_queries.sql`

Data quality and forecasting Relevant queries in `sql/analytics_queries/`
and `ecommerce_dbt/analyses/`

---

Document the exact query and measure for each visual, including filters,
denominator, time field, and any exclusions.

## Time Comparisons, Forecasting, and Anomaly Analysis

### Time comparisons

The project includes `time_comparison_analysis.sql` and a Power BI
month-over-month sales growth measure. Ensure the date dimension covers
the required periods and that the visual uses a chronological date
field. WoW, MoM, and YoY metrics should only be reported when the model
has sufficient data and the period definitions are clear.

### Rolling average and forecast

The Data Quality & Forecasting page compares monthly net sales with a
three-month rolling average. Confirm that the DAX or SQL window includes
the intended current and prior months and handles the first months of
the series appropriately.

A rolling average describes recent historical behavior. If a future
forecast is added, document the method, forecast horizon, assumptions,
and limitations. Do not describe the rolling-average line as a future
prediction.

### Anomaly analysis

Anomaly work focuses on unexpected sales changes and data-quality
exceptions such as invalid quantities or line-total mismatches. Document
whether each anomaly is rule-based (for example, a reconciliation
tolerance) or statistically detected. Explain the impact and the
follow-up needed rather than assuming every spike is an error.

## Incremental Processing, Late Data, and Backfills

### Incremental model

`fact_order_items` is documented as an incremental dbt model with
`order_item_id` as its unique key. The model uses `ingested_at` and
`updated_at` to identify records that may be new or changed.

The documented approach is conceptually based on newer ingestion or
update timestamps. Independent maximum-timestamp comparisons can miss
edge cases with out-of-order events or updates. The project describes
this as a learning implementation rather than production-grade CDC.

### Late-arriving data

The generator documentation records a late-arriving order with
`order_id = 320`, with an earlier business event time and later
update/ingestion timestamps. This demonstrates that business event time
differs from ingestion time.

### Updated records

The project also records an updated order (`order_id = 10`) to
demonstrate that incremental logic must account for changes, not only
inserts.

### Backfills and full refresh

The backfill strategy is documented in `docs/backfill_strategy.md`. A
full refresh is useful when historical transformations need rebuilding,
incremental state is stale, or model logic changes significantly.

Run a full refresh only when appropriate for the target environment and
data volume:

```powershell
dbt run --full-refresh
```

To rebuild only the Gold selection, verify the selector against the
current model paths before running:

```powershell
dbt run --select gold --full-refresh
```

A full refresh rebuilds model data; it does not by itself repair
incorrect source data or guarantee that every downstream process has
been backfilled.

## Source Freshness, Audit Columns, and Lineage

### Source freshness

Freshness is configured in `ecommerce_dbt/models/sources/sources.yml`,
with `ingested_at` documented as the timestamp field and conceptual
thresholds of 24 hours for warning and 48 hours for error.

Run:

```powershell
dbt source freshness
```

The command is only meaningful when the source tables and freshness
configuration are available and the timestamps reflect the intended
arrival semantics. For synthetic local data, old timestamps can trigger
warnings even when the pipeline itself is functioning.

### Audit timestamps

The project uses technical timestamps such as:

- `ingested_at`
- `loaded_at`
- `transformed_at`
- `modeled_at`
- `updated_at`

Their exact meaning should be documented in the data dictionary and kept
consistent across models.

### Lineage

dbt derives model dependencies from `source()` and `ref()` calls.
Example:

```text
raw.orders
   -> bronze_orders
   -> silver_orders
   -> Gold fact model
```

The lineage and model structure are documented in `docs/data_lineage.md`
and `docs/data_model.md`.

## Local Setup

The commands below use PowerShell because that is the development shell
used in the project screenshots. Run commands from the repository root
unless a different working directory is shown.

### 1. Prerequisites

Install or have access to:

- Python 3.12 (recommended for the documented virtual environment).
- PostgreSQL 17.x.
- Git.
- Power BI Desktop for opening the report.
- A terminal such as PowerShell or VS Code's integrated terminal.

The documented dbt dependency versions are:

```text
dbt-core==1.12.3
dbt-postgres==1.11.0
```

### 2. Create and activate a virtual environment

From the repository root:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

If `requirements.txt` is malformed or contains unexpected characters,
correct it before installing. Keep package requirements on separate
valid lines.

### 3. Configure environment variables and dbt profile

Use a local `.env` file or another secure local configuration mechanism
for database credentials. Do not commit `.env` or real passwords.

The dbt profile must match the `name:` in
`ecommerce_dbt/dbt_project.yml`, and its target must point to the
correct PostgreSQL host, port, database, user, password, and schema. The
profile is commonly stored in the user's dbt configuration directory;
the CI workflow described below uses a separate CI profile.

### 4. Create and load raw data

The repository contains SQL scripts for database/table setup and
raw-data loading:

```text
sql/01_create_database.sql
sql/02_create_raw_tables.sql
sql/03_insert_raw_data.sql
sql/04_add_ingested_at.sql
sql/05_raw_data_quality_checks.sql
```

The current Python scripts live under `ecommerce_dbt/scripts/`. Inspect
their arguments and expected working directory before executing them.
The intended sequence is:

1. Create the database.
2. Create raw tables.
3. Generate the data.
4. Load the data into PostgreSQL.
5. Validate row counts, keys, relationships, and controlled
    data-quality scenarios.

Do not run destructive database commands against a database containing
data you need to preserve.

## Run the Pipeline

From the repository root:

```powershell
cd ecommerce_dbt
```

Check dbt and its connection:

```powershell
dbt --version
dbt deps
dbt debug
```

Parse and compile:

```powershell
dbt parse
dbt compile
```

Build models and tests:

```powershell
dbt build
```

Useful targeted commands:

```powershell
dbt run --select bronze
dbt run --select silver
dbt run --select gold
dbt run --select fact_order_items
dbt test
dbt test --select gold
dbt source freshness
```

The exact selection syntax depends on the current model paths and
configuration. Check `dbt ls` if a selector does not match any nodes.

### Previously recorded execution results

The project context records a successful `dbt compile`, a `dbt run` that
built 21 models (14 views, 6 tables, and 1 incremental model), and a
`dbt build` with 240 of 240 operations completed (21 models and 219
tests). These are historical results from that run; repeat the commands
after code changes and use the latest output as the source of truth.

## GitHub Actions CI

The repository contains:

```text
.github/workflows/dbt-ci.yml
```

The intended workflow runs on pushes and pull requests targeting `main`,
and supports manual execution with `workflow_dispatch`. It checks out
the repository, sets up Python, installs dbt, starts a PostgreSQL
service, installs dbt packages, checks the connection, compiles the
project, and runs `dbt build`.

### CI requirements and limitations

- The workflow's `working-directory` must point to `ecommerce_dbt`.
- The dbt profile name must match the project name in
  `dbt_project.yml`.
- CI starts with a **fresh, empty PostgreSQL database**. It does not
  copy the local raw tables or local data.
- If the dbt models reference raw tables that are not created and
  populated during CI, `dbt build` will fail. Add explicit CI
  setup/seed steps or adjust the workflow to use a reproducible test
  database before treating CI as passing.
- Do not commit real credentials. Use GitHub Actions secrets for
  sensitive values in production. The example local CI credentials
  should only be used for an isolated ephemeral test database.
- Keep `.github/workflows/dbt-ci.yml` tracked in Git; do not add it to
  `.gitignore`.
- If `.github/profiles.yml` is intended to be committed as a
  credential-free CI profile, ensure the `.gitignore` rule for
  `profiles.yml` does not accidentally exclude it. A rule such as
  `!.github/profiles.yml` can re-include it after the general ignore
  rule.
- Verify the workflow on GitHub and review the Actions logs. A file
  existing in the repository does not mean the workflow has already
  passed.

## Known Limitations and Risks

1. **Synthetic data:** Values are generated and should not be
    represented as real business performance.
2. **Metric semantics:** The observed `net_sales_amount` behaves like a
    final line total including tax. Clearly distinguish gross sales, net
    sales excluding tax, and final line total.
3. **Invalid sales rows:** Two invalid order-item rows were recorded in
    a prior validation. Re-run the tests and checks to establish the
    current state.
4. **Negative quantity:** A negative-quantity row was observed in a
    Gold validation even though an older generator note says the
    scenario was removed. Investigate the current raw data and model
    output.
5. **Shipment completeness:** 125 shipments were recorded with unknown
    delay status and missing delivery duration. Delay rates must use the
    known-status denominator and disclose missingness.
6. **Returns cardinality:** The current sample has unique return item
    references, but a production system may allow multiple return events
    for an item.
7. **Date roles:** Return-date relationship was recorded as inactive in
    Power BI. Measures must activate or otherwise handle that date role
    when needed.
8. **Forecasting:** A rolling average is not a future forecast.
    Describe the actual method implemented.
9. **Incremental edge cases:** Timestamp watermark logic may miss
    out-of-order changes; robust CDC, lookback windows, and targeted
    backfills are possible future improvements.
10. **Freshness in a sample environment:** Generated timestamps may not
    represent a continuously arriving source.
11. **Local-only setup:** PostgreSQL service, local profile, `.env`, and
    virtual environment are machine-specific unless setup steps are
    reproduced elsewhere.
12. **CI database setup:** The workflow's PostgreSQL service starts
    empty. CI requires raw schema/data setup before model builds can
    pass.
13. **Historical counts:** Row counts and metric values in this README
    are recorded observations, not permanent constants. Use fresh query
    output for final results.
14. **No full SCD Type 2:** The project does not currently claim a
    complete Slowly Changing Dimension Type 2 implementation.
15. **Scale:** The local dataset is small and is suitable for
    demonstrating engineering patterns, not proving production-scale
    performance.

## Final Validation Checklist

### Data and dbt

- [ ] Confirm the current raw table counts and key relationships.
- [ ] Run `dbt deps`, `dbt debug`, `dbt parse`, `dbt compile`, and
      `dbt build`.
- [ ] Run `dbt source freshness` and interpret results in the context
      of generated timestamps.
- [ ] Re-run the singular and generic data quality tests.
- [ ] Confirm the current Gold model grain, materializations, and
      schema names.
- [ ] Reconcile the sales formula across Silver, Gold, SQL, and DAX.
- [ ] Investigate any negative quantity and line-total mismatch
      records.
- [ ] Verify payment, return, and shipment metrics with current query
      results.

### Semantic layer and dashboards

- [ ] Verify Power BI relationships, cardinalities, active/inactive
      date relationships, and filter direction.
- [ ] Confirm the exact DAX definitions and display formats for all
      KPI measures.
- [ ] Check that distinct orders, eligible units, and financial
      measures use consistent rules.
- [ ] Validate every dashboard visual against its SQL query or
      documented DAX measure.
- [ ] Confirm chronological sorting and time-comparison behavior.
- [ ] Document the rolling-average calculation and whether a separate
      future forecast exists.
- [ ] Add dashboard screenshots or a walkthrough to the documentation
      if required.

### Repository and CI

- [ ] Ensure `.venv/`, `.env`, credentials, `target/`, `logs/`, and
      generated package folders are not committed.
- [ ] Keep `.github/workflows/dbt-ci.yml` tracked.
- [ ] Ensure the CI profile is available to the workflow without
      exposing secrets.
- [ ] Set up raw tables and data in CI, or document the required CI
      fixture approach.
- [ ] Run the GitHub Actions workflow and review the result.
- [ ] Confirm the PBIX file's final location and submission method.
- [ ] Update this README if the actual files, commands, counts, or
      workflow behavior differ from what is documented.
- [ ] Commit and push the final implementation.

## Conclusion

This project demonstrates a complete learning-oriented analytics
engineering workflow: generated source data, PostgreSQL raw storage, dbt
transformations across Bronze/Silver/Gold, data quality checks,
incremental-processing concepts, a documented semantic layer, SQL-backed
analysis, and three Power BI dashboards.

The final submission should prioritize reproducibility and consistent
metric definitions. The most important final checks are to validate the
current database rather than rely on historical counts, align sales
definitions across dbt/SQL/DAX, disclose incomplete shipment data, and
confirm that the GitHub Actions workflow can build the project from a
fresh CI database.
