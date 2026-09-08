# Data Model

## E-Commerce Analytics Engineering Project

---

## Table of Contents

- [Overview](#1-overview)
- [Data Modeling Approach](#2-data-modeling-approach)
- [OLTP Source Data Model](#3-oltp-source-data-model)
- [Medallion Transformation Layers](#6-medallion-transformation-layers)
- [Gold Layer and Dimensional Modeling](#9-gold-layer-data-model)
- [Star Schema](#18-star-schema)
- [Keys and Relationships](#20-primary-keys-and-foreign-keys)
- [Data Quality Constraints](#22-data-quality-constraints)
- [Incremental Processing and Backfills](#25-incremental-fact-table)
- [Analytical Queries](#28-example-analytical-queries)
- [Data Lineage](#32-data-lineage)
- [Model Summary](#33-model-summary)
- [Final Conclusion](#36-final-conclusion)

---

## 1. Overview

This document describes the **data model** used in the E-Commerce Analytics Engineering project.

The project transforms OLTP-style e-commerce data stored in PostgreSQL through a **Bronze → Silver → Gold** architecture.

The final Gold layer uses **dimensional modeling** and follows a simplified **Star Schema** design.

The Gold layer contains:

```
Dimensions
│
├── dim_customers
│
└── dim_products

Facts
│
└── fact_order_items
```

The purpose of this model is to make the data easier and more efficient to use for analytical queries.

---

## 2. Data Modeling Approach

The project starts with a normalized, transactional-style raw data model.

The raw source tables are:

```
raw.customers
raw.products
raw.orders
raw.order_items
```

These tables are transformed using dbt into multiple layers:

```
Raw Layer
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
    ▼
Analytics
```

The Gold layer reorganizes the cleaned transactional data into an analytics-friendly dimensional model.

---

## 3. OLTP Source Data Model

The raw data represents a simplified e-commerce transactional system.

The main entities are:

```
Customers
    │
    │ customer_id
    ▼
Orders
    │
    │ order_id
    ▼
Order Items
    │
    │ product_id
    ▼
Products
```

The relationships are:

```
One Customer
      │
      │ can place
      ▼
Many Orders


One Order
      │
      │ can contain
      ▼
Many Order Items


One Product
      │
      │ can appear in
      ▼
Many Order Items
```

---

## 4. Raw Source Tables

### 4.1 `raw.customers`

This table stores customer information.

Main columns include:

```
customer_id
customer_name
email
city
signup_date
ingested_at
```

### Primary Identifier

```
customer_id
```

Each row represents:

> **One customer.**

---

### 4.2 `raw.products`

This table stores product information.

Main columns include:

```
product_id
product_name
category
price
ingested_at
```

### Primary Identifier

```
product_id
```

Each row represents:

> **One product.**

---

### 4.3 `raw.orders`

This table stores order-level information.

Main columns include:

```
order_id
customer_id
order_date
order_status
ingested_at
```

### Primary Identifier

```
order_id
```

Each row represents:

> **One customer order.**

---

### 4.4 `raw.order_items`

This table stores individual products within orders.

Main columns include:

```
order_item_id
order_id
product_id
quantity
unit_price
ingested_at
```

### Primary Identifier

```
order_item_id
```

Each row represents:

> **One product item within one order.**

---

## 5. Raw Entity Relationships

The raw transactional model can be represented as:

```
┌──────────────────────┐
│      customers       │
│──────────────────────│
│ customer_id (PK)     │
│ customer_name        │
│ email                │
│ city                 │
│ signup_date          │
└──────────┬───────────┘
           │
           │ customer_id
           ▼
┌──────────────────────┐
│        orders        │
│──────────────────────│
│ order_id (PK)        │
│ customer_id (FK)     │
│ order_date           │
│ order_status         │
└──────────┬───────────┘
           │
           │ order_id
           ▼
┌──────────────────────┐
│     order_items      │
│──────────────────────│
│ order_item_id (PK)   │
│ order_id (FK)        │
│ product_id (FK)      │
│ quantity             │
│ unit_price           │
└──────────┬───────────┘
           │
           │ product_id
           ▼
┌──────────────────────┐
│       products       │
│──────────────────────│
│ product_id (PK)      │
│ product_name         │
│ category             │
│ price                │
└──────────────────────┘
```

This structure is useful for transactional operations but is not the final analytical model.

---

## 6. Medallion Transformation Layers

Before reaching the final dimensional model, the data moves through three transformation layers.

```
RAW
 │
 ▼
BRONZE
 │
 ▼
SILVER
 │
 ▼
GOLD
```

---

## 7. Bronze Layer Data Model

The Bronze layer is the first dbt transformation layer.

Models include:

```
bronze_customers
bronze_products
bronze_orders
bronze_order_items
```

The Bronze layer performs minimal transformations.

Responsibilities include:

- Reading data from dbt sources.
- Standardizing basic column handling.
- Applying basic type handling where required.
- Preserving the original source structure.
- Adding audit metadata through reusable transformation logic.

The Bronze layer remains close to the raw source data.

---

## 8. Silver Layer Data Model

The Silver layer contains cleaned and standardized datasets.

Models include:

```
silver_customers
silver_products
silver_orders
silver_order_items
```

The Silver layer is responsible for:

- Cleaning data.
- Standardizing values.
- Preparing reusable datasets.
- Applying transformation logic.
- Supporting relationships between entities.
- Providing trusted inputs for the Gold layer.

The Silver layer acts as the primary cleaned transformation layer.

---

## 9. Gold Layer Data Model

The Gold layer contains analytics-ready tables.

The Gold models are:

```
analytics_gold.dim_customers

analytics_gold.dim_products

analytics_gold.fact_order_items
```

The Gold layer follows a dimensional modeling approach.

---

## 10. What Is Dimensional Modeling?

Dimensional modeling is a method of organizing data for analytical queries.

It separates data into:

```
Dimensions
```

and:

```
Facts
```

---

## Dimensions

Dimension tables contain descriptive information about business entities.

Examples include:

```
Customers
Products
Dates
Locations
```

Dimensions answer questions such as:

```
Who?

What?

Where?

Which category?
```

---

## Facts

Fact tables contain measurable business events.

Examples include:

```
Sales
Orders
Revenue
Quantity
Transactions
```

Facts answer questions such as:

```
How many?

How much?

How often?
```

---

## 11. Gold Dimension: `dim_customers`

The customer dimension stores descriptive information about customers.

Table:

```
analytics_gold.dim_customers
```

---

### 11.1 Columns

The main columns are:

```
customer_id
customer_name
email
city
signup_date
```

The model also contains audit and transformation metadata generated through the pipeline.

These include fields such as:

```
ingested_at
loaded_at
transformed_at
modeled_at
```

---

### 11.2 Primary Key

The primary business identifier is:

```
customer_id
```

Each value should uniquely identify one customer.

---

### 11.3 Table Grain

The grain of `dim_customers` is:

> **One row represents one customer.**

Example:

| customer_id | customer_name | city      |
| ----------- | ------------- | --------- |
| 1           | Aarav Sharma  | Delhi     |
| 2           | Priya Verma   | Mumbai    |
| 3           | Rahul Kumar   | Bengaluru |

---

## 12. Gold Dimension: `dim_products`

The product dimension stores descriptive information about products.

Table:

```
analytics_gold.dim_products
```

---

### 12.1 Columns

The main columns are:

```
product_id
product_name
category
price
```

The model also contains pipeline audit metadata.

These include:

```
ingested_at
loaded_at
transformed_at
modeled_at
```

---

### 12.2 Primary Key

The primary business identifier is:

```
product_id
```

Each product should appear only once in the dimension.

---

### 12.3 Table Grain

The grain of `dim_products` is:

> **One row represents one product.**

Example:

| product_id | product_name        | category    |   price |
| ---------- | ------------------- | ----------- | ------: |
| 1          | Wireless Mouse      | Electronics |  799.00 |
| 2          | Mechanical Keyboard | Electronics | 2499.00 |
| 3          | USB-C Charger       | Electronics | 1299.00 |

---

## 13. Gold Fact Table: `fact_order_items`

The main analytical fact table is:

```
analytics_gold.fact_order_items
```

This table stores transactional sales events.

---

## 14. Fact Table Columns

The main analytical columns are:

```
order_item_id
order_id
customer_id
product_id
order_date
quantity
unit_price
total_amount
```

The model also contains audit and transformation metadata:

```
ingested_at
loaded_at
transformed_at
modeled_at
```

---

## 15. Fact Table Grain

The grain of the fact table is one of the most important design decisions.

The grain is:

> **One row represents one product item within one order.**

For example:

```
Order 101

Customer: 1

Products:

Wireless Mouse
Quantity: 2

Mechanical Keyboard
Quantity: 3
```

The fact table contains two rows:

| order_item_id | order_id | product_id | quantity |
| ------------- | -------: | ---------: | -------: |
| 1001          |      101 |          1 |        2 |
| 1002          |      101 |         13 |        3 |

Even though both products belong to the same order, they are separate fact records.

---

## 16. Why the Grain Is Important

The table grain determines what calculations are valid.

Because the fact table is at the order-item level, it can calculate:

```
Revenue by product

Revenue by customer

Quantity sold

Product sales

Category sales

Daily revenue
```

For example:

```
SUM(total_amount)
```

calculates total revenue.

And:

```
SUM(quantity)
```

calculates total units sold.

---

## 17. Fact Table Measures

The fact table contains numerical measures.

---

### 17.1 Quantity

```
quantity
```

Represents the number of units purchased.

Example:

```
quantity = 2
```

means two units of the product were purchased.

---

### 17.2 Unit Price

```
unit_price
```

Represents the price of one unit at the time of the order.

Example:

```
unit_price = 799.00
```

---

### 17.3 Total Amount

```
total_amount
```

Represents the total value of the order item.

The calculation is:

```
total_amount

=

quantity × unit_price
```

Example:

```
quantity = 2

unit_price = 799.00


2 × 799.00

=

1598.00
```

Therefore:

```
total_amount = 1598.00
```

---

## 18. Star Schema

The final Gold layer follows a simplified Star Schema.

```
                   ┌─────────────────────────┐
                   │      dim_customers      │
                   │─────────────────────────│
                   │ customer_id             │
                   │ customer_name           │
                   │ email                   │
                   │ city                    │
                   │ signup_date             │
                   └────────────┬────────────┘
                                │
                                │ customer_id
                                │
                                ▼
                 ┌──────────────────────────────┐
                 │       fact_order_items       │
                 │──────────────────────────────│
                 │ order_item_id                │
                 │ order_id                     │
                 │ customer_id                  │
                 │ product_id                   │
                 │ order_date                   │
                 │ quantity                     │
                 │ unit_price                   │
                 │ total_amount                 │
                 └──────────────┬───────────────┘
                                │
                                │ product_id
                                │
                                ▼
                   ┌─────────────────────────┐
                   │      dim_products       │
                   │─────────────────────────│
                   │ product_id              │
                   │ product_name            │
                   │ category                │
                   │ price                   │
                   └─────────────────────────┘
```

---

## 19. Star Schema Relationships

The fact table connects to the dimensions through business keys.

---

## Customer Relationship

```
fact_order_items.customer_id

            │
            │
            ▼

dim_customers.customer_id
```

Relationship:

```
Many Fact Records
        │
        ▼
One Customer
```

One customer can have many order items.

---

## Product Relationship

```
fact_order_items.product_id

            │
            │
            ▼

dim_products.product_id
```

Relationship:

```
Many Fact Records
        │
        ▼
One Product
```

One product can appear in many order items.

---

## 20. Primary Keys and Foreign Keys

The dimensional model uses logical primary and foreign key relationships.

## Dimension Keys

```
dim_customers

customer_id
dim_products

product_id
```

---

## Fact Table Identifier

```
fact_order_items

order_item_id
```

The `order_item_id` uniquely identifies each row in the fact table.

---

## Foreign Keys

The fact table contains:

```
customer_id
```

which references:

```
dim_customers.customer_id
```

It also contains:

```
product_id
```

which references:

```
dim_products.product_id
```

---

## 21. Relationship Testing

dbt relationship tests are used to validate important relationships.

For example:

```
fact_order_items.customer_id
```

should exist in:

```
dim_customers.customer_id
```

Conceptually:

```
Fact Table

customer_id = 1

       │
       ▼

Customer Dimension

customer_id = 1

       ✓
```

If a fact record references a customer that does not exist, the relationship test should fail.

The same approach is used for products.

---

## 22. Data Quality Constraints

The project uses dbt tests to validate important data model assumptions.

Examples include:

---

## Not Null Tests

Important identifiers should not be null.

Examples:

```
customer_id
product_id
order_id
order_item_id
```

---

## Unique Tests

Primary business identifiers should be unique where appropriate.

Examples:

```
dim_customers.customer_id

dim_products.product_id

fact_order_items.order_item_id
```

---

## Relationship Tests

Relationships are validated between:

```
fact_order_items.customer_id

        ↓

dim_customers.customer_id
```

and:

```
fact_order_items.product_id

        ↓

dim_products.product_id
```

---

## Custom Positive Amount Test

The project includes a custom test:

```
test_positive_order_amount.sql
```

This validates that order amounts are positive.

Conceptually:

```
total_amount > 0
```

---

## 23. Audit Columns

The project uses audit metadata throughout the transformation pipeline.

Depending on the model layer, audit fields include:

```
ingested_at
loaded_at
transformed_at
modeled_at
```

These timestamps help track the lifecycle of data.

---

## `ingested_at`

Represents when the record entered the raw data layer.

Example:

```
Business event:

2026-08-01


Data ingestion:

2026-09-04
```

The `ingested_at` value helps identify when the pipeline received the record.

---

## `loaded_at`

Represents when the data was loaded or processed into the transformation pipeline layer.

---

## `transformed_at`

Represents when the Silver transformation logic processed the record.

---

## `modeled_at`

Represents when the Gold dimensional model processed the record.

---

## 24. Business Time vs Pipeline Time

The project distinguishes between business event timestamps and pipeline processing timestamps.

Example:

```
Business Event Time

order_date

2026-08-01
```

and:

```
Pipeline Ingestion Time

ingested_at

2026-09-04
```

These timestamps answer different questions.

| Timestamp        | Meaning                                                  |
| ---------------- | -------------------------------------------------------- |
| `order_date`     | When the customer order occurred                         |
| `ingested_at`    | When the source record entered the pipeline              |
| `loaded_at`      | When the record was loaded into the transformation layer |
| `transformed_at` | When the Silver transformation processed the data        |
| `modeled_at`     | When the Gold model processed the data                   |

This distinction is important for incremental processing and backfills.

---

## 25. Incremental Fact Table

The `fact_order_items` model uses an incremental materialization strategy.

The purpose is to avoid rebuilding the entire transactional fact table every time new data arrives.

Conceptually:

```
Existing Fact Table

        │
        │
        ▼

New Raw Records

        │
        ▼

Incremental dbt Run

        │
        ▼

Only New Records Processed

        │
        ▼

Updated Fact Table
```

The primary unique identifier is:

```
order_item_id
```

---

## 26. Late-Arriving Historical Data

The data model supports late-arriving records.

A practical example was tested in the project.

A historical order was created with:

```
order_date

2026-08-01 10:00:00
```

but entered the raw pipeline later with an ingestion timestamp on:

```
2026-09-04
```

The order item was:

```
order_item_id = 1063

order_id = 133

product_id = 2

quantity = 1

unit_price = 2499.00
```

After running the incremental fact model, the record was successfully added to:

```
analytics_gold.fact_order_items
```

The resulting fact record contained:

```
total_amount = 2499.00
```

This demonstrates that the model can preserve the historical business date while processing newly ingested data.

---

## 27. Current Gold Layer Record Counts

After the implemented transformations and backfill simulation, the Gold layer contains:

| Table                             | Row Count |
| --------------------------------- | --------: |
| `analytics_gold.dim_customers`    |        15 |
| `analytics_gold.dim_products`     |        15 |
| `analytics_gold.fact_order_items` |        63 |

These tables represent the final analytics-ready data model for the current project dataset.

---

## 28. Example Analytical Queries

The dimensional model supports business analysis using joins and aggregations.

---

### 28.1 Customer Sales Analysis

Example:

```
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

This query answers:

```
Which customers generated the most revenue?
```

---

## 29. Product Revenue Analysis

Example:

```
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

This query answers:

```
Which products generated the most revenue?
```

---

## 30. Daily Sales Analysis

Example:

```
SELECT
    DATE(order_date) AS order_day,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS total_items_sold,
    SUM(total_amount) AS total_revenue
FROM analytics_gold.fact_order_items
GROUP BY DATE(order_date)
ORDER BY order_day;
```

This query answers:

```
How did orders and revenue change over time?
```

---

## 31. Why the Gold Layer Is Analytics-Friendly

The Gold layer simplifies analytical queries.

Instead of joining multiple normalized transactional tables every time, analysts can use:

```
fact_order_items
```

with:

```
dim_customers

dim_products
```

This provides a clear separation between:

```
Descriptive Data
```

and:

```
Transactional Measures
```

---

## 32. Data Lineage

The data lineage for each Gold model can be represented as follows.

---

## Customer Dimension Lineage

```
raw.customers
      │
      ▼
bronze_customers
      │
      ▼
silver_customers
      │
      ▼
dim_customers
```

---

## Product Dimension Lineage

```
raw.products
      │
      ▼
bronze_products
      │
      ▼
silver_products
      │
      ▼
dim_products
```

---

## Fact Table Lineage

```
raw.orders
      │
      ▼
bronze_orders
      │
      ▼
silver_orders
      │
      │
      ├──────────────────┐
      │                  │
      ▼                  │
                      JOIN
                        │
                        ▼
raw.order_items          │
      │                  │
      ▼                  │
bronze_order_items       │
      │                  │
      ▼                  │
silver_order_items ──────┘
                        │
                        ▼
                fact_order_items
```

The fact model combines order-level information with order-item-level information.

---

## 33. Model Summary

## Raw Layer

| Table             | Grain                                    |
| ----------------- | ---------------------------------------- |
| `raw.customers`   | One row per customer                     |
| `raw.products`    | One row per product                      |
| `raw.orders`      | One row per order                        |
| `raw.order_items` | One row per product item within an order |

---

## Bronze Layer

| Model                | Purpose                               |
| -------------------- | ------------------------------------- |
| `bronze_customers`   | Minimal transformation of customers   |
| `bronze_products`    | Minimal transformation of products    |
| `bronze_orders`      | Minimal transformation of orders      |
| `bronze_order_items` | Minimal transformation of order items |

---

## Silver Layer

| Model                | Purpose                 |
| -------------------- | ----------------------- |
| `silver_customers`   | Cleaned customer data   |
| `silver_products`    | Cleaned product data    |
| `silver_orders`      | Cleaned order data      |
| `silver_order_items` | Cleaned order item data |

---

## Gold Layer

| Model              | Type      | Grain                                     |
| ------------------ | --------- | ----------------------------------------- |
| `dim_customers`    | Dimension | One row per customer                      |
| `dim_products`     | Dimension | One row per product                       |
| `fact_order_items` | Fact      | One row per product item within one order |

---

## 34. Final Star Schema Summary

```
                         DIMENSION
                    dim_customers
                         │
                         │
                         │ customer_id
                         │
                         ▼

              ┌─────────────────────────┐
              │                         │
              │   fact_order_items      │
              │                         │
              │   Measures:             │
              │                         │
              │   quantity              │
              │   unit_price            │
              │   total_amount          │
              │                         │
              └────────────┬────────────┘
                           │
                           │ product_id
                           │
                           ▼

                         DIMENSION
                    dim_products
```

---

## 35. Key Data Modeling Concepts Demonstrated

This project demonstrates the following concepts:

- OLTP-style transactional modeling.
- Analytical data modeling.
- Dimensional modeling.
- Fact tables.
- Dimension tables.
- Table grain.
- Star schema design.
- Primary keys.
- Foreign keys.
- One-to-many relationships.
- Fact-to-dimension relationships.
- Data lineage.
- Medallion architecture.
- Bronze, Silver, and Gold layers.
- Data quality testing.
- Relationship testing.
- Incremental processing.
- Late-arriving data.
- Historical backfills.
- Audit columns.
- Business timestamps.
- Pipeline timestamps.
- Analytical SQL queries.

---

## 36. Final Conclusion

The E-Commerce Analytics Engineering project transforms normalized OLTP-style e-commerce data into an analytics-ready dimensional model.

The final Gold layer contains:

```
analytics_gold.dim_customers

analytics_gold.dim_products

analytics_gold.fact_order_items
```

The model follows a simplified Star Schema where:

- `dim_customers` provides descriptive customer information.
- `dim_products` provides descriptive product information.
- `fact_order_items` stores transactional sales events and measurable business metrics.

The fact table operates at the grain:

> **One row represents one product item within one order.**

This design supports analytical queries involving:

- Customer sales.
- Product performance.
- Revenue analysis.
- Quantity analysis.
- Order analysis.
- Category performance.
- Time-based trends.

The model is supported by dbt transformations, automated data quality tests, incremental processing, audit metadata, and a tested late-arriving historical data backfill scenario.

The complete pipeline was successfully validated using:

```
dbt build
```

with the final result:

```
PASS=113
WARN=0
ERROR=0
SKIP=0
```

This confirms that the implemented data model and its transformation pipeline are functioning successfully for the current project dataset.
