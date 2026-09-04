# E-Commerce Analytics Engineering Project

## Project Overview

This project is an end-to-end **Data Engineering and Analytics Engineering** project built using **PostgreSQL** and **dbt (data build tool)**.

The project simulates a small e-commerce analytics pipeline where raw transactional data is loaded into PostgreSQL and transformed into analytics-ready datasets using dbt.

The complete pipeline follows an **ELT (Extract, Load, Transform)** approach and implements:

- Raw OLTP-style source tables.
- dbt source definitions.
- Bronze, Silver, and Gold transformation layers.
- Dimensional modeling.
- A Star Schema.
- Dimension and fact tables.
- Data quality testing.
- Custom dbt tests.
- Incremental processing.
- Late-arriving data handling.
- Backfill simulation.
- Data freshness configuration.
- Reusable dbt macros.
- Analytical SQL queries.
- Data lineage through dbt model dependencies.

The final Gold layer provides analytics-ready tables that can be used for reporting, dashboards, and business analysis.

---

# Project Objectives

The main goal of this project is to build a simple but realistic analytics engineering pipeline.

The project performs the following steps:

1. Creates a PostgreSQL database.
2. Creates raw OLTP-style tables.
3. Inserts mock e-commerce transactional data.
4. Defines raw source tables in dbt.
5. Transforms raw data into the Bronze layer.
6. Cleans and standardizes data in the Silver layer.
7. Builds analytics-ready dimension and fact tables in the Gold layer.
8. Applies data quality tests.
9. Implements incremental loading for transactional data.
10. Simulates late-arriving and historical data.
11. Documents a backfill strategy.
12. Runs analytical SQL queries on the Gold layer.
13. Validates the complete project using `dbt build`.

---

# Technology Stack

| Technology   | Purpose                                             |
| ------------ | --------------------------------------------------- |
| PostgreSQL   | Local relational database and analytical data store |
| dbt Core     | SQL-based data transformation framework             |
| dbt-postgres | PostgreSQL adapter for dbt                          |
| Python       | Environment required to run dbt                     |
| Git          | Version control                                     |
| GitHub       | Remote repository hosting                           |
| PowerShell   | Local development environment                       |
| SQL          | Data querying and transformation                    |
| Jinja        | dbt templating and macros                           |

---

# Project Architecture

The complete data flow is:

```text
Mock / OLTP-Style Data
          │
          ▼
┌─────────────────────────────┐
│         PostgreSQL          │
│                             │
│         RAW LAYER           │
│                             │
│ raw.customers               │
│ raw.products                │
│ raw.orders                  │
│ raw.order_items             │
└──────────────┬──────────────┘
               │
               │ dbt source()
               ▼
┌─────────────────────────────┐
│        BRONZE LAYER         │
│                             │
│ Minimal transformation      │
│ Basic type standardization  │
│ Audit columns               │
│ Source-level validation     │
│                             │
│ bronze_customers            │
│ bronze_products             │
│ bronze_orders               │
│ bronze_order_items          │
└──────────────┬──────────────┘
               │
               │ dbt ref()
               ▼
┌─────────────────────────────┐
│        SILVER LAYER         │
│                             │
│ Cleaned data                │
│ Standardized values         │
│ Business rules              │
│ Referential validation      │
│ Reusable datasets           │
│                             │
│ silver_customers            │
│ silver_products             │
│ silver_orders               │
│ silver_order_items          │
└──────────────┬──────────────┘
               │
               │ dbt ref()
               ▼
┌────────────────────────────────┐
│           GOLD LAYER           │
│                                │
│      Analytics-Ready Data      │
│                                │
│ Dimensions                     │
│ ├── dim_customers              │
│ └── dim_products               │
│                                │
│ Facts                          │
│ └── fact_order_items           │
│     (Incremental Model)        │
└───────────────┬────────────────┘
                │
                ▼
       Analytics & Insights
```

---

# Data Engineering Lifecycle

This project demonstrates the following simplified data engineering lifecycle:

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
Data Modeling
      ↓
Data Quality Testing
      ↓
Analytics-Ready Tables
      ↓
