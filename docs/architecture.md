# E-Commerce Analytics Engineering Project Architecture

---

## 1. Overview

This document describes the architecture of the E-Commerce Analytics Engineering project: a local analytics engineering pipeline that transforms mock e-commerce transactional data into analytics-ready datasets and dashboards.

The implemented workflow uses PostgreSQL for storage, dbt Core with the PostgreSQL adapter for transformations, SQL for analysis and validation, Python for the local environment and mock-data generation, Git for version control, and Power BI for dashboarding.

The logical pipeline follows a medallion-style ELT design:

```text
Mock / operational-style data
          |
          v
     Data ingestion
          |
          v
 PostgreSQL raw schema
          |
          v
      dbt sources
          |
          v
    Bronze models
          |
          v
    Silver models
          |
          v
 Gold facts and dimensions
          |
          v
 Semantic definitions + SQL
          |
          v
 Leadership, Operations, and Data Quality / Forecasting dashboards
```

**Important:** this is a local learning and evaluation project using generated/mock data, not a production e-commerce platform. Any historical row counts, metric values, and successful test totals documented below are snapshots from prior runs. Re-run the relevant SQL/dbt commands before presenting them as current results.

---

## 2. Architecture goals and principles

The architecture is designed to demonstrate:

- Separation between raw data, cleaned transformations, and reporting models.
- ELT: load data into PostgreSQL first, then transform it with dbt.
- Modular SQL models and explicit model dependencies using `source()` and `ref()`.
- Dimensional modeling with documented fact-table grain.
- Reusable and consistently defined metrics.
- Data-quality checks and audit metadata.
- Incremental processing, including a simulated late-arriving historical record.
- SQL traceability for dashboard visuals.
- Documentation of assumptions, limitations, and risks.
- A path toward automated validation through CI.

---

### 2.1 ELT responsibilities

| Stage              | Responsibility                                                      | Main technology         |
| ------------------ | ------------------------------------------------------------------- | ----------------------- |
| Extract / generate | Create mock transactional records that represent source-system data | Python                  |
| Load               | Insert or load records into PostgreSQL raw tables                   | Python / SQL            |
| Transform          | Build Bronze, Silver, and Gold models                               | dbt Core + dbt-postgres |
| Validate           | Run dbt tests and SQL reconciliation checks                         | dbt / PostgreSQL        |
| Analyze            | Calculate business metrics and time-based comparisons               | SQL / dbt analyses      |
| Present            | Explore reporting metrics through dashboards                        | Power BI                |
| Version            | Track code, SQL, documentation, and configuration                   | Git                     |

---

## 3. High-level architecture

```text
+-------------------------------+
| Mock e-commerce data generator|
| Customers, products, orders,   |
| order items, payments, returns,|
| and shipment-related records   |
+---------------+---------------+
                |
                v
+-------------------------------+
| PostgreSQL: ecommerce_analytics|
|                               |
| raw schema                    |
| Source / ingested tables      |
+---------------+---------------+
                |
                | dbt source()
                v
+-------------------------------+
| Bronze models                 |
| Minimal transformations       |
| Basic type handling / audit   |
+---------------+---------------+
                |
                | dbt ref()
                v
+-------------------------------+
| Silver models                 |
| Cleaning and standardization  |
| Business-rule preparation     |
+---------------+---------------+
                |
                | dbt ref()
                v
+-----------------------------------------------+
| Gold reporting layer                          |
| Dimensions: customers, products, date          |
| Facts: order items, payments, returns,         |
|        shipments                               |
+----------------------+------------------------+
                       |
                       v
+-----------------------------------------------+
| Analytics and semantic definitions            |
| Metric catalog, grain, join rules, validation  |
| SQL analyses and dashboard queries             |
+----------------------+------------------------+
                       |
          +------------+-------------+
          |            |             |
          v            v             v
+---------------+ +---------------+ +------------------+
| Leadership    | | Operations    | | Data Quality and |
| dashboard     | | dashboard     | | Forecasting view |
+---------------+ +---------------+ +------------------+
```

