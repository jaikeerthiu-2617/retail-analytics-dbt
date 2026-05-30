# Retail Data Warehouse

A compact, assignment-ready retail analytics warehouse built with **dbt**, **Snowflake**, and **Airflow**. The project models raw retail data into a clean star schema, captures customer history with an SCD Type 2 snapshot, supports incremental fact loading, and includes SQL reports for business analysis.

## What This Project Delivers

| Requirement | Implementation |
| --- | --- |
| Data ingestion | Seed CSVs for customers, orders, and products, plus a helper script to refresh product data from the FakeStore API |
| Star schema | `dim_date`, `dim_customer`, `dim_product`, and `fact_orders` marts |
| SCD handling | dbt snapshot `dim_customer_snapshot` tracks customer history |
| Incremental loading | `fact_orders` is configured as an incremental model |
| Reporting | Ready-to-run analytics SQL in `reporting/analytics_queries.sql` |
| Orchestration | Airflow DAG `retail_dw_pipeline` coordinates ingestion, dbt runs, snapshots, marts, and tests |

## Architecture

```text
FakeStore API / CSV Seeds
          |
          v
RAW_DB.RAW
          |
          v
dbt Staging Models
  stg_customers
  stg_orders
  stg_products
          |
          v
Intermediate Model
  int_order_items_enriched
          |
          +------------------+
          |                  |
          v                  v
SCD2 Snapshot           Dimension Models
  dim_customer_snapshot   dim_date
          |               dim_product
          v               dim_customer
      dim_customer              |
          |                     |
          +----------+----------+
                     v
                fact_orders
                     |
                     v
             Reporting SQL
```

## Project Structure

```text
retail-dw/
  airflow/
    dags/
      retail_dw_dag.py          # Airflow orchestration DAG
  dbt/
    models/
      staging/                  # Raw-to-clean source models
      intermediate/             # Business-ready joining layer
      marts/                    # Star schema dimensions and facts
    seeds/                      # Source CSV files loaded by dbt seed
    snapshots/                  # SCD Type 2 customer snapshot
    dbt_project.yml
    profiles.yml
  reporting/
    analytics_queries.sql       # Business reporting queries
  scripts/
    fetch_api_to_csv.py         # Refreshes product seed data from FakeStore API
  requirements.txt
```

## Data Model

### Staging

- `stg_customers`: cleans customer attributes and prepares tier metadata.
- `stg_orders`: standardizes order dates, amounts, discounts, statuses, and payment fields.
- `stg_products`: flattens product and rating data.

### Intermediate

- `int_order_items_enriched`: joins order lines with product context and derives analysis-ready order metrics.

### Marts

- `dim_date`: reusable calendar dimension.
- `dim_product`: product dimension with category, pricing, and rating attributes.
- `dim_customer`: SCD2 customer dimension projected from the dbt snapshot.
- `fact_orders`: incremental order fact table for revenue, quantity, discounts, and status analysis.

## Setup

Install dependencies from the project root:

```bash
pip install -r requirements.txt
```

Create a local `.env` file with your Snowflake connection values:

```bash
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_AUTHENTICATOR=snowflake
```

The dbt profile uses environment variables, so secrets stay outside source control.

## Run dbt Locally

From the project root:

```bash
cd dbt
dbt deps --profiles-dir .
dbt seed --profiles-dir .
dbt run --select staging intermediate --profiles-dir .
dbt snapshot --profiles-dir .
dbt run --select marts --profiles-dir .
dbt test --profiles-dir .
```

To refresh product seed data from the FakeStore API:

```bash
python scripts/fetch_api_to_csv.py
```

## Airflow DAG

The DAG is defined at:

```text
airflow/dags/retail_dw_dag.py
```

It creates the `retail_dw_pipeline` DAG with this flow:

```text
start
  -> ingest_raw_data
  -> dbt_deps
  -> dbt_staging
  -> intermediate + snapshot
  -> marts
  -> dbt_test
  -> finish
```

Start Airflow and trigger the DAG from the UI:

```bash
airflow db init
airflow webserver --port 8080
airflow scheduler
```

## Reporting

Use `reporting/analytics_queries.sql` to answer warehouse questions such as:

- monthly revenue trend
- revenue by category
- customer lifetime value
- customer history changes
- data quality checks

## Notes

- `.env`, dbt artifacts, Airflow runtime files, Python caches, logs, and dbt local user state are ignored by Git.
- `dbt/profiles.yml` is safe to keep in the project because it reads credentials from environment variables.
- `fact_orders` uses incremental materialization, so repeated runs process only newer order data according to the model logic.