Business Analysis
```

---

# ELT Architecture

This project follows an **ELT workflow**.

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
PostgreSQL Raw Tables
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

Unlike traditional ETL systems where transformation may happen before loading into the warehouse, this project loads data into PostgreSQL first and then transforms it using dbt.

---

# PostgreSQL Database

The local PostgreSQL database used for this project is:

```text
ecommerce_analytics
```

The database contains multiple schemas representing different stages of the analytics pipeline.

```text
raw
analytics_bronze
analytics_silver
analytics_gold
```

---

# Database Schemas

## 1. Raw Schema

```text
raw
```

This schema contains the source transactional tables.

Tables:

```text
raw.customers
raw.products
raw.orders
raw.order_items
```

These tables simulate an **OLTP-style e-commerce system**.

---

## 2. Bronze Schema

```text
analytics_bronze
```

This schema contains minimally transformed source data.

Models:

```text
bronze_customers
bronze_products
bronze_orders
bronze_order_items
```

Bronze models are created as dbt views.

---

## 3. Silver Schema

```text
analytics_silver
```

This schema contains cleaned and standardized datasets.

Models:

```text
silver_customers
silver_products
silver_orders
silver_order_items
```

Silver models are created as dbt views.

---

## 4. Gold Schema

```text
analytics_gold
```

This schema contains analytics-ready dimensional models.

Tables:

```text
dim_customers
dim_products
fact_order_items
```

The Gold layer is designed for analytical queries.

---

# Raw Data Model

The raw layer contains four tables.

---

## `raw.customers`

Stores customer information.

Main fields include:

```text
customer_id
customer_name
email
city
signup_date
ingested_at
```

---

## `raw.products`

Stores product information.

Main fields include:

```text
product_id
product_name
category
price
ingested_at
```

---

## `raw.orders`

Stores order-level information.

Main fields include:

```text
order_id
customer_id
order_date
order_status
ingested_at
```

---

## `raw.order_items`

Stores individual products within orders.

Main fields include:

```text
order_item_id
order_id
product_id
quantity
unit_price
ingested_at
```

---

# OLTP-Style Source Model

The raw transactional model follows relationships similar to a traditional e-commerce OLTP database.

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
    ├───────────────► products
    │                 product_id
    │
    ▼
Individual Product Transactions
```

A customer can place multiple orders.

An order can contain multiple order items.

Each order item references a product.

---

# Medallion Architecture

This project uses a simplified version of the **Medallion Architecture**.

The transformation layers are:

```text
Raw
 ↓
Bronze
 ↓
Silver
 ↓
Gold
```

Each layer has a specific responsibility.

---

# Raw Layer

The Raw layer stores source data in its original or near-original form.

Tables:

```text
raw.customers
raw.products
raw.orders
raw.order_items
```

Responsibilities:

- Store ingested data.
- Preserve source-level structure.
- Represent transactional data.
- Provide the starting point for dbt transformations.

The raw layer is intentionally kept close to the source.

---

# Bronze Layer

The Bronze layer performs minimal transformation.

Models:

```text
bronze_customers
bronze_products
bronze_orders
bronze_order_items
```

Responsibilities include:

- Reading from dbt sources.
- Standardizing column names.
- Performing basic transformations.
- Preserving source data structure.
- Adding audit information.
- Preparing data for downstream cleaning.

Bronze models act as a controlled interface between the raw source tables and the rest of the dbt project.

---

# Silver Layer

The Silver layer contains cleaned and standardized datasets.

Models:

```text
silver_customers
silver_products
silver_orders
silver_order_items
```

Responsibilities include:

- Cleaning data.
- Standardizing values.
- Applying business rules.
- Creating reusable datasets.
- Maintaining referential consistency.
- Preparing data for dimensional modeling.

The Silver layer acts as the primary transformation layer before analytical modeling.

---

# Gold Layer

The Gold layer contains analytics-ready tables.

Models:

```text
dim_customers
dim_products
fact_order_items
```

The Gold layer implements dimensional modeling principles.

It is optimized for:

- Reporting.
- Aggregations.
- Analytical queries.
- Business intelligence.
- Dashboard development.

---

# Dimensional Modeling

The project uses a **Star Schema** design.

The Star Schema contains:

```text
Dimension Tables
      +
Fact Table
```

Dimension tables provide descriptive context.

The fact table stores measurable business events.

---

# Gold Data Model

## Dimension Tables

### `dim_customers`

Stores descriptive customer information.

Columns include:

```text
customer_id
customer_name
email
city
signup_date
ingested_at
loaded_at
transformed_at
modeled_at
```

Business purpose:

```text
Who made the purchase?
```

---

### `dim_products`

Stores descriptive product information.

Columns include:

```text
product_id
product_name
category
price
ingested_at
loaded_at
transformed_at
modeled_at
```

Business purpose:

```text
What product was purchased?
```

---

# Fact Table

## `fact_order_items`

Stores transactional sales events.

Columns include:

```text
order_item_id
order_id
customer_id
product_id
order_date
quantity
unit_price
total_amount
ingested_at
loaded_at
transformed_at
modeled_at
```

The calculated metric is:

```text
total_amount = quantity × unit_price
```

Example:

```text
quantity   = 2
unit_price = 799.00

total_amount = 1598.00
```

---

# Fact Table Grain

The grain of the fact table is:

> **One row represents one product item within one order.**

This means:

```text
One Order
   │
   ├── Product A
   │
   ├── Product B
   │
   └── Product C
```

will produce multiple rows in:

```text
fact_order_items
```

The primary business event being measured is an individual order item.

---

# Star Schema

```text
                ┌──────────────────────┐
                │    dim_customers     │
                │──────────────────────│
                │ customer_id          │
                │ customer_name        │
                │ email                │
                │ city                 │
                │ signup_date          │
                └──────────┬───────────┘
                           │
                           │ customer_id
                           │
                    ┌──────▼───────────┐
                    │ fact_order_items │
                    │──────────────────│
                    │ order_item_id    │
                    │ order_id         │
                    │ customer_id      │
                    │ product_id       │
                    │ order_date       │
                    │ quantity         │
                    │ unit_price       │
                    │ total_amount     │
                    └──────┬───────────┘
                           │
                           │ product_id
                           │
                ┌──────────▼───────────┐
                │    dim_products      │
                │──────────────────────│
                │ product_id           │
                │ product_name         │
                │ category             │
                │ price                │
                └──────────────────────┘
```

---

# dbt Project Structure

The repository is organized as follows:

```text
ecommerce-analytics-engineering/
│
├── .venv/                         # Local Python virtual environment
│
├── .gitignore
├── README.md
├── requirements.txt
├── .env.example
│
├── sql/
│   ├── 01_create_database.sql
│   ├── 02_create_raw_tables.sql
│   ├── 03_insert_raw_data.sql
│   └── analytics_queries.sql
│
├── docs/
│   ├── architecture.md
│   ├── data_model.md
│   └── backfill_strategy.md
│
└── ecommerce_dbt/
    │
    ├── dbt_project.yml
    ├── packages.yml
    │
    ├── models/
    │
    │   ├── sources/
    │   │   └── sources.yml
    │   │
    │   ├── bronze/
    │   │   ├── bronze_customers.sql
    │   │   ├── bronze_products.sql
    │   │   ├── bronze_orders.sql
    │   │   ├── bronze_order_items.sql
    │   │   └── bronze_schema.yml
    │   │
    │   ├── silver/
    │   │   ├── silver_customers.sql
    │   │   ├── silver_products.sql
    │   │   ├── silver_orders.sql
    │   │   ├── silver_order_items.sql
    │   │   └── silver_schema.yml
    │   │
    │   └── gold/
    │       │
    │       ├── dimensions/
    │       │   ├── dim_customers.sql
    │       │   └── dim_products.sql
    │       │
    │       ├── facts/
    │       │   └── fact_order_items.sql
    │       │
    │       └── gold_schema.yml
    │
    ├── macros/
    │   └── add_audit_columns.sql
    │
    ├── tests/
    │   └── test_positive_order_amount.sql
    │
    ├── analyses/
    │   └── data_quality_analysis.sql
    │
    ├── target/                     # Generated by dbt
    ├── logs/                       # Generated by dbt
    └── dbt_packages/               # Generated packages
```