The diagram represents the intended logical flow. Physical schema names and the exact set of models should always be confirmed from `ecommerce_dbt/dbt_project.yml`, model configurations, and the current PostgreSQL database.

---

## 4. PostgreSQL architecture

PostgreSQL is the local database and analytical storage environment. The project database is named `ecommerce_analytics`.

The logical schema organization is:

```text
ecommerce_analytics
├── raw
├── analytics_bronze
├── analytics_silver
└── analytics_gold
```

These schema names reflect the project configuration and earlier runs. dbt schema generation can vary according to the `generate_schema_name` macro and model configuration. Verify the actual physical schema names in PostgreSQL rather than assuming that a folder name equals a database schema.

### 4.1 Raw schema

The `raw` schema holds the source-style records before downstream dbt transformations. The initial source set includes:

- `raw.customers`
- `raw.products`
- `raw.orders`
- `raw.order_items`

The broader reporting work also includes payment, return, and shipment-related entities. The exact raw table names and columns must match the current DDL and dbt source definitions.

The raw layer should preserve source values as faithfully as practical. Corrections and business rules should normally be implemented downstream so that the original values remain available for reconciliation and auditing.

### 4.2 Typical entity relationships

```text
customers
   | 1-to-many
   v
orders
   | 1-to-many
   v
order_items
   | many-to-1
   v
products

orders / order items
   |
   +---- payments
   +---- returns
   +---- shipments
```

The relationship diagram is conceptual. Actual cardinality depends on the source model: for example, an order may have more than one payment attempt or shipment, and an item may have return records according to the business rules. Do not assume one-to-one relationships unless they are validated.

---

## 5. dbt project architecture

The dbt project is located in `ecommerce_dbt/`. Important project components include:

- `dbt_project.yml`: project name, model paths, and configuration.
- `packages.yml` and the generated package lock file, if used.
- `models/sources/`: source definitions for raw tables.
- `models/bronze/`: source-aligned models.
- `models/silver/`: cleaned and standardized models.
- `models/gold/dimensions/`: descriptive dimensions.
- `models/gold/facts/`: measurable business events.
- `macros/`: reusable Jinja/SQL logic such as audit-column helpers.
- `tests/`: custom data tests.
- `analyses/`: saved analytical SQL, including sales, customer, payment, returns, shipping, time comparison, forecasting, anomaly, and data-quality analysis.
- `target/`, `logs/`, and `dbt_packages/`: generated/runtime directories that should generally not be committed.

### 5.1 Source definitions

Source definitions are expected under:

```text
ecommerce_dbt/models/sources/
```

A model can refer to a declared raw table with syntax such as:

```sql
{{ source('raw', 'customers') }}
```

The exact source name and table identifier must match the current YAML source declaration. `source()` establishes the relationship between a dbt model and an upstream source.

### 5.2 Model dependencies

Use `ref()` to refer to other dbt models:

```sql
{{ ref('silver_order_items') }}
```

dbt uses `source()` and `ref()` to build the dependency graph, determine execution order, and provide lineage metadata. Avoid hard-coding downstream model names as fully qualified database objects when a dbt reference is appropriate.

---

## 6. Medallion layers

### 6.1 Bronze layer

**Purpose:** expose source data in a predictable model structure with limited transformation.

Typical responsibilities:

- Read from raw source tables.
- Standardize column names and basic types where needed.
- Preserve source identifiers and useful source attributes.
- Add or carry ingestion/audit metadata when available.
- Avoid embedding complex reporting logic.

Earlier model names include:

```text
bronze_customers
bronze_products
bronze_orders
bronze_order_items
```

Additional Bronze models may exist for the payment, return, and shipment entities. Check the current model directory for the authoritative list.

---

### 6.2 Silver layer

