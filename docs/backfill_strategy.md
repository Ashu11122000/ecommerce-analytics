# Backfill Strategy

## E-Commerce Analytics Engineering Project

---

## Table of Contents

1. [Overview](#1-overview)
2. [What Is a Backfill?](#2-what-is-a-backfill)
3. [Types of Backfill Scenarios](#3-types-of-backfill-scenarios)
4. [Incremental Processing Strategy](#4-incremental-processing-strategy)
5. [Incremental Data Flow](#5-incremental-data-flow)
6. [Why `ingested_at` Is Important](#6-why-ingested_at-is-important)
7. [Backfill Simulation Performed in This Project](#7-backfill-simulation-performed-in-this-project)
8. [Historical Order Inserted into Raw Layer](#8-historical-order-inserted-into-raw-layer)
9. [Historical Order Item Inserted](#9-historical-order-item-inserted)
10. [Verification of Raw Historical Data](#10-verification-of-raw-historical-data)
11. [Running the Incremental Model](#11-running-the-incremental-model)
12. [Verification of Backfilled Record](#12-verification-of-backfilled-record)
13. [Row Count Verification](#13-row-count-verification)
14. [Backfill Result](#14-backfill-result)
15. [Why This Incremental Strategy Works](#15-why-this-incremental-strategy-works)
16. [Normal Incremental Run](#16-normal-incremental-run)
17. [Full Refresh Strategy](#17-full-refresh-strategy)
18. [When to Use a Full Refresh](#18-when-to-use-a-full-refresh)
19. [Failed Pipeline Recovery](#19-failed-pipeline-recovery)
20. [Data Quality Validation After Backfill](#20-data-quality-validation-after-backfill)
21. [Important Validation Queries](#21-important-validation-queries)
22. [Backfill and Dimensional Models](#22-backfill-and-dimensional-models)
23. [Backfill Considerations in Production](#23-backfill-considerations-in-production)
24. [Idempotency Considerations](#24-idempotency-considerations)
25. [Incremental Processing vs Full Refresh](#25-incremental-processing-vs-full-refresh)
26. [Backfill Workflow](#26-backfill-workflow)
27. [Example Backfill Workflow Used in This Project](#27-example-backfill-workflow-used-in-this-project)
28. [Key Learning Outcomes](#28-key-learning-outcomes)
29. [Final Backfill Status](#29-final-backfill-status)
30. [Final Conclusion](#30-final-conclusion)

---

## 1. Overview

This document explains the **backfill strategy** used in the **E-Commerce Analytics Engineering Project**.

A **backfill** is the process of reprocessing historical data that was missing, arrived late, or was not processed correctly during a previous pipeline run.

The project uses:

- **PostgreSQL** for raw data storage.
- **dbt** for data transformations.
- **Bronze, Silver, and Gold** data layers.
- An **incremental fact table** for transactional processing.

The primary incremental model is:

```text
analytics_gold.fact_order_items
```

The project supports both:

- Incremental processing of newly ingested data.
- Backfilling historical or late-arriving data.

---

## 2. What Is a Backfill?

A backfill occurs when data from the past needs to be processed after the normal processing period.

For example:

```text
August 1, 2026
      │
      │ Historical order occurs
      ▼
Data is missing from the pipeline
      │
      │ Later
      ▼
September 4, 2026
      │
      ▼
Historical order is inserted into raw tables
      │
      ▼
dbt processes the newly ingested record
      │
      ▼
Gold fact table receives the historical record
```

The important point is:

> The **business event date** can be old, while the **ingestion timestamp** can be new.

---

## 3. Types of Backfill Scenarios

This project considers several common backfill scenarios.

### 3.1 Historical Missing Data

Historical records may have been missing from the source system.

Example:

```text
Order Date:     2026-08-01
Ingested Date:  2026-09-04
```

The order occurred in August but entered the data warehouse in September.

The pipeline must still process it.

---

### 3.2 Late-Arriving Data

Late-arriving data occurs when the business event happens earlier but reaches the data warehouse later.

Example:

**Order created:**

```text
2026-08-01
```

But the source data is loaded into PostgreSQL on:

```text
2026-09-04
```

The pipeline should identify the record based on its ingestion time rather than ignoring it because the order date is old.

---

### 3.3 Failed Pipeline Run

A pipeline run may fail because of:

- Database connectivity issues.
- Invalid source data.
- dbt execution failures.
- Environment problems.
- Temporary infrastructure issues.

After fixing the issue, the affected data may need to be reprocessed.

---

### 3.4 Logic Changes

Sometimes transformation logic changes.

For example:

**Old logic:**

```text
total_amount = quantity * unit_price
```

This may later be replaced with additional business logic.

When transformation logic changes significantly, previously processed records may need to be rebuilt.

---

### 3.5 Full Historical Reprocessing

Sometimes the entire analytical table must be rebuilt.

Possible reasons include:

- Major transformation changes.
- Incorrect historical data.
- Schema changes.
- Incorrect incremental logic.
- Data corruption.

In this case, a **full refresh** can be performed.

---

## 4. Incremental Processing Strategy

The project uses an incremental strategy for:

```text
analytics_gold.fact_order_items
```

The fact table stores transactional data at the following grain:

> **One row represents one product item within one order.**

The unique identifier is:

```text
order_item_id
```

This identifier allows dbt to identify individual transactional records.

---

## 5. Incremental Data Flow

The incremental processing flow is:

```text
Raw Data
    │
    ▼
raw.orders
raw.order_items
    │
    ▼
Bronze Layer
    │
    ▼
Silver Layer
    │
    ▼
Incremental Gold Fact Model
fact_order_items
    │
    ▼
Only New Records Are Added
```

The model avoids rebuilding the complete fact table during normal incremental runs.

---

## 6. Why `ingested_at` Is Important

The project uses the `ingested_at` timestamp to track when data entered the raw layer.

For example:

### Business Event

```text
order_date
    │
    ▼
2026-08-01
```

### Data Arrival

```text
ingested_at
    │
    ▼
2026-09-04
```

These timestamps serve different purposes:

| Column        | Purpose                                   |
| ------------- | ----------------------------------------- |
| `order_date`  | When the business event occurred          |
| `ingested_at` | When the record entered the data pipeline |

For incremental processing and late-arriving data, the ingestion timestamp is particularly useful.

---

## 7. Backfill Simulation Performed in This Project

A practical backfill simulation was performed as part of this project.

The goal was to verify that the incremental model could process a historical order that was ingested later.

### Step 1: Existing Data Was Verified

The `raw.order_items` table was checked.

Example query:

```sql
SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    ingested_at
FROM raw.order_items
ORDER BY order_item_id
LIMIT 5;
```

The existing records had earlier ingestion timestamps.

---

## 8. Historical Order Inserted into Raw Layer

A new order was inserted with a historical `order_date`.

The order was:

| Column         | Value                 |
| -------------- | --------------------- |
| `order_id`     | `133`                 |
| `customer_id`  | `2`                   |
| `order_date`   | `2026-08-01 10:00:00` |
| `order_status` | `completed`           |

The record was inserted into:

```text
raw.orders
```

The SQL used was:

```sql
INSERT INTO raw.orders (
    order_id,
    customer_id,
    order_date,
    order_status
)
VALUES (
    133,
    2,
    '2026-08-01 10:00:00',
    'completed'
);
```

The result was:

```text
INSERT 0 1
```

---

## 9. Historical Order Item Inserted

A related order item was inserted into:

```text
raw.order_items
```

The inserted record contained:

| Column          | Value     |
| --------------- | --------- |
| `order_item_id` | `1063`    |
| `order_id`      | `133`     |
| `product_id`    | `2`       |
| `quantity`      | `1`       |
| `unit_price`    | `2499.00` |

The SQL used was:

```sql
INSERT INTO raw.order_items (
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price
)
VALUES (
    1063,
    133,
    2,
    1,
    2499.00
);
```

The result was:

```text
INSERT 0 1
```

---

## 10. Verification of Raw Historical Data

The inserted order was verified.

```sql
SELECT *
FROM raw.orders
WHERE order_id = 133;
```

The result showed:

```text
order_id = 133
order_date = 2026-08-01 10:00:00
ingested_at = 2026-09-04
```

This demonstrates a **late-arriving historical record**.

The business event happened on:

```text
2026-08-01
```

But the record entered the pipeline on:

```text
2026-09-04
```

---

## 11. Running the Incremental Model

After inserting the historical data, the incremental model was executed.

Command:

```bash
dbt run --select fact_order_items
```

The run completed successfully.

The output indicated:

```text
PASS=1
WARN=0
ERROR=0
```

The incremental run inserted the new historical record into the Gold fact table.

---

## 12. Verification of Backfilled Record

The Gold fact table was queried.

```sql
SELECT
    order_item_id,
    order_id,
    customer_id,
    product_id,
    order_date,
    quantity,
    unit_price,
    total_amount,
    ingested_at
FROM analytics_gold.fact_order_items
WHERE order_item_id = 1063;
```

The result confirmed:

| Column          | Value                 |
| --------------- | --------------------- |
| `order_item_id` | `1063`                |
| `order_id`      | `133`                 |
| `customer_id`   | `2`                   |
| `product_id`    | `2`                   |
| `order_date`    | `2026-08-01 10:00:00` |
| `quantity`      | `1`                   |
| `unit_price`    | `2499.00`             |
| `total_amount`  | `2499.00`             |
| `ingested_at`   | `2026-09-04`          |

This proves that the historical record was successfully processed.

---

## 13. Row Count Verification

Before the backfill simulation, the fact table contained:

```text
62 rows
```

After processing the historical order item, the fact table contained:

```text
63 rows
```

The verification query was:

```sql
SELECT COUNT(*) AS row_count
FROM analytics_gold.fact_order_items;
```

Result:

```text
row_count
---------
63
```

This confirmed that the new record was successfully added without rebuilding all historical records.

---

## 14. Backfill Result

The backfill simulation demonstrated the following:

```text
Historical Order
2026-08-01
       │
       │ Inserted later
       ▼
Raw Layer
2026-09-04 ingestion
       │
       ▼
dbt Incremental Run
       │
       ▼
Bronze Layer
       │
       ▼
Silver Layer
       │
       ▼
Gold Fact Table
       │
       ▼
Historical Record Successfully Added
```

### Result

**The backfill was successful.**

---

## 15. Why This Incremental Strategy Works

The strategy works because the pipeline distinguishes between:

- **Business Event Time**
- **Data Ingestion Time**

A historical record does not need to have a recent `order_date`.

Instead, it can still be processed when it enters the pipeline later.

Example:

```text
order_date
2026-08-01
     │
     │ Historical business event
     ▼

ingested_at
2026-09-04
     │
     │ New pipeline ingestion
     ▼

Incremental Processing
     │
     ▼

Gold Table Updated
```

---

## 16. Normal Incremental Run

For normal processing of new data, the following command can be used:

```bash
dbt run
```

Alternatively, the specific incremental fact model can be run:

```bash
dbt run --select fact_order_items
```

This is useful when testing or processing only the transactional fact model.

---

## 17. Full Refresh Strategy

If a complete rebuild is required, dbt supports a full refresh.

Example:

```bash
dbt run --full-refresh
```

For the specific fact model:

```bash
dbt run --select fact_order_items --full-refresh
```

A full refresh rebuilds the incremental table from the complete upstream dataset.

Conceptually:

```text
Existing Gold Fact Table
        │
        ▼
Dropped / Rebuilt
        │
        ▼
All Historical Source Data
        │
        ▼
Complete Transformation
        │
        ▼
New Gold Fact Table
```

---

## 18. When to Use a Full Refresh

A full refresh may be appropriate when:

- The incremental logic has changed significantly.
- Historical records were processed incorrectly.
- Transformation logic has changed.
- Important columns were added or removed.
- Data corruption occurred.
- A complete reconciliation is required.

However, full refreshes can be expensive for large production datasets.

For this small local project, they are practical.

---

## 19. Failed Pipeline Recovery

If a dbt run fails, the following process can be used.

### Step 1: Identify the Failure

Run:

```bash
dbt build
```

Review the error output.

Possible failures include:

- SQL syntax errors.
- Missing source tables.
- Failed data tests.
- Relationship issues.
- Invalid transformations.

---

### Step 2: Fix the Problem

Examples:

- Fix SQL logic.
- Fix source data.
- Fix schema definitions.
- Fix test configuration.
- Fix database connectivity.

---

### Step 3: Re-run the Affected Model

For example:

```bash
dbt run --select fact_order_items
```

Or rebuild the affected model and its downstream dependencies:

```bash
dbt build --select fact_order_items+
```

---

## 20. Data Quality Validation After Backfill

After a backfill, data quality checks should be executed.

The project uses:

```bash
dbt build
```

This command performs:

```text
Model Execution
+
Data Testing
```

The complete project build was successfully executed.

Result:

```text
PASS=113
WARN=0
ERROR=0
SKIP=0
```

This confirmed that:

- Bronze models were successfully built.
- Silver models were successfully built.
- Gold models were successfully built.
- Data quality tests passed.
- Relationship tests passed.
- Custom tests passed.
- The incremental model executed correctly.

---

## 21. Important Validation Queries

After a backfill, the following checks can be performed.

### Check the Backfilled Record

```sql
SELECT *
FROM analytics_gold.fact_order_items
WHERE order_item_id = 1063;
```

---

### Check Row Count

```sql
SELECT COUNT(*)
FROM analytics_gold.fact_order_items;
```

---

### Check for Duplicate Order Items

```sql
SELECT
    order_item_id,
    COUNT(*)
FROM analytics_gold.fact_order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;
```

Expected result:

```text
0 rows
```

---

### Check Customer Relationships

```sql
SELECT
    f.customer_id
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_customers AS c
    ON f.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
```

Expected result:

```text
0 rows
```

---

### Check Product Relationships

```sql
SELECT
    f.product_id
FROM analytics_gold.fact_order_items AS f
LEFT JOIN analytics_gold.dim_products AS p
    ON f.product_id = p.product_id
WHERE p.product_id IS NULL;
```

Expected result:

```text
0 rows
```

---

## 22. Backfill and Dimensional Models

This project contains the following Gold layer models:

```text
analytics_gold.dim_customers
analytics_gold.dim_products
analytics_gold.fact_order_items
```

The dimensions contain descriptive entities.

The fact table contains transactional events.

During backfills, it is important to ensure that:

```text
Customer Dimension
        │
        │ customer_id exists
        ▼
Fact Table
        │
        │ product_id exists
        ▼
Product Dimension
```

This prevents orphaned foreign key references.

---

## 23. Backfill Considerations in Production

For a larger production data pipeline, backfills would require additional controls.

Examples include:

- Date-range parameters.
- Partition-based processing.
- Incremental watermarks.
- Idempotent loading.
- Logging.
- Monitoring.
- Retry mechanisms.
- Data reconciliation.
- Backup strategies.

### Example Conceptual Date-Range Backfill

```text
Start Date
2026-08-01
       │
       ▼
Process Historical Data
       │
       ▼
End Date
2026-08-31
```

A production dbt project might use variables to control this process.

Example conceptually:

```bash
dbt run --vars '{start_date: "2026-08-01", end_date: "2026-08-31"}'
```

The exact implementation would depend on the incremental model logic and warehouse architecture.

---

## 24. Idempotency Considerations

A good backfill process should avoid creating duplicate records.

In this project, the key fact table identifier is:

```text
order_item_id
```

The intended principle is:

> Reprocessing the same source data should not create duplicate analytical records.

This is especially important for:

- Late-arriving data.
- Retry operations.
- Failed pipeline recovery.
- Historical backfills.

---

## 25. Incremental Processing vs Full Refresh

| Feature                                  | Incremental Run | Full Refresh  |
| ---------------------------------------- | --------------- | ------------- |
| Processes new records                    | Yes             | Yes           |
| Rebuilds entire table                    | No              | Yes           |
| Faster for large datasets                | Yes             | No            |
| Suitable for daily loads                 | Yes             | Less suitable |
| Suitable for major logic changes         | Sometimes       | Yes           |
| Suitable for complete historical rebuild | No              | Yes           |

---

## 26. Backfill Workflow

The recommended workflow for a historical backfill is:

```text
1. Identify Missing Historical Data
            │
            ▼
2. Load Data into Raw Tables
            │
            ▼
3. Verify Raw Data
            │
            ▼
4. Run Relevant dbt Models
            │
            ▼
5. Validate Gold Tables
            │
            ▼
6. Run dbt Tests
            │
            ▼
7. Verify Analytical Results
```

---

## 27. Example Backfill Workflow Used in This Project

The practical workflow was:

### Step 1

Insert a historical order:

```text
order_date = 2026-08-01
```

### Step 2

Allow PostgreSQL to record the current ingestion timestamp:

```text
ingested_at = 2026-09-04
```

### Step 3

Insert the related order item.

### Step 4

Run:

```bash
dbt run --select fact_order_items
```

### Step 5

Verify:

```text
order_item_id = 1063
```

in:

```text
analytics_gold.fact_order_items
```

### Step 6

Confirm the row count increased:

```text
62
```

to:

```text
63
```

### Step 7

Run the complete project validation:

```bash
dbt build
```

### Step 8

Confirm:

```text
PASS=113
WARN=0
ERROR=0
```

---

## 28. Key Learning Outcomes

The backfill implementation demonstrates understanding of:

- Historical data processing.
- Late-arriving data.
- Incremental models.
- Data ingestion timestamps.
- Business event timestamps.
- Data warehouse recovery.
- Full refresh strategies.
- Data validation.
- Idempotency concepts.
- Fact table processing.
- Dimensional modeling.
- dbt model execution.
- dbt data testing.


---

## 30. Final Conclusion

The **E-Commerce Analytics Engineering Project** successfully demonstrates a practical backfill scenario.

A historical order with:

```text
order_date = 2026-08-01
```

was inserted into the raw PostgreSQL layer on:

```text
2026-09-04
```

The dbt incremental model successfully processed the late-arriving record and added it to:

```text
analytics_gold.fact_order_items
```

The fact table row count increased from:

```text
62
```

to:

```text
63
```

The historical record retained both:

- Its original business event date.
- Its later ingestion timestamp.

Finally, the complete dbt project was validated successfully using:

```bash
dbt build
```

with the result:

```text
PASS=113
WARN=0
ERROR=0
SKIP=0
```

This confirms that the project supports:

- Incremental processing.
- Late-arriving historical data.
- Backfill simulation.
- Data quality validation.
- Complete analytical pipeline testing.

---