---

# dbt Sources

Raw PostgreSQL tables are defined as dbt sources.

The source configuration is located in:

```text
ecommerce_dbt/models/sources/sources.yml
```

The configured source tables are:

```text
customers
products
orders
order_items
```

dbt models reference raw source tables using:

```jinja
{{ source('raw', 'customers') }}
```

This provides several advantages:

- Clear source definitions.
- Data lineage.
- Source documentation.
- Source-level tests.
- Freshness checks.

---

# dbt Model Dependencies

dbt models are connected through dependencies.

The project follows this pattern:

```text
source()
   ↓
Bronze Models
   ↓
ref()
   ↓
Silver Models
   ↓
ref()
   ↓
Gold Models
```

For example:

```text
raw.orders
    ↓
bronze_orders
    ↓
silver_orders
    ↓
fact_order_items
```

dbt automatically understands these dependencies.

This allows dbt to:

- Build models in the correct order.
- Track lineage.
- Generate documentation.
- Run dependent models.

---

# Data Quality Testing

Data quality is implemented using dbt tests.

The project includes:

- `not_null` tests.
- `unique` tests.
- `relationships` tests.
- A custom data test.

The complete project currently contains:

```text
102 data tests
```

---

# Not Null Tests

Not Null tests validate that important fields do not contain missing values.

Examples include:

```text
customer_id
product_id
order_id
order_item_id
order_date
quantity
unit_price
```

Example configuration:

```yaml
columns:
  - name: customer_id
    data_tests:
      - not_null
```

These tests are applied across the different transformation layers where appropriate.

---

# Unique Tests

Unique tests validate primary or business key uniqueness.

Examples include:

```text
customer_id
product_id
order_id
order_item_id
```

Example:

```yaml
columns:
  - name: customer_id
    data_tests:
      - not_null
      - unique
```

This ensures duplicate identifiers are detected.

---

# Relationship Tests

Relationship tests validate foreign key relationships between models.

Examples include:

```text
silver_order_items.order_id
              │
              ▼
silver_orders.order_id
```

and:

```text
silver_orders.customer_id
              │
              ▼
silver_customers.customer_id
```

The Gold layer also validates relationships.

Examples:

```text
fact_order_items.customer_id
              │
              ▼
dim_customers.customer_id
```

and:

```text
fact_order_items.product_id
              │
              ▼
dim_products.product_id
```

These tests help ensure referential consistency.

---

# Custom Data Test

The project includes a custom dbt test:

```text
test_positive_order_amount.sql
```

This validates that order amounts are valid and positive.

The business rule is conceptually:

```text
total_amount > 0
```

A dbt data test passes when the query returns zero invalid records.

---

# Audit Columns

The project includes audit and lineage-related columns.

Examples include:

```text
ingested_at
loaded_at
transformed_at
modeled_at
```

These columns help identify when data moved through the pipeline.

---

## `ingested_at`

Represents when the record was loaded into the raw layer.

Example:

```text
Raw data inserted into PostgreSQL
        ↓
ingested_at recorded
```

---

## `loaded_at`

Represents when the data was loaded into a dbt transformation layer.

---

## `transformed_at`

Represents when the transformation occurred.

---

## `modeled_at`

Represents when the Gold-layer analytical model was created or refreshed.

---

# dbt Macro

The project contains a reusable dbt macro:

```text
ecommerce_dbt/macros/add_audit_columns.sql
```

The macro helps reduce repeated SQL logic related to audit columns.

dbt macros use:

```text
Jinja templating
```

Macros are useful for:

- Reusable SQL.
- Reducing duplication.
- Standardizing transformation patterns.
- Improving maintainability.

---

# Incremental Processing

The Gold fact table:

```text
fact_order_items
```

is implemented as an **incremental dbt model**.

Incremental processing is useful because transactional datasets can grow continuously.

Instead of rebuilding the entire fact table every time, dbt processes only eligible new records.

Conceptually:

```text
Existing Fact Table
        +
New Raw Records
        │
        ▼
Incremental dbt Run
        │
        ▼
Updated Fact Table
```

---

# Incremental Model

The incremental model is:

```text
analytics_gold.fact_order_items
```