**Purpose:** provide cleaned, standardized, and reusable data for downstream reporting models.

Typical responsibilities:

- Normalize data types and values.
- Handle nulls and inconsistent representations according to documented rules.
- Validate key relationships and prepare joins.
- Apply reusable business rules.
- Retain enough information to explain rejected or anomalous records.
- Prepare transactional data for fact and dimension modeling.

Earlier model names include:

```text
silver_customers
silver_products
silver_orders
silver_order_items
```

Additional Silver models may support payments, returns, and shipments.

---

### 6.3 Gold layer

**Purpose:** provide stable, analytics-ready facts and dimensions for SQL analysis, semantic definitions, and dashboards.

The broader reporting layer has included these model concepts:

```text
Dimensions
- dim_customers
- dim_products
- dim_date

Facts
- fact_order_items
- fact_payments
- fact_returns
- fact_shipments
```

---

**Physical naming caution:** historical project runs also used a three-model Gold layer (`dim_customers`, `dim_products`, and `fact_order_items`) in `analytics_gold`. The wider list above reflects the reporting-layer scope documented for the evaluation. Verify which of the additional models currently exist and build successfully before describing all seven as implemented in the live database.

---

## 7. Dimensional model and grain

The Gold layer follows dimensional-modeling principles. A fact table stores events and measures; dimensions provide descriptive attributes for filtering and grouping.

### 7.1 `dim_customers`

Stores customer attributes used for customer and geographic analysis.

Typical attributes may include:

- `customer_id`
- customer name and contact attributes, if appropriate for the reporting use case
- city
- signup date
- available audit timestamps

**Expected grain:** one row per customer identifier, assuming the current model does not implement historical versions such as a Type 2 slowly changing dimension.

### 7.2 `dim_products`

Stores product attributes used for product and category analysis.

Typical attributes may include:

- `product_id`
- product name
- category
- product price or other source attributes
- available audit timestamps

**Expected grain:** one row per product identifier unless the model explicitly represents historical product versions.

### 7.3 `dim_date`

A reusable calendar dimension supports consistent year, month, and date filtering. It can include calendar date, year, month number, month label, quarter, and other date attributes if those columns exist in the current model.

**Expected grain:** one row per calendar date.

### 7.4 `fact_order_items`

The intended grain is:

> **One row per `order_item_id` — one product line within one order.**

Typical fields include order-item, order, customer, product, and date identifiers; order status; quantity; unit price; discount and tax amounts; recorded and calculated line totals; data-quality flags; return-related fields; and audit timestamps, depending on the current model.

This grain means that an order containing three distinct product lines contributes three fact rows. Do not count fact rows as orders; use a distinct order identifier for order counts.

### 7.5 `fact_payments`

The grain must be confirmed from the model's unique key. The project has used payment-level validation, with a payment identifier and attributes such as payment status, amount, method, transaction reference, and payment date. If the model is one row per payment record, multiple attempts or split payments may create multiple rows for a single order.

### 7.6 `fact_returns`

The grain must be confirmed from the return identifier and the model logic. The model supports return quantities, refund amounts, return status/reason, and links to the related order or order item where available. Multiple returns for a single item must not be ruled out without source evidence.

### 7.7 `fact_shipments`

The grain must be confirmed from the shipment identifier. Shipment status, shipment/delivery dates, delivery duration, and delay indicators can support logistics analysis. One order can have multiple shipments, so shipment counts and order counts are different measures.

---

## 8. Star-schema relationships and join safety

A simplified order-item star schema is:

```text
dim_customers              dim_products              dim_date
      |                         |                       |
      | customer_id             | product_id            | date key
      +-------------+-----------+-----------------------+
                    |
                    v
             fact_order_items
```

The broader reporting model may also include payment, return, and shipment facts. These facts should generally be analyzed at their own grain and joined through validated shared dimensions or carefully controlled keys.

