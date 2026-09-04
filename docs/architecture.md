# E-Commerce Analytics Engineering Project Architecture

## Overview

This document describes the complete architecture of the **E-Commerce Analytics Engineering Project**.

The project implements an end-to-end **ELT (Extract, Load, Transform)** pipeline using:

- PostgreSQL
- dbt Core
- dbt-postgres
- SQL
- Python virtual environment
- Git

The architecture transforms raw e-commerce transactional data into analytics-ready datasets using a simplified **Medallion Architecture**:

```text
Raw → Bronze → Silver → Gold → Analytics
```

The final analytical layer follows **dimensional modeling principles** and implements a **Star Schema**.

---

## Table of Contents

- [1. High-Level Architecture](#1-high-level-architecture)
- [2. Architecture Principles](#2-architecture-principles)
- [3. PostgreSQL Architecture](#3-postgresql-architecture)
- [4. Raw Layer](#4-raw-layer)
- [5. dbt Source Layer](#5-dbt-source-layer)
- [6. Bronze Layer](#6-bronze-layer)
- [7. Silver Layer](#7-silver-layer)
- [8. Gold Layer](#8-gold-layer)
- [9. Gold Layer Architecture](#9-gold-layer-architecture)
- [10. Dimension Table: dim_customers](#10-dimension-table-dim_customers)
- [11. Dimension Table: dim_products](#11-dimension-table-dim_products)
- [12. Fact Table: fact_order_items](#12-fact-table-fact_order_items)
- [13. Fact Table Metrics](#13-fact-table-metrics)
- [14. Star Schema](#14-star-schema)
- [15. dbt Model Dependencies](#15-dbt-model-dependencies)
- [16. Audit Columns](#16-audit-columns)
- [17. dbt Macro Architecture](#17-dbt-macro-architecture)
- [18. Incremental Processing Architecture](#18-incremental-processing-architecture)
- [19. Incremental Data Flow](#19-incremental-data-flow)
- [20. Backfill Architecture](#20-backfill-architecture)
- [21. Full Refresh Architecture](#21-full-refresh-architecture)
- [22. Data Quality Architecture](#22-data-quality-architecture)
- [23. Types of Data Quality Tests](#23-types-of-data-quality-tests)
- [24. Source Freshness Architecture](#24-source-freshness-architecture)
- [25. Data Lineage](#25-data-lineage)
- [26. Analytics Architecture](#26-analytics-architecture)
- [27. Current Gold Layer Results](#27-current-gold-layer-results)
- [28. End-to-End Pipeline Execution](#28-end-to-end-pipeline-execution)
- [29. Repository Architecture](#29-repository-architecture)
- [30. Schema Organization](#30-schema-organization)
- [31. Model Materialization Strategy](#31-model-materialization-strategy)
- [32. Why the Fact Table Is Incremental](#32-why-the-fact-table-is-incremental)
- [33. Handling Late-Arriving Data](#33-handling-late-arriving-data)
- [34. Data Validation Results](#34-data-validation-results)
- [35. End-to-End Data Flow Example](#35-end-to-end-data-flow-example)
- [36. Complete Technology Responsibilities](#36-complete-technology-responsibilities)
- [37. Architecture Benefits](#37-architecture-benefits)
- [38. Future Architecture Improvements](#38-future-architecture-improvements)
- [39. Final Architecture Summary](#39-final-architecture-summary)
- [40. Project Completion Status](#40-project-completion-status)

---

# 1. High-Level Architecture

```text
                         ┌──────────────────────────┐
                         │   Mock E-Commerce Data   │
                         │                          │
                         │ Customers                │
                         │ Products                 │
                         │ Orders                   │
                         │ Order Items              │
                         └────────────┬─────────────┘
                                      │
                                      │ Load
                                      ▼
                    ┌─────────────────────────────────┐
                    │           PostgreSQL            │
                    │                                 │
                    │           RAW SCHEMA            │
                    │                                 │
                    │ raw.customers                   │
                    │ raw.products                    │
                    │ raw.orders                      │
                    │ raw.order_items                 │
                    └───────────────┬─────────────────┘
                                    │
                                    │ dbt source()
                                    ▼
                    ┌─────────────────────────────────┐
                    │         BRONZE LAYER            │
                    │                                 │
                    │ analytics_bronze                │
                    │                                 │
                    │ bronze_customers                │
                    │ bronze_products                 │
                    │ bronze_orders                   │
                    │ bronze_order_items              │
                    └───────────────┬─────────────────┘
                                    │
                                    │ dbt ref()
                                    ▼
                    ┌─────────────────────────────────┐
                    │         SILVER LAYER            │
                    │                                 │
                    │ analytics_silver                │
                    │                                 │
                    │ silver_customers                │
                    │ silver_products                 │
                    │ silver_orders                   │
                    │ silver_order_items              │
                    └───────────────┬─────────────────┘
                                    │
                                    │ dbt ref()
                                    ▼
                    ┌─────────────────────────────────┐
                    │          GOLD LAYER             │
                    │                                 │
                    │ analytics_gold                  │
                    │                                 │
                    │ dim_customers                   │
                    │ dim_products                    │
                    │ fact_order_items                │
                    └───────────────┬─────────────────┘
                                    │
                                    ▼
                    ┌─────────────────────────────────┐
                    │      Analytics & Insights       │
                    │                                 │
                    │ Customer Analysis               │
                    │ Product Analysis                │
                    │ Revenue Analysis                │
                    │ Time-Based Analysis             │
                    └─────────────────────────────────┘
```

---

# 2. Architecture Principles

The project follows several important data engineering and analytics engineering principles.

## 2.1 Separation of Layers

Each layer has a clearly defined responsibility.

```text
Raw
 ↓
Bronze
 ↓
Silver
 ↓
Gold
```

Data transformations are separated instead of placing all business logic inside one SQL query.

## 2.2 ELT Approach

The project follows an **ELT workflow**.

```text
Extract
   │
   ▼
Load
   │
   ▼
PostgreSQL Raw Tables
   │
   ▼
Transform with dbt
   │
   ▼
Analytics-Ready Data
```

### Extract

Mock e-commerce data represents data extracted from an operational source system.

### Load

The data is loaded into PostgreSQL raw tables.

### Transform

dbt transforms the raw data through the Bronze, Silver, and Gold layers.

## 2.3 Modular Transformations

Each transformation is implemented as a separate dbt model.

```text
Raw
  ↓
Bronze Models
  ↓
Silver Models
  ↓
Gold Models
```

This improves:

- Maintainability
- Readability
- Reusability
- Testing
- Debugging
- Data lineage

---

# 3. PostgreSQL Architecture

PostgreSQL acts as both:

1. The source data storage system for this project.
2. The analytical storage environment for dbt models.

The database is organized into multiple schemas.

```text
ecommerce_analytics
│
├── raw
│
├── analytics_bronze
│
├── analytics_silver
│
└── analytics_gold
```

Each schema represents a different stage in the data pipeline.

---

# 4. Raw Layer

## Schema

```text
raw
```

The Raw layer contains the original transactional data.

The tables are:

```text
raw.customers
raw.products
raw.orders
raw.order_items
```

These tables represent an OLTP-style e-commerce data model.

## 4.1 `raw.customers`

Stores customer information.

Typical columns include:

```text
customer_id
customer_name
email
city
signup_date
ingested_at
```

### Primary Identifier

```text
customer_id
```

## 4.2 `raw.products`

Stores product information.

Typical columns include:

```text
product_id
product_name
category
price
ingested_at
```

### Primary Identifier

```text
product_id
```

## 4.3 `raw.orders`

Stores order-level information.

Typical columns include:

```text
order_id
customer_id
order_date
order_status
ingested_at
```

### Primary Identifier

```text
order_id
```

### Relationship

```text
orders.customer_id
        │
        ▼
customers.customer_id
```

Each order belongs to a customer.

## 4.4 `raw.order_items`

Stores individual products within orders.

Typical columns include:

```text
order_item_id
order_id
product_id
quantity
unit_price
ingested_at
```

### Primary Identifier

```text
order_item_id
```

### Relationships

```text
order_items.order_id
        │
        ▼
orders.order_id
```

and:

```text
order_items.product_id
        │
        ▼
products.product_id
```

---

# 5. dbt Source Layer

dbt source definitions describe the raw PostgreSQL tables.

The source configuration is located at:

```text
ecommerce_dbt/models/sources/sources.yml
```

The raw tables are referenced using:

```jinja
{{ source('raw', 'customers') }}
```

or:

```jinja
{{ source('raw', 'orders') }}
```

This provides an abstraction between the physical PostgreSQL table and dbt transformation models.

---

# 6. Bronze Layer

## Schema

```text
analytics_bronze
```

The Bronze layer performs minimal transformation.

The models are:

```text
bronze_customers
bronze_products
bronze_orders
bronze_order_items
```

## Bronze Layer Responsibilities

The Bronze layer is responsible for:

- Reading raw source tables.
- Standardizing column naming.
- Applying basic type handling.
- Preserving source data structure.
- Adding audit information.
- Creating a clean starting point for downstream transformations.

The Bronze layer remains close to the original source.

## Bronze Data Flow

```text
raw.customers
       │
       ▼
bronze_customers


raw.products
       │
       ▼
bronze_products


raw.orders
       │
       ▼
bronze_orders


raw.order_items
       │
       ▼
bronze_order_items
```

---

# 7. Silver Layer

## Schema

```text
analytics_silver
```

The Silver layer contains cleaned and standardized datasets.

The models are:

```text
silver_customers
silver_products
silver_orders
silver_order_items
```

## Silver Layer Responsibilities

The Silver layer performs transformations such as:

- Data cleaning.
- Standardization.
- Business rule application.
- Data validation.
- Reusable transformation logic.
- Preparing datasets for dimensional modeling.

The Silver layer acts as the main cleaned data layer.

## Silver Data Flow

```text
bronze_customers
       │
       ▼
silver_customers


bronze_products
       │
       ▼
silver_products


bronze_orders
       │
       ▼
silver_orders


bronze_order_items
       │
       ▼
silver_order_items
```

---

# 8. Gold Layer

## Schema

```text
analytics_gold
```

The Gold layer contains analytics-ready tables.

The final models are:

```text
dim_customers
dim_products
fact_order_items
```

The Gold layer follows a **Star Schema** design.

---

# 9. Gold Layer Architecture

```text
                       analytics_gold

                    ┌─────────────────┐
                    │  dim_customers  │
                    └────────┬────────┘
                             │
                             │ customer_id
                             │
                             ▼
                  ┌─────────────────────────┐
                  │    fact_order_items     │
                  └────────────┬────────────┘
                               │
                               │ product_id
                               │
                               ▼
                    ┌─────────────────┐
                    │  dim_products   │
                    └─────────────────┘
```

---

# 10. Dimension Table: `dim_customers`

The `dim_customers` table stores descriptive information about customers.

Typical columns include:

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

### Primary Key

```text
customer_id
```

### Purpose

The table provides customer-related attributes for analytical queries.

Example questions:

- Which customers generate the highest revenue?
- How many orders has each customer placed?
- Which cities have the highest customer activity?

---

# 11. Dimension Table: `dim_products`

The `dim_products` table stores descriptive information about products.

Typical columns include:

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

### Primary Key

```text
product_id
```

### Purpose

The table provides product-related attributes for analytical queries.

Example questions:

- Which products generate the most revenue?
- Which categories perform best?
- Which products have the highest quantity sold?

---

# 12. Fact Table: `fact_order_items`

The `fact_order_items` table stores transactional metrics at the order-item level.

Typical columns include:

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

## Fact Table Grain

The grain of the fact table is:

> **One row represents one product item within one order.**

This means:

```text
Order 101

Product A
Product B
Product C
```

would create multiple rows in the fact table.

Example:

| order_item_id | order_id | product_id | quantity |
| ------------- | -------: | ---------: | -------: |
| 1001          |      101 |          1 |        2 |
| 1002          |      101 |         13 |        3 |

Both rows belong to the same order but represent different order items.

---

# 13. Fact Table Metrics

The main calculated metric is:

```text
total_amount
```

The calculation is:

```text
total_amount = quantity × unit_price
```

Example:

```text
quantity   = 2
unit_price = 799.00

total_amount = 1598.00
```

This metric supports revenue analysis.

---

# 14. Star Schema

The Gold layer implements a Star Schema.

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
                         ┌──────────▼───────────┐
                         │   fact_order_items   │
                         │──────────────────────│
                         │ order_item_id (PK)   │
                         │ order_id             │
                         │ customer_id (FK)     │
                         │ product_id (FK)      │
                         │ order_date           │
                         │ quantity             │
                         │ unit_price           │
                         │ total_amount         │
                         └──────────┬───────────┘
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

# 15. dbt Model Dependencies

dbt automatically manages dependencies using:

```text
ref()
```

and:

```text
source()
```

The lineage is:

```text
                    SOURCES
                       │
       ┌───────────────┼────────────────┐
       │               │                │
       ▼               ▼                ▼

   customers        products          orders
       │               │                │
       ▼               ▼                ▼

bronze_customers bronze_products bronze_orders
       │               │                │
       ▼               ▼                ▼

silver_customers silver_products silver_orders
       │               │                │
       │               │                │
       │               │                ▼
       │               │         silver_order_items
       │               │                │
       ▼               ▼                ▼

dim_customers   dim_products   fact_order_items
```

More accurately, the fact model depends on multiple Silver models:

```text
silver_customers
       │

silver_orders
       │
       ├───────────────┐
       │               │
       ▼               ▼
silver_order_items   silver_products
       │               │
       └───────┬───────┘
               │
               ▼
       fact_order_items
```

---

# 16. Audit Columns

The project uses audit columns to track the movement of data through the pipeline.

Examples include:

```text
ingested_at
loaded_at
transformed_at
modeled_at
```

These columns help identify:

- When data entered the raw layer.
- When data was processed in Bronze.
- When data was transformed in Silver.
- When the Gold model was created or updated.

---

# 17. dbt Macro Architecture

Reusable SQL logic is stored in:

```text
ecommerce_dbt/macros/
```

The project includes:

```text
add_audit_columns.sql
```

Macros use Jinja templating.

Conceptually:

```text
Reusable SQL Logic
        │
        ▼
      Macro
        │
        ▼
Multiple dbt Models
```

This reduces repeated SQL code.

---

# 18. Incremental Processing Architecture

The following Gold model uses incremental processing:

```text
fact_order_items
```

Instead of rebuilding the complete fact table every time, dbt processes new records.

Conceptually:

```text
                    Raw Data
                       │
                       ▼
                 Silver Layer
                       │
                       ▼
              Incremental Filter
                       │
             ┌─────────┴─────────┐
             │                   │
             ▼                   ▼
       Existing Records      New Records
             │                   │
             └─────────┬─────────┘
                       │
                       ▼
              fact_order_items
```

The incremental model uses a unique key:

```text
order_item_id
```

This helps dbt identify records in the fact table.

---

# 19. Incremental Data Flow

Initial run:

```text
Raw Data
   │
   ▼
dbt Build
   │
   ▼
fact_order_items

61 records
```

A new record is inserted:

```text
raw.orders
      +
raw.order_items
```

Then:

```bash
dbt run --select fact_order_items
```

Only new eligible records are processed.

Example result:

```text
61 rows
   │
   ▼

New Order Item

   │
   ▼

62 rows
```

Additional backfill simulation:

```text
62 rows
   │
   ▼

Late-Arriving Historical Record

   │
   ▼

63 rows
```

The project successfully demonstrated incremental processing for newly arriving and historical records.

---

# 20. Backfill Architecture

A backfill is required when data arrives late or historical data needs to be reprocessed.

Example scenario:

```text
Historical order date:

2026-08-01
```

However, the record may be ingested later:

```text
2026-09-04
```

This creates a late-arriving historical record.

The architecture handles this using ingestion metadata.

```text
Historical Event Date
        │
        ▼
2026-08-01

        │
        │ Data arrives later
        ▼

Ingestion Date
        │
        ▼
2026-09-04

        │
        ▼

Incremental dbt Processing
        │
        ▼

Gold Fact Table Updated
```

This demonstrates the difference between:

```text
Business Event Time
```

and:

```text
Data Ingestion Time
```

---

# 21. Full Refresh Architecture

When a complete rebuild is required:

```bash
dbt run --full-refresh
```

Conceptually:

```text
Existing Gold Table
        │
        ▼
      Rebuild
        │
        ▼
All Source Records
        │
        ▼
New Gold Table
```

A full refresh is useful when:

- Transformation logic changes significantly.
- Incremental logic changes.
- Historical data must be completely rebuilt.
- Data corruption requires reconstruction.

---

# 22. Data Quality Architecture

The project uses dbt tests throughout the transformation layers.

The completed project contains:

```text
102 data tests
```

The final validation command was:

```bash
dbt build
```

Result:

```text
PASS=113
WARN=0
ERROR=0
SKIP=0
```

This includes:

```text
8 view models
2 table models
1 incremental model
102 data tests
```

---

# 23. Types of Data Quality Tests

## Not Null Tests

Used for required columns.

Examples:

```text
customer_id
product_id
order_id
order_item_id
quantity
unit_price
order_date
```

Example configuration:

```yaml
tests:
  - not_null
```

## Unique Tests

Used to validate unique identifiers.

Examples:

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
  - unique
```

## Relationship Tests

Relationship tests validate foreign key integrity.

Example:

```text
fact_order_items.customer_id
             │
             ▼
dim_customers.customer_id
```

Another example:

```text
fact_order_items.product_id
             │
             ▼
dim_products.product_id
```

The project also validates relationships in the Silver layer.

## Custom Data Test

The project contains a custom data test:

```text
test_positive_order_amount.sql
```

The test validates that order amounts are positive.

Conceptually:

```text
total_amount > 0
```

The test passed successfully during the final `dbt build`.

---

# 24. Source Freshness Architecture

Source freshness is configured for raw source tables.

The configuration is located in:

```text
ecommerce_dbt/models/sources/sources.yml
```

The command is:

```bash
dbt source freshness
```

Freshness checks help detect situations where source data has not been updated within an expected time period.

Conceptually:

```text
Current Time
      │
      ▼
Compare
      │
      ▼
Latest Source Ingestion Time
      │
      ▼
Fresh or Stale
```

The project uses ingestion timestamps to support freshness monitoring.

---

# 25. Data Lineage

The complete lineage can be summarized as:

```text
                         RAW
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼

   customers          products            orders
        │                 │                 │
        ▼                 ▼                 ▼

 bronze_customers  bronze_products   bronze_orders
        │                 │                 │
        ▼                 ▼                 ▼

 silver_customers  silver_products   silver_orders
        │                 │                 │
        │                 │                 │
        │                 │                 └──────────────┐
        │                 │                                │
        │                 │                         order_items
        │                 │                                │
        │                 │                                ▼
        │                 │                     bronze_order_items
        │                 │                                │
        │                 │                                ▼
        │                 │                     silver_order_items
        │                 │                                │
        ▼                 ▼                                │

 dim_customers      dim_products                            │
        │                 │                                │
        └─────────────────┼────────────────────────────────┘
                          │
                          ▼
                  fact_order_items
                          │
                          ▼
                 Analytics Queries
```

---

# 26. Analytics Architecture

The Gold layer supports analytical SQL queries.

The project demonstrates:

- Customer analysis
- Product analysis
- Revenue analysis
- Order analysis
- Time-based analysis

The analytical queries are stored in:

```text
sql/analytics_queries.sql
```

---

# 27. Current Gold Layer Results

The final Gold schema contains three tables:

```text
analytics_gold.dim_customers
analytics_gold.dim_products
analytics_gold.fact_order_items
```

The validated row counts are:

| Table              | Row Count |
| ------------------ | --------: |
| `dim_customers`    |        15 |
| `dim_products`     |        15 |
| `fact_order_items` |        63 |

The fact table contains both:

- Original transactional records.
- Newly inserted incremental records.
- A simulated late-arriving historical record.

---

# 28. End-to-End Pipeline Execution

The complete pipeline can be executed using:

```bash
dbt build
```

This command:

1. Builds Bronze models.
2. Runs Bronze tests.
3. Builds Silver models.
4. Runs Silver tests.
5. Builds Gold models.
6. Runs Gold tests.
7. Runs custom data tests.

The final successful execution produced:

```text
PASS=113
WARN=0
ERROR=0
SKIP=0
```

---

# 29. Repository Architecture

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
    │   │
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
    ├── target/                    # Generated by dbt
    ├── logs/                      # Generated by dbt
    └── dbt_packages/              # Installed dbt packages
```

---

# 30. Schema Organization

The PostgreSQL schemas provide logical separation between pipeline stages.

```text
PostgreSQL Database
│
├── raw
│   ├── customers
│   ├── products
│   ├── orders
│   └── order_items
│
├── analytics_bronze
│   ├── bronze_customers
│   ├── bronze_products
│   ├── bronze_orders
│   └── bronze_order_items
│
├── analytics_silver
│   ├── silver_customers
│   ├── silver_products
│   ├── silver_orders
│   └── silver_order_items
│
└── analytics_gold
    ├── dim_customers
    ├── dim_products
    └── fact_order_items
```

---

# 31. Model Materialization Strategy

The project uses different dbt materializations depending on the layer and purpose.

## Bronze

```text
Views
```

Bronze models provide lightweight access to source data with minimal transformation.

## Silver

```text
Views
```

Silver models provide reusable cleaned and standardized datasets.

## Gold Dimensions

```text
Tables
```

The dimension models are materialized as tables:

```text
dim_customers
dim_products
```

## Gold Fact

```text
Incremental
```

The fact model:

```text
fact_order_items
```

uses incremental processing.

---

# 32. Why the Fact Table Is Incremental

Fact tables can become large in real-world systems.

Rebuilding the complete table every time can become inefficient.

Instead:

```text
Existing Fact Data
        +
Newly Arriving Data
        │
        ▼
Incremental Processing
        │
        ▼
Updated Fact Table
```

The project demonstrates this pattern using:

```text
order_item_id
```

as the unique identifier.

---

# 33. Handling Late-Arriving Data

The project simulated late-arriving data.

A new order was inserted with an older business date.

Example:

```text
Order Date:

2026-08-01
```

However, the data was ingested later.

```text
Ingested:

2026-09-04
```

After running:

```bash
dbt run --select fact_order_items
```

the historical record was successfully inserted into the Gold fact table.

This demonstrates an important real-world data engineering scenario.

---

# 34. Data Validation Results

The complete pipeline was validated using:

```bash
dbt build
```

The execution successfully completed all models and tests.

Final result:

```text
PASS=113
WARN=0
ERROR=0
SKIP=0
NO-OP=0
REUSED=0
TOTAL=113
```

This confirms that:

- All models built successfully.
- Bronze tests passed.
- Silver tests passed.
- Gold tests passed.
- Relationship tests passed.
- Unique tests passed.
- Not-null tests passed.
- Custom positive order amount test passed.

---

# 35. End-to-End Data Flow Example

Consider a new order item arriving in the raw layer.

## Step 1: Raw Data

```text
raw.orders
raw.order_items
```

A new order is inserted.

## Step 2: Bronze Layer

The source data becomes available through:

```text
bronze_orders
bronze_order_items
```

## Step 3: Silver Layer

The data is cleaned and standardized through:

```text
silver_orders
silver_order_items
```

## Step 4: Gold Layer

The incremental fact model processes the new record.

```text
fact_order_items
```

## Step 5: Analytics

The record becomes available for:

```text
Customer Analysis
Product Analysis
Revenue Analysis
Time-Based Analysis
```

---

# 36. Complete Technology Responsibilities

## PostgreSQL

Responsible for:

- Raw data storage.
- Database schemas.
- Analytical tables.
- SQL execution.
- Joins and aggregations.

## dbt Core

Responsible for:

- Data transformations.
- Model dependencies.
- Data lineage.
- Incremental processing.
- Testing.
- Source definitions.
- Documentation generation.

## dbt-postgres

Responsible for connecting dbt Core to PostgreSQL.

## Python

Used to create and manage the local environment required for dbt.

## Git

Used for:

- Version control.
- Tracking project changes.
- Managing source code.

---

# 37. Architecture Benefits

This architecture provides several advantages.

## Clear Separation

Each transformation stage has a defined purpose.

```text
Raw → Bronze → Silver → Gold
```

## Scalability

The architecture can be extended by adding:

```text
More sources
More models
More dimensions
More fact tables
More tests
More analytical datasets
```

## Maintainability

Transformations are separated into small SQL models.

## Testability

dbt tests validate data quality at multiple stages.

## Reusability

The Silver layer provides reusable cleaned datasets.

Macros reduce repeated SQL logic.

## Analytics Optimization

The Gold layer uses a dimensional model optimized for analytical queries.

---

# 38. Future Architecture Improvements

The current architecture can be extended with:

- Additional fact tables.
- Date dimensions.
- Customer segmentation.
- Slowly Changing Dimensions.
- dbt snapshots.
- CI/CD pipelines.
- Cloud data warehouses.
- Apache Airflow orchestration.
- Data observability tools.
- Automated alerts.
- Business intelligence dashboards.

Possible future architecture:

```text
Sources
   │
   ▼
Ingestion
   │
   ▼
Data Warehouse
   │
   ▼
dbt Transformations
   │
   ▼
Data Quality Tests
   │
   ▼
Orchestration
   │
   ▼
BI Dashboard
```

---

# 39. Final Architecture Summary

The complete architecture is:

```text
                         ┌──────────────────────┐
                         │   Source / OLTP Data │
                         │                      │
                         │ Customers            │
                         │ Products             │
                         │ Orders               │
                         │ Order Items          │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │    PostgreSQL RAW    │
                         │                      │
                         │ raw.customers        │
                         │ raw.products         │
                         │ raw.orders           │
                         │ raw.order_items      │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │       BRONZE         │
                         │                      │
                         │ Minimal Cleaning     │
                         │ Type Handling        │
                         │ Audit Columns        │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │       SILVER         │
                         │                      │
                         │ Cleaned Data         │
                         │ Standardized Data    │
                         │ Business Logic       │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │        GOLD          │
                         │                      │
                         │ dim_customers        │
                         │ dim_products         │
                         │                      │
                         │ fact_order_items     │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Analytics & Insights │
                         │                      │
                         │ Customers            │
                         │ Products             │
                         │ Revenue              │
                         │ Time Analysis        │
                         └──────────────────────┘
```

---

# 40. Project Completion Status

The implemented architecture includes:

- PostgreSQL database setup.
- Raw OLTP-style tables.
- Mock e-commerce data.
- dbt project setup.
- dbt source definitions.
- Bronze layer.
- Silver layer.
- Gold layer.
- Star schema.
- Customer dimension.
- Product dimension.
- Order item fact table.
- Incremental fact processing.
- Incremental data simulation.
- Late-arriving historical data simulation.
- Backfill strategy documentation.
- dbt data quality tests.
- Not-null tests.
- Unique tests.
- Relationship tests.
- Custom data test.
- Audit columns.
- Reusable dbt macro.
- Analytical SQL queries.
- End-to-end pipeline validation.
- Successful `dbt build`.

## Final Validation

```text
PASS=113
WARN=0
ERROR=0
SKIP=0
```

The project successfully demonstrates a complete **local E-Commerce Analytics Engineering pipeline** from raw transactional data to analytics-ready dimensional models.