The unique identifier is:

```text
order_item_id
```

This represents the grain-level identifier for each row.

---

# Incremental Load Simulation

A new order was inserted into the raw layer.

Example:

```text
order_id = 132
customer_id = 1
order_status = completed
```

A corresponding order item was inserted:

```text
order_item_id = 1062
order_id = 132
product_id = 1
quantity = 2
unit_price = 799.00
```

The calculated amount is:

```text
2 × 799.00 = 1598.00
```

After running:

```bash
dbt run --select fact_order_items
```

the new record was successfully added to:

```text
analytics_gold.fact_order_items
```

The Gold fact table row count increased accordingly.

This demonstrated successful incremental processing.

---

# Late-Arriving Data Simulation

The project also simulated late-arriving historical data.

A new record was inserted into the raw layer with:

```text
order_id = 133
```

The order date was historical:

```text
2026-08-01 10:00:00
```

However, the ingestion timestamp occurred later:

```text
2026-09-04
```

This simulates a common real-world scenario:

```text
Historical Event
      │
      │
      ▼
Data arrives later
      │
      ▼
Pipeline processes it
```

The corresponding order item was:

```text
order_item_id = 1063
product_id = 2
quantity = 1
unit_price = 2499.00
```

The record was then processed using:

```bash
dbt run --select fact_order_items
```

The output showed:

```text
INSERT 0 1
```

The late-arriving record was successfully added to the Gold fact table.

---

# Backfill Simulation

The project tested a backfill scenario involving historical data.

The scenario demonstrated that:

```text
Event Date
    ≠
Ingestion Date
```

For the late-arriving record:

```text
order_date:
2026-08-01
```

while:

```text
ingested_at:
2026-09-04
```

This is important because real-world pipelines may receive historical records after newer data has already been processed.

The project successfully demonstrated processing this late-arriving record.

---

# Backfill Strategy

The project documentation includes:

```text
docs/backfill_strategy.md
```

The strategy covers scenarios such as:

- Historical missing data.
- Late-arriving records.
- Failed pipeline runs.
- Full model rebuilds.

A full rebuild can be performed using:

```bash
dbt run --full-refresh
```

For the incremental fact model, this recreates the model from the complete upstream dataset.

Conceptually:

```text
Existing Incremental Table
        │
        ▼
Full Refresh
        │
        ▼
Rebuild from Source Data
        │
        ▼
Complete Updated Table
```

---

# Current Gold Layer Results

After incremental and late-arriving data simulations, the Gold layer contains:

| Table              | Row Count |
| ------------------ | --------: |
| `dim_customers`    |        15 |
| `dim_products`     |        15 |
| `fact_order_items` |        63 |

The Gold schema contains:

```text
analytics_gold.dim_customers
analytics_gold.dim_products
analytics_gold.fact_order_items
```

---

# Analytical SQL Queries

The project includes:

```text
sql/analytics_queries.sql
```

The queries demonstrate how the Gold layer can be used for business analysis.

---

# Customer Sales Analysis

The project calculates:

- Customer ID.
- Customer name.
- Total number of orders.
- Total sales.

Example logic:

```sql
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.total_amount) AS total_sales
FROM analytics_gold.fact_order_items AS f
JOIN analytics_gold.dim_customers AS c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_sales DESC;
```

This demonstrates:

- SQL joins.
- Aggregations.
- `COUNT(DISTINCT ...)`.
- `SUM()`.
- `GROUP BY`.
- Analytical reporting.

---

# Product Performance Analysis

The project analyzes product-level performance.

Metrics include:

```text
Total Quantity Sold
Total Revenue
```

Example query:

```sql
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(f.quantity) AS total_quantity_sold,
    SUM(f.total_amount) AS total_revenue
FROM analytics_gold.fact_order_items AS f
JOIN analytics_gold.dim_products AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY total_revenue DESC;
```

This demonstrates:

- Fact-to-dimension joins.
- Product-level aggregation.
- Revenue analysis.
- Quantity analysis.

---

# Daily Sales Analysis

The project analyzes sales over time.

Metrics include:

```text
Total Orders
Total Items Sold
Total Revenue
```

Example query:

```sql
SELECT
    DATE(order_date) AS order_day,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS total_items_sold,
    SUM(total_amount) AS total_revenue
FROM analytics_gold.fact_order_items
GROUP BY DATE(order_date)
ORDER BY order_day;
```

This demonstrates:

- Date transformation.
- Time-based aggregation.
- Revenue trends.
- Daily order analysis.

---

# Data Freshness

Raw source freshness is configured in:

```text
ecommerce_dbt/models/sources/sources.yml
```

Data freshness checks help identify situations where source tables have not received new data within an expected period.

The dbt command is:

```bash
dbt source freshness
```

This is useful for monitoring source data availability.

Conceptually:

```text
Expected Source Updates
          │
          ▼
Source Freshness Check
          │
          ├── Fresh
          │
          └── Stale
```

---

# Full Project Validation

The complete dbt project was validated using:

```bash
dbt build
```

The build command runs:

- Models.
- Tests.
- Dependencies in the correct order.

The project successfully completed with:

```text
PASS=113
WARN=0
ERROR=0
SKIP=0
```

The build included:

```text
1 Incremental Model
2 Table Models
8 View Models
102 Data Tests
```

This confirms that:

- All models built successfully.
- All data quality tests passed.
- All relationships were valid.
- The incremental model executed successfully.
- The complete transformation pipeline worked correctly.

---

# dbt Commands

## Check dbt Installation

```bash
dbt --version
```

---

## Install dbt Dependencies

```bash
dbt deps
```

---

## Validate Database Connection

```bash
dbt debug
```

---

## Run All Models

```bash
dbt run
```

---

## Run a Specific Model

```bash
dbt run --select fact_order_items
```

---

## Run All Tests

```bash
dbt test
```

---

## Build the Complete Project

```bash
dbt build
```

This is the main validation command for the project.

---

## Run Source Freshness Checks

```bash
dbt source freshness
```

---

## Full Refresh

To rebuild incremental models:

```bash
dbt run --full-refresh
```

For a complete rebuild and validation:

```bash
dbt build --full-refresh
```

---

# Environment Setup

## 1. Clone the Repository

```bash
git clone https://github.com/Ashu11122000/ecommerce-analytics.git
```

Move into the repository directory:

```bash
cd ecommerce-analytics-engineering
```

---

## 2. Create a Python Virtual Environment

Example using Python 3.12:

```powershell
py -3.12 -m venv .venv
```

---

## 3. Activate the Virtual Environment

PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

You should see:

```text
(.venv)
```

at the beginning of the terminal prompt.

---

## 4. Install Dependencies

Install dependencies from:

```text
requirements.txt
```

Command:

```powershell
pip install -r requirements.txt
```

Alternatively:

```powershell
pip install dbt-postgres
```

---

## 5. Verify dbt

```powershell
dbt --version
```

---

# PostgreSQL Setup

Create the database using:

```text
sql/01_create_database.sql
```

Create the raw tables using:

```text
sql/02_create_raw_tables.sql
```

Insert mock data using:

```text
sql/03_insert_raw_data.sql
```

The workflow is:

```text
Create Database
       ↓
Create Schemas
       ↓
Create Raw Tables
       ↓
Insert Mock Data
       ↓
Configure dbt
       ↓
Run Transformations
```

---

# Running the Project

After configuring PostgreSQL and dbt:

Move into the dbt project:

```powershell
cd ecommerce_dbt
```

Install packages:

```powershell
dbt deps
```

Validate the connection:

```powershell
dbt debug
```

Run the complete pipeline:

```powershell
dbt build
```

---

# Expected Transformation Flow

When the project runs successfully:

```text
raw.customers
      ↓
bronze_customers
      ↓
silver_customers
      ↓
dim_customers
```

```text
raw.products
      ↓
bronze_products
      ↓
silver_products
      ↓
dim_products
```

```text
raw.orders
      ↓
bronze_orders
      ↓
silver_orders
      │
      │
raw.order_items
      ↓
bronze_order_items
      ↓
silver_order_items
      │
      ▼
fact_order_items
```

---

# Data Lineage

One of the important benefits of dbt is automatic lineage tracking.

The project lineage can be understood as:

```text
Sources
   │
   ▼
Bronze Models
   │
   ▼
Silver Models
   │
   ▼
Gold Models
```

dbt tracks dependencies created through:

```jinja
{{ source() }}
```

and:

```jinja
{{ ref() }}
```

This makes the pipeline easier to understand and maintain.

---

# Why PostgreSQL?

PostgreSQL is used because it provides:

- Relational data storage.
- Strong SQL support.
- Schema-based organization.
- Joins and aggregations.
- ACID-compliant transactions.
- Compatibility with dbt.
- A realistic environment for learning analytics engineering.

In this project, PostgreSQL acts as both:

```text
Source Data Store
        +
Analytical Transformation Destination
```

---

# Why dbt?

dbt is used because it allows data transformations to be managed using SQL and software engineering practices.

dbt provides:

- Modular SQL models.
- Dependency management.
- Data lineage.
- Testing.
- Documentation.
- Incremental models.
- Macros.
- Source definitions.
- Freshness checks.
- Reusable transformation logic.

The project demonstrates how dbt can turn raw database tables into analytics-ready datasets.

---

# Key Concepts Demonstrated

This project demonstrates practical implementation of the following concepts.

## Data Engineering

- Data pipelines.
- Data ingestion.
- Data transformation.
- Data quality.
- Data storage.
- Analytical data modeling.

---

## Databases

- PostgreSQL.
- Relational databases.
- Database schemas.
- Tables.
- Primary keys.
- Foreign keys.

---

## SQL

- `SELECT`.
- `INSERT`.
- `JOIN`.
- `GROUP BY`.
- `ORDER BY`.
- `COUNT`.
- `COUNT(DISTINCT ...)`.
- `SUM`.
- Date transformations.
- Aggregations.

---

## OLTP and OLAP

The raw layer represents an OLTP-style model.

The Gold layer represents an analytics-oriented OLAP-style model.

```text
OLTP
 ↓
Transactional Data
 ↓
Transformation
 ↓
OLAP / Analytics
```

---

## ELT

The project follows:

```text
Extract
   ↓
Load
   ↓
Transform
```

Data is loaded into PostgreSQL before dbt transformations are applied.

---

## Medallion Architecture

The project implements:

```text
Raw
 ↓
Bronze
 ↓
Silver
 ↓
Gold
```

---

## dbt

The project demonstrates:

- dbt models.
- `source()`.
- `ref()`.
- Schema YAML files.
- Tests.
- Custom tests.
- Macros.
- Incremental models.
- Freshness checks.
- `dbt build`.
- `dbt run`.
- `dbt test`.
- Full refreshes.

---

## Dimensional Modeling

The project implements:

- Dimension tables.
- Fact tables.
- Fact table grain.
- Star Schema.
- Analytical modeling.

---

## Data Quality

The project implements:

- Not Null tests.
- Unique tests.
- Relationship tests.
- Custom business rule tests.

---

## Incremental Processing

The project demonstrates:

- Incremental fact loading.
- Processing new records.
- Avoiding unnecessary full rebuilds.
- Unique keys.
- Full refreshes.

---

## Backfills and Late-Arriving Data

The project demonstrates:

- Historical data arriving late.
- Differences between event time and ingestion time.
- Incremental processing of late-arriving records.
- Full-refresh recovery strategies.

---

# Security and Git Practices

The following files and directories should not be committed to Git:

```text
.venv/
target/
logs/
dbt_packages/
profiles.yml
.env
```

These may contain:

- Local dependencies.
- Generated dbt artifacts.
- Database credentials.
- Environment-specific configuration.

Example configuration files should be used instead.

---

# Recommended `.gitignore`

The project should ignore:

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

# Project Validation Results

The latest complete project validation was performed using:

```bash
dbt build
```

Result:

```text
Completed successfully

PASS=113
WARN=0
ERROR=0
SKIP=0
NO-OP=0
REUSED=0
TOTAL=113
```

The run completed:

```text
1 incremental model
2 table models
102 data tests
8 view models
```

This confirms that the complete data pipeline and all configured tests passed successfully.

---

# Final Project Outcome

The project successfully implements an end-to-end analytics engineering workflow.