**Avoid joining multiple fact tables directly at their raw grains without pre-aggregation.** For example, joining multiple payments and multiple shipment records to order items can multiply rows and inflate sales, payment amounts, or shipment counts. Document join rules in `semantic_layer/join_rules.md` and validate the output grain after each join.

---

## 9. Core business metrics and data-quality rules

Metric definitions should be maintained consistently in the semantic layer and documentation, rather than redefined independently in each dashboard.

Examples include:

| Metric                     | Definition / caution                                                                                                          |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Order count                | Count distinct `order_id` at the appropriate filtered grain                                                                   |
| Units sold                 | Sum eligible positive quantities, excluding invalid rows according to the documented rule                                     |
| Gross sales                | Use the project’s documented gross-sales formula and eligible order-item records                                              |
| Recorded line-total amount | Sum the recorded line-total measure only for eligible records                                                                 |
| Average order value (AOV)  | Revenue measure divided by distinct eligible orders; the revenue numerator must be named clearly                              |
| Payment success rate       | Successful payment records divided by payment records with a known success outcome; this is not an order conversion rate      |
| Refund amount              | Sum validated refund amounts at the return grain                                                                              |
| Returned units             | Sum validated returned quantities at the return grain                                                                         |
| Delivery duration          | Average delivery duration only for shipments with a valid duration                                                            |
| Delay rate                 | Delayed shipments divided by shipments with a known delay classification, unless another denominator is explicitly documented |
| MoM / YoY growth           | Compare equivalent periods and handle zero or missing prior-period values explicitly                                          |
| Rolling average            | A smoothed historical metric; a trailing rolling average is not automatically a future forecast                               |

---

### 9.1 Sales eligibility and reconciliation

Historical validation of `fact_order_items` identified two rows that required review: one with a negative quantity and one with a line-total mismatch. The project’s documented validation logic has included checks for positive quantity, nonnegative and present monetary inputs, a present line total, and reconciliation between recorded and calculated amounts within a tolerance of `0.01`.

Invalid records should remain traceable for audit purposes, but they should not silently contribute to financial metrics. Confirm the current model’s exact formula and flags before reusing the rules above as a formal production contract.

**Metric naming caution:** an earlier validation indicated that the model's `net_sales_amount` behaved like a final line-total amount including tax. Do not label it “net sales excluding tax” unless the SQL formula is changed and verified. Clearly distinguish gross sales, recorded line totals, discounts, tax, refunds, and any true net-revenue measure.

---

## 10. Audit metadata

The project has used audit columns such as:

```text
ingested_at
loaded_at
transformed_at
modeled_at
```

Their exact presence depends on the source and model. These fields help distinguish when a business event occurred from when data was ingested or transformed. In particular:

- **Event time**: when the order, payment, return, or shipment event occurred.
- **Ingestion time**: when the record entered the raw data environment.
- **Transformation/model time**: when a downstream model was built or updated.

Do not substitute ingestion time for business event time in sales trend charts unless the analysis specifically concerns ingestion operations.

---

## 11. Incremental processing

The project has used an incremental strategy for `fact_order_items`, with `order_item_id` as its unique key in the earlier implementation.

Conceptual flow:

```text
Raw source records
       |
       v
Bronze / Silver models
       |
       v
Incremental selection logic
       |
       +---- previously processed keys
       |
       +---- new or selected changed records
       |
       v
Gold fact table updated by dbt
```

An incremental model can reduce unnecessary reprocessing as data volume grows. However, an incremental strategy is correct only if its filter captures the relevant new and changed records and the merge/unique-key behavior is configured correctly.

Example command, run from the dbt project directory:

```bash
dbt run --select fact_order_items
```

A normal incremental run does not necessarily update every historical record. If a related order, product, customer, or source row changes after the fact row was first processed, the fact model must be designed to detect that change or the affected records must be backfilled.

---

## 12. Late-arriving data and backfills

