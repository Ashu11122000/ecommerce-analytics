# E-Commerce Analytics Engineering Project

## Project Overview

This project is an end-to-end **Data Engineering and Analytics Engineering** project built using **PostgreSQL** and **dbt (data build tool)**.

The goal is to build a simple analytical data model that:

1. Ingests raw OLTP-style data into PostgreSQL.
2. Defines raw source tables using dbt source definitions.
3. Transforms data through **Bronze, Silver, and Gold layers**.
4. Creates analytics-ready tables using **dimensional modeling principles**.
5. Builds at least one **fact table** and multiple **dimension tables**.
6. Implements data quality tests using dbt.
7. Demonstrates analytical SQL queries.
8. Implements important data engineering practices such as incremental processing, backfills, data freshness checks, macros, and clear project organization.

---

# Technology Stack

| Technology   | Purpose                                      |
| ------------ | -------------------------------------------- |
| PostgreSQL   | Local relational database and data warehouse |
| dbt Core     | SQL-based data transformation framework      |
| dbt-postgres | PostgreSQL adapter for dbt                   |
| Python       | Environment required for dbt                 |
| Git          | Version control                              |
| PowerShell   | Local development environment                |

---

# Project Architecture

The planned data flow is:

```text
Mock / OLTP-Style Data
          │
          ▼
┌─────────────────────┐
│     PostgreSQL      │
│                     │
│      RAW LAYER      │
│                     │
│ customers           │
│ products            │
│ orders              │
│ order_items         │
└──────────┬──────────┘
           │
           │ dbt
           ▼
┌─────────────────────┐
│    BRONZE LAYER     │
│                     │
│ Minimal cleaning    │
│ Type standardizing  │
│ Column naming       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│    SILVER LAYER     │
│                     │
│ Cleaned data        │
│ Standardized data   │
│ Business logic      │
└──────────┬──────────┘
           │
           ▼
┌────────────────────────────┐
│         GOLD LAYER         │
│                            │
│ Analytics-Ready Tables     │
│                            │
│ Dimensions                 │
│ • dim_customers            │
│ • dim_products             │
│                            │
│ Facts                      │
│ • fact_order_items         │
└──────────────┬─────────────┘
               │
               ▼
       Analytics & Insights
```

---

# Planned Data Model

The final Gold layer will follow a **Star Schema** design.

## Dimension Tables

### `dim_customers`

Stores descriptive information about customers.

Planned columns include:

* `customer_id`
* `customer_name`
* `email`
* `city`
* `signup_date`

### `dim_products`

Stores descriptive information about products.

Planned columns include:

* `product_id`
* `product_name`
* `category`
* `price`

---

## Fact Table

### `fact_order_items`

Stores transactional events at the **order item level**.

Planned columns include:

* `order_item_id`
* `order_id`
* `customer_id`
* `product_id`
* `order_date`
* `quantity`
* `unit_price`
* `total_amount`

### Fact Table Grain

The grain of `fact_order_items` will be:

> **One row represents one product item within one order.**

This is an important design decision because the grain determines what each row in a fact table represents.

---

# Planned Star Schema

```text
                 ┌─────────────────────┐
                 │    dim_customers    │
                 │─────────────────────│
                 │ customer_id (PK)    │
                 │ customer_name       │
                 │ email               │
                 │ city                │
                 │ signup_date         │
                 └──────────┬──────────┘
                            │
                            │ customer_id
                            │
                    ┌───────▼────────┐
                    │fact_order_items│
                    │────────────────│
                    │ order_item_id  │
                    │ order_id       │
                    │ customer_id FK │
                    │ product_id FK  │
                    │ order_date     │
                    │ quantity       │
                    │ unit_price     │
                    │ total_amount   │
                    └───────┬────────┘
                            │
                            │ product_id
                            │
                 ┌──────────▼──────────┐
                 │    dim_products     │
                 │─────────────────────│
                 │ product_id (PK)     │
                 │ product_name        │
                 │ category            │
                 │ price               │
                 └─────────────────────┘
```

---

# Medallion Architecture

This project uses a simplified **Medallion Architecture**.

## Raw Layer

The raw layer contains data in its original or near-original format.

Planned PostgreSQL tables:

```text
raw.customers
raw.products
raw.orders
raw.order_items
```

These tables represent an **OLTP-style transactional data model**.

---

## Bronze Layer

The Bronze layer performs minimal transformation.

Responsibilities include:

* Reading data from dbt sources.
* Standardizing column names.
* Basic type casting.
* Adding ingestion or audit information where required.
* Preserving data close to the original source.

Planned models:

```text
bronze_customers
bronze_products
bronze_orders
bronze_order_items
```

---

## Silver Layer

The Silver layer contains cleaned and standardized data.

Responsibilities include:

* Removing invalid records.
* Standardizing text values.
* Handling null values.
* Applying business rules.
* Creating reusable cleaned datasets.

Planned models:

```text
silver_customers
silver_products
silver_orders
silver_order_items
```

---

## Gold Layer

The Gold layer contains analytics-ready data.

It will implement dimensional modeling using:

```text
Dimensions
├── dim_customers
└── dim_products

Facts
└── fact_order_items
```

The Gold layer will be optimized for analytical queries rather than transactional operations.

---

# Why PostgreSQL?

PostgreSQL is used as the local database for this project because it provides:

* Relational data storage.
* SQL support.
* Schemas for organizing data layers.
* Support for joins and aggregations.
* Compatibility with dbt.
* A realistic environment for learning analytical data modeling.

The database will contain raw source data and dbt-generated transformation layers.

---

# Why dbt?

dbt is used to transform data using SQL.

dbt allows us to:

* Write modular SQL models.
* Define dependencies between models.
* Use `ref()` to reference other models.
* Define sources using `source()`.
* Run data quality tests.
* Generate documentation.
* Build incremental models.
* Reuse SQL logic with macros.

The transformation approach follows an **ELT-style workflow**:

```text
Extract
   ↓
Load into PostgreSQL
   ↓
Transform using dbt
```

---

# Complete Repository Structure

The current repository is organized as follows:

```text
ecommerce-analytics-engineering/
│
├── .venv/                         # Local Python virtual environment (ignored by Git)
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
    ├── target/                    # Generated by dbt, ignored by Git
    ├── logs/                      # Generated by dbt, ignored by Git
    └── dbt_packages/              # Generated by dbt packages, ignored by Git
```

---

# SQL Scripts

The `sql/` directory contains database-related scripts.

## `01_create_database.sql`

This script will contain commands related to creating the PostgreSQL database.

## `02_create_raw_tables.sql`

This script will create the raw OLTP-style tables:

```text
customers
products
orders
order_items
```

## `03_insert_raw_data.sql`

This script will insert mock transactional data into the raw tables.

## `analytics_queries.sql`

This file will contain SQL queries demonstrating:

* Aggregations.
* Joins.
* Grouping.
* Revenue analysis.
* Customer analysis.
* Product analysis.
* Time-based analysis.

---

# Documentation

The `docs/` directory contains additional project documentation.

## `architecture.md`

Will explain:

* Overall system architecture.
* Data flow.
* PostgreSQL and dbt responsibilities.
* Medallion architecture.

## `data_model.md`

Will explain:

* Fact tables.
* Dimension tables.
* Table grain.
* Primary keys.
* Foreign keys.
* Star schema design.

## `backfill_strategy.md`

Will document how historical or missing data can be reprocessed.

---

# Data Quality Testing

The project will use dbt tests to validate data quality.

Planned tests include:

## Not Null

Used for important fields such as:

```text
customer_id
product_id
order_id
order_item_id
```

Example:

```yaml
tests:
  - not_null
```

---

## Unique

Used for primary key fields in dimension tables.

Example:

```yaml
customer_id:
  tests:
    - not_null
    - unique
```

---

## Relationships

Used to validate foreign key relationships.

For example:

```text
fact_order_items.customer_id
            │
            ▼
dim_customers.customer_id
```

A relationship test ensures that every customer referenced in the fact table exists in the customer dimension.

---

# Incremental Processing

The project will implement an incremental strategy for appropriate large or transactional models.

The likely candidate is:

```text
fact_order_items
```

The goal of incremental processing is to avoid rebuilding the entire dataset when only new data needs to be processed.

Conceptually:

```text
Existing Gold Table
        +
New Source Records
        │
        ▼
Incremental dbt Run
        │
        ▼
Updated Gold Table
```

A full rebuild will also be supported using:

```bash
dbt run --full-refresh
```

---

# Backfill Strategy

The project will document a strategy for handling:

* Historical missing data.
* Late-arriving data.
* Failed pipeline runs.
* Full table rebuilds.

Possible approaches include:

```bash
dbt run --full-refresh
```

and controlled date-based processing using dbt variables.

The final implementation and commands will be documented in:

```text
docs/backfill_strategy.md
```

---

# Data Freshness

The project will configure data freshness checks for raw source tables.

The purpose is to detect situations where source data has not been updated within an expected time period.

The checks will be configured in:

```text
ecommerce_dbt/models/sources/sources.yml
```

The planned command is:

```bash
dbt source freshness
```

---

# dbt Macros

The project includes a location for reusable dbt macros:

```text
ecommerce_dbt/macros/
```

The macro:

```text
add_audit_columns.sql
```

will be used to reduce repetitive SQL logic where appropriate.

Macros use Jinja templating and allow reusable SQL patterns.

---

# Environment Setup

## 1. Clone the Repository

```bash
git clone https://github.com/Ashu11122000/ecommerce-analytics.git
```

Move into the project directory:

```bash
cd ecommerce-analytics-engineering
```

---

## 2. Create a Virtual Environment

Example for Python 3.12:

```powershell
py -3.12 -m venv .venv
```

Activate it:

```powershell
.\.venv\Scripts\Activate.ps1
```

You should see:

```text
(.venv)
```

at the beginning of the terminal prompt.

---

## 3. Install Dependencies

Install the required Python dependencies:

```powershell
pip install -r requirements.txt
```

Alternatively, install the PostgreSQL dbt adapter:

```powershell
pip install dbt-postgres
```

Verify dbt:

```powershell
dbt --version
```


---

# Security and Git Practices

The following files and folders should not be committed:

```text
.venv/
target/
logs/
dbt_packages/
profiles.yml
.env
```

These may contain:

* Local dependencies.
* Generated files.
* Database credentials.
* Environment-specific configuration.

The repository will provide example configuration files where required.

---

# Learning Objectives

This project is designed to demonstrate understanding of:

* Data Engineering fundamentals.
* OLTP vs OLAP.
* PostgreSQL.
* SQL.
* ELT workflows.
* Data pipelines.
* dbt.
* Data transformations.
* Data lineage.
* Medallion architecture.
* Bronze, Silver, and Gold layers.
* Dimensional modeling.
* Fact tables.
* Dimension tables.
* Star schema.
* Data quality testing.
* Incremental processing.
* Backfills.
* Data freshness.
* SQL joins.
* SQL aggregations.
* Analytical queries.
* Git and project organization.

---

# Project Status

**Current Stage:** Environment and project structure setup complete.

**Next Stage:** PostgreSQL database setup and raw OLTP-style data ingestion.