The final architecture is:

```text
PostgreSQL Raw Data
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
        │
        ├── dim_customers
        │
        ├── dim_products
        │
        └── fact_order_items
                 │
                 ▼
         Analytics & Insights
```

The project demonstrates the complete journey from:

```text
Raw Transactional Data
        ↓
Data Transformation
        ↓
Data Quality Validation
        ↓
Dimensional Modeling
        ↓
Incremental Processing
        ↓
Analytics-Ready Tables
```

---

# Future Improvements

Although the core assignment requirements are complete, the project can be extended further.

Possible future improvements include:

- Adding more source tables.
- Adding more fact tables.
- Implementing Slowly Changing Dimensions.
- Adding snapshots.
- Adding dbt exposures.
- Creating dashboards using Power BI or Tableau.
- Adding orchestration using Apache Airflow.
- Adding automated CI/CD using GitHub Actions.
- Adding data quality packages such as `dbt_utils`.
- Adding anomaly detection tests.
- Adding more advanced incremental strategies.
- Adding partitioning strategies for large datasets.
- Deploying the project to a cloud data warehouse.

---

# Learning Outcomes

By completing this project, the following concepts were practiced:

- Data Engineering fundamentals.
- Analytics Engineering.
- PostgreSQL.
- SQL.
- OLTP vs OLAP.
- ELT.
- Data pipelines.
- Data transformation.
- Data modeling.
- Medallion Architecture.
- Bronze, Silver, and Gold layers.
- dbt.
- dbt models.
- dbt sources.
- dbt tests.
- dbt macros.
- Data freshness.
- Incremental models.
- Backfills.
- Late-arriving data.
- Fact tables.
- Dimension tables.
- Fact table grain.
- Star Schema.
- Referential integrity.
- Data quality testing.
- Analytical SQL.
- Git project organization.

---

# Assignment Requirements Mapping

| Assignment Requirement    | Status    | Implementation                            |
| ------------------------- | --------- | ----------------------------------------- |
| Git repository            | Completed | Project repository created                |
| Local PostgreSQL database | Completed | `ecommerce_analytics`                     |
| Raw source tables         | Completed | Customers, products, orders, order items  |
| Mock data ingestion       | Completed | SQL insert scripts and manual simulations |
| dbt project               | Completed | `ecommerce_dbt`                           |
| Source definitions        | Completed | `sources.yml`                             |
| Bronze layer              | Completed | 4 Bronze models                           |
| Silver layer              | Completed | 4 Silver models                           |
| Gold layer                | Completed | 2 dimensions + 1 fact                     |
| Fact table                | Completed | `fact_order_items`                        |
| Dimension tables          | Completed | `dim_customers`, `dim_products`           |
| Dimensional modeling      | Completed | Star Schema                               |
| Data quality tests        | Completed | 102 dbt data tests                        |
| Custom data test          | Completed | Positive order amount validation          |
| Incremental processing    | Completed | `fact_order_items`                        |
| Backfill simulation       | Completed | Late-arriving historical record           |
| Data freshness            | Completed | Source freshness configuration            |
| dbt macro                 | Completed | Audit column macro                        |
| Analytical queries        | Completed | Customer, product, and daily analysis     |
| Full project validation   | Completed | `dbt build` with 113 passes               |

---

# Conclusion

This project demonstrates a complete small-scale **Data Engineering and Analytics Engineering pipeline** using PostgreSQL and dbt.

It starts with raw OLTP-style transactional data and transforms it through multiple layers:

```text
Raw
 ↓
Bronze
 ↓
Silver
 ↓
Gold
```

The final Gold layer implements a dimensional Star Schema containing:

```text
dim_customers
dim_products
fact_order_items
```

The project also demonstrates important real-world engineering practices including:

- Data quality testing.
- Referential integrity validation.
- Incremental processing.
- Late-arriving data handling.
- Backfill simulation.
- Audit columns.
- Source freshness.
- Reusable macros.
- Analytical querying.

The complete dbt pipeline was successfully validated with:

```text
PASS=113
WARN=0
ERROR=0
```

This confirms that the project models, tests, and transformation pipeline are functioning successfully.