The project simulated a historical record that was ingested after its business event date. The example documented previously used an event date of `2026-08-01` and an ingestion date of `2026-09-04`; treat these as simulation values, not production events.

```text
Business event date: 2026-08-01
            |
            | record arrives later
            v
Ingestion date:      2026-09-04
            |
            v
Incremental / backfill logic
            |
            v
Gold reporting model updated
```

The simulation demonstrates why event time and ingestion time must be separate. A reliable incremental process should define how it handles:

- Newly inserted records.
- Updates to existing records.
- Late-arriving records with old event dates.
- Changes in upstream dimensions.
- Duplicate deliveries or replays.
- Corrections and deleted/invalidated source records.

---

### 12.1 Full refresh

When a full rebuild is appropriate, use the command from the dbt project directory:

```bash
dbt run --full-refresh
```

For a full build including tests, use:

```bash
dbt build --full-refresh
```

A full refresh can be useful after material changes to model logic or incremental strategy, or when a full reconstruction is needed. Check the target database and the model selection before running it because it can rebuild substantial data.

---

## 13. Data-quality architecture

Data quality is enforced through dbt tests and SQL validation queries. The project has included or planned checks such as:

- `not_null` for required fields.
- `unique` for primary identifiers.
- `relationships` for validated foreign-key relationships.
- Accepted-value checks where status domains are defined.
- Custom tests for positive or reconciled order amounts.
- SQL checks for duplicate keys, missing relationships, invalid quantities, line-total mismatches, and unexplained differences between financial measures.

A test passing confirms only the rule that the test actually checks. It does not prove that all business data is correct or that all possible edge cases have been covered.

---

### 13.1 Custom test

The earlier project included a custom test named `test_positive_order_amount.sql`. Its exact behavior should be checked in the current file. A positive-amount test may be inappropriate for rows intentionally retained as invalid audit records, so eligibility and test severity need to align with the model’s intended behavior.

---

### 13.2 Build and test commands

Run from `ecommerce_dbt/`:

```bash
dbt debug
dbt deps
dbt compile
dbt build
```

Historical project notes recorded a successful build with `PASS=113`, `WARN=0`, `ERROR=0`, `SKIP=0`, and `TOTAL=113`. Other project iterations recorded different counts. These are historical run outputs, not a guarantee of the current checkout’s status. Use the latest terminal output as the source of truth.

---

## 14. Source freshness and monitoring

Source freshness can be configured in the source YAML when suitable timestamp columns and freshness thresholds are available.

Command:

```bash
dbt source freshness
```

A freshness check compares the most recent available source timestamp with the configured threshold. It helps identify stale inputs, but it does not replace validation of row counts, schema changes, completeness, or business correctness.

Freshness checks should use an appropriate ingestion/update timestamp. If a source table is not updated continuously or uses simulated data, document that limitation and avoid treating a lack of new records as a production incident automatically.

---

## 15. Data lineage

The logical lineage is:

```text
raw sources
    |
    v
Bronze models
    |
    v
Silver models
    |
    v
Gold dimensions and facts
    |
    v
SQL analyses / semantic definitions
    |
    v
Dashboard queries
    |
    v
Power BI pages
```

Lineage is represented by dbt `source()` and `ref()` dependencies and should be cross-documented in `docs/data_lineage.md`. For a current, model-level lineage view, generate dbt documentation after a successful parse/build:

```bash
dbt docs generate
dbt docs serve
```

These commands should be run from `ecommerce_dbt/`. The docs site is a local development tool unless separately hosted.

---

## 16. Analytics and dashboard architecture

The reporting layer is intended to support multiple business personas. The repository includes dashboard query/documentation folders for leadership and operations, with an additional data-quality/forecasting page documented in the broader Power BI work.

---

### 16.1 Leadership dashboard

Typical audience: business leaders and managers.

Questions include:

- How are sales and order volumes trending?
- Which categories and products contribute most to sales?
- How are current results changing versus the previous month or year?
- What is the average order value?
- Is the rolling trend increasing or decreasing?

Typical content includes KPI cards, monthly sales trends, category sales, top products, and time comparisons.

---

### 16.2 Operations dashboard

Typical audience: operations, payments, shipping, and customer-support analysts.

Questions include:

- What is the distribution of order statuses?
- What proportion of payments succeeded?
- How many shipments were delivered or classified as delayed?
- How many units were returned and what refund amounts were recorded?
- What is the average delivery duration among shipments with valid durations?

The denominator and status coverage should be visible in metric definitions, particularly where delay or delivery information is unknown.

---

### 16.3 Data Quality and Forecasting view

Typical content includes:

- Invalid order-item counts.
- Line-total mismatches and negative quantities.
- Trends in data-quality exceptions.
- Monthly sales compared with a trailing rolling average.
- Anomaly or spike investigation supported by SQL.

A trailing rolling average is a descriptive baseline, not a forecast of future sales. If a forecast is shown, document the forecasting method, period, assumptions, and validation limits.

---

### 16.4 SQL backing each visual

Store the SQL used to power or validate visuals in the dashboard-specific query files, including:

```text
dashboards/
├── leadership/
│   ├── dashboard_queries.sql
│   └── README.md
└── operations/
    ├── dashboard_queries.sql
    └── README.md
```

The exact repository may also contain additional dashboard folders or a separate Power BI `.pbix` file. The query file and dashboard should agree on metric formulas, filters, date ranges, and grain. If a visual uses a DAX measure rather than a SQL query directly, document the equivalent business definition and how it reconciles to the Gold data.

---

## 17. Semantic layer

The semantic layer is the business-facing abstraction over the Gold reporting models. Project documentation includes or is intended to include files such as:

```text
semantic_layer/
├── README.md
├── metric_definitions.md
├── dimensions.md
├── join_rules.md
├── model_grain.md
├── metrics_catalog.csv
└── metric_validation.sql
```

Responsibilities:

- Define metrics once with clear formulas and denominators.
- Document the grain of each fact and dimension.
- Identify safe join paths and potential fan-out.
- Standardize dimensions such as date, customer, product, status, and category.
- Provide validation SQL for key metrics.
- Keep dashboard terminology consistent.

The semantic layer is a documented abstraction unless a specific semantic platform/model is configured. Do not describe a full Looker semantic model as implemented unless the LookML or equivalent model files actually exist and are working.

---

## 18. Time comparisons, forecasts, and anomalies

The analytics work includes SQL analysis for time comparisons, rolling averages, and anomaly investigation.

---

### 18.1 MoM / YoY

- Month-over-month comparisons compare a period with the immediately preceding month.
- Year-over-year comparisons compare a period with the equivalent period in the prior year.
- Handle missing prior periods and zero denominators explicitly.
- Use consistent date boundaries and a clearly named revenue metric.

---

### 18.2 Rolling average

A trailing three-month average smooths short-term variation by averaging the current month and the preceding two months, depending on the exact SQL window definition. Confirm whether the implementation includes the current month and how incomplete months are treated.

---

### 18.3 Forecasting

A simple forecast may use a rolling average or a linear trend, but the methodology must be explicitly documented. A smoothed historical line alone should not be presented as future prediction. Record the forecast horizon, training period, method, and limitations.

---

### 18.4 Anomaly detection

Anomaly analysis should identify unusual changes or spikes for investigation, not automatically conclude that a business event is fraudulent or erroneous. Document the baseline, threshold, comparison window, and known data-quality issues that could explain the anomaly.

---

## 19. Repository structure

The following is a consolidated working structure based on the project documentation. It is an architectural guide, not a claim that every listed file currently exists in the working tree. Use `dir /s` or the VS Code Explorer to confirm the actual repository.

```text
ecommerce-analytics/
├── .github/
│   ├── workflows/
│   │   └── dbt-ci.yml
│   └── profiles.yml                 # Optional credential-free CI profile
├── dashboards/
│   ├── leadership/
│   │   ├── dashboard_queries.sql
│   │   └── README.md
│   └── operations/
│       ├── dashboard_queries.sql
│       └── README.md
├── docs/
│   ├── architecture.md
│   ├── anomaly_detection_methodology.md
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
│   └── model_grain.md
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
│   ├── macros/
│   ├── models/
│   │   ├── sources/
│   │   ├── bronze/
│   │   ├── silver/
│   │   └── gold/
│   │       ├── dimensions/
│   │       └── facts/
│   ├── tests/
│   ├── scripts/
│   ├── dbt_project.yml
│   ├── packages.yml
│   └── package-lock.yml             # If generated by the installed dbt version
├── semantic_layer/
│   ├── README.md
│   ├── dimensions.md
│   ├── join_rules.md
│   ├── metric_definitions.md
│   ├── metric_validation.sql
│   ├── metrics_catalog.csv
│   └── model_grain.md
├── sql/
│   ├── analytics_queries/
│   ├── 01_create_database.sql
│   ├── 02_create_raw_tables.sql
│   ├── 03_insert_raw_data.sql
│   ├── 04_add_ingested_at.sql
│   └── 05_raw_data_quality_checks.sql
├── .env                              # Local only; never commit secrets
├── .env.example                      # Placeholder values only
├── .gitignore
├── README.md
├── requirements.txt
└── Ecommerce_Analytics_Dashboard.pbix # If stored in this repository
```

Do not commit `.env`, database passwords, or local virtual environments. Ignore dbt-generated `target/`, `logs/`, and `dbt_packages/` directories unless there is a specific reason to version a generated artifact.

---

## 20. CI architecture

The project has a GitHub Actions workflow at:

```text
.github/workflows/dbt-ci.yml
```

The workflow is intended to install Python and dbt dependencies, connect to a temporary PostgreSQL service, and run dbt validation commands such as `dbt debug`, `dbt compile`, and `dbt build`.

**Critical CI prerequisite:** a new PostgreSQL service starts empty. If the dbt models expect raw tables and data, the workflow must create/load those source tables before `dbt build`. Otherwise, a correctly written dbt model can fail because the CI database has no source relations. A CI profile may be committed only if it contains no real credentials; use GitHub secrets for sensitive values.

Treat CI as implemented only after the workflow has actually run successfully in GitHub Actions. A workflow file alone does not prove that CI passes.

---

## 21. Local environment and execution

The project has been developed on Windows with VS Code and a Python virtual environment. Commands below should be run in the appropriate terminal and from the stated directory.

---

### 21.1 Activate the environment

From the repository root in Windows Command Prompt:

```bat
.venv\Scripts\activate
```

If the environment has not been created yet, create it with the Python version required by the project and install dependencies from `requirements.txt`.

---

### 21.2 Verify dbt and the database connection

From the repository root, activate the environment first. Then run:

```bat
dbt --version
```

From `ecommerce_dbt/`, run:

```bat
dbt debug
dbt deps
dbt compile
dbt build
```

`dbt debug` checks the profile and connection configuration. `dbt deps` installs declared dbt packages. `dbt compile` checks model compilation. `dbt build` runs selected models and tests in dependency order.

---

### 21.3 Refresh the reporting layer

After new source data has been loaded, run the intended dbt build and refresh the connected Power BI model as required. Dashboard refresh behavior depends on the configured PostgreSQL connection and Power BI storage mode.

---

## 22. Historical validation snapshots

The project notes contain multiple validation snapshots from different stages. They must not be combined as if they came from one unchanged database run.

---

### 22.1 Earlier three-model Gold snapshot

An earlier run documented:

| Table              | Historical row count |
| ------------------ | -------------------: |
| `dim_customers`    |                   15 |
| `dim_products`     |                   15 |
| `fact_order_items` |                   63 |

The same iteration recorded a successful dbt build with `PASS=113`, `WARN=0`, `ERROR=0`, and `SKIP=0`.

---

### 22.2 Broader reporting-layer snapshot

A later evaluation context documented the following Gold counts:

| Model              | Historical row count |
| ------------------ | -------------------: |
| `dim_customers`    |                  120 |
| `dim_date`         |                1,707 |
| `dim_products`     |                  500 |
| `fact_order_items` |                  644 |
| `fact_payments`    |                  320 |
| `fact_returns`     |                   30 |
| `fact_shipments`   |                  290 |

These counts are historical and may belong to a later dataset or implementation stage. Re-query the current database to establish current counts.

---

### 22.3 Historical metric validation observations

The later reporting work recorded these observations, which should be revalidated before use in a final submission:

- `fact_order_items`: 644 rows and 644 distinct `order_item_id` values.
- 642 rows were marked eligible for sales; 2 were invalid.
- 2 line-total mismatches and 1 negative-quantity issue were identified.
- Eligible units were recorded as 1,975.
- Gross sales were recorded as `25,281,271.32`.
- The current line-total-based amount was recorded as `25,347,841.41`; the difference was `66,570.09`.
- Average order value was recorded as `79,212.00`, based on the implementation’s selected revenue measure and order denominator.
- Payments: 320 records; 224 successful and 96 unsuccessful; recorded payment success rate 70%; payment amount total `25,773,107.21`.
- Returns: 30 records, 61 returned units, and recorded refunds of `767,215.84`.
- Shipments: 290 records; 165 delivered; 45 delayed; average delivery duration 3.89 days for records with a valid duration. Delay rate among the 165 shipments with known delay classification was recorded as 27.27% (`45 / (45 + 120)`).

These figures are not guaranteed to reconcile across different model versions or datasets. In particular, the financial metrics may use different definitions, and shipment denominators exclude unknown classifications. Document the current SQL formulas alongside any final reported values.

---

## 23. Key limitations and risks

- **Mock data:** generated data may not reflect real customer behavior, seasonality, operational constraints, or real production distributions.
- **Local execution:** the current architecture is primarily a local learning/evaluation setup; production deployment, scheduling, and alerting require additional work.
- **Source completeness:** the existence and completeness of raw payment, return, and shipment tables must be verified against current DDL and source definitions.
- **Incremental updates:** a unique key alone does not handle every late update or upstream correction; incremental filters and merge behavior must be tested.
- **Fact-table fan-out:** direct joins between facts can duplicate values if their grains differ.
- **Metric ambiguity:** sales, line totals, taxes, discounts, refunds, payment amount, and net revenue are not interchangeable.
- **Unknown statuses:** unknown shipment or payment outcomes should not silently be treated as success, failure, delivered, or not delayed.
- **Historical snapshots:** row counts and build totals change as data and models change.
- **CI bootstrap:** CI must initialize raw schemas/tables/data before building downstream models.
- **Forecasting:** a rolling average is not itself a forward-looking forecast.
- **Security:** local credentials must remain outside Git; CI secrets should be stored in the repository’s secret-management settings.

---

## 25. Final architecture summary

The project demonstrates a local end-to-end analytics engineering workflow:

```text
Mock data generation
        |
        v
PostgreSQL raw storage
        |
        v
dbt source definitions
        |
        v
Bronze: source-aligned models
        |
        v
Silver: cleaned / standardized models
        |
        v
Gold: facts and dimensions
        |
        v
Semantic definitions + validation SQL
        |
        v
Dashboard queries / measures
        |
        v
Leadership + Operations + Data Quality / Forecasting dashboards
```

The main deliverable is not just a collection of charts. It is a documented reporting layer with explicit grains, traceable transformations, reusable metric definitions, quality checks, SQL validation, and dashboards targeted to different business personas. The final submission should clearly separate features that are implemented and tested from features that are documented, simulated, or still planned.
