from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.models.baseoperator import BaseOperator
from airflow.operators.empty import EmptyOperator
from airflow.utils.task_group import TaskGroup
from dotenv import dotenv_values


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DBT_PROJECT_DIR = PROJECT_ROOT / "dbt"
INGESTION_DIR = PROJECT_ROOT / "ingestion"

PYTHON_BIN = os.environ.get("RETAIL_DW_PYTHON_BIN", sys.executable)
DBT_BIN = os.environ.get("RETAIL_DW_DBT_BIN", "dbt")


def project_env() -> dict[str, str]:
    env = os.environ.copy()
    env_file = PROJECT_ROOT / ".env"

    if env_file.exists():
        for key, value in dotenv_values(env_file).items():
            if value is not None:
                env.setdefault(key, value)

    env.setdefault("DBT_PROFILES_DIR", str(DBT_PROJECT_DIR))
    env["PYTHONPATH"] = os.pathsep.join(
        [str(PROJECT_ROOT), env.get("PYTHONPATH", "")]
    ).rstrip(os.pathsep)
    return env


def run_command(command: list[str], cwd: str) -> None:
    subprocess.run(
        command,
        cwd=cwd,
        env=project_env(),
        check=True,
    )


class CommandOperator(BaseOperator):
    template_fields = ("command", "cwd")

    def __init__(self, *, command: list[str], cwd: str, **kwargs) -> None:
        super().__init__(**kwargs)
        self.command = command
        self.cwd = cwd

    def execute(self, context) -> None:
        self.log.info("Running command: %s", " ".join(self.command))
        run_command(self.command, self.cwd)


def python_task(task_id: str, script_name: str) -> CommandOperator:
    return CommandOperator(
        task_id=task_id,
        command=[PYTHON_BIN, str(INGESTION_DIR / script_name)],
        cwd=str(PROJECT_ROOT),
    )


def dbt_task(task_id: str, *args: str) -> CommandOperator:
    return CommandOperator(
        task_id=task_id,
        command=[DBT_BIN, *args, "--profiles-dir", str(DBT_PROJECT_DIR)],
        cwd=str(DBT_PROJECT_DIR),
    )


default_args = {
    "owner": "retail_dw",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}


with DAG(
    dag_id="retail_dw_pipeline",
    description="Ingest retail data and build all dbt models for the retail warehouse.",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["retail", "snowflake", "dbt"],
) as dag:
    start = EmptyOperator(task_id="start")
    finish = EmptyOperator(task_id="finish")

    with TaskGroup(group_id="ingest_raw_data") as ingest_raw_data:
        ingest_api = python_task("ingest_api_products_and_users", "api_ingestor.py")
        ingest_customers = python_task("ingest_customers_csv", "csv_ingestor.py")
        ingest_orders = python_task("ingest_orders_json", "json_ingestor.py")

    dbt_deps = dbt_task("dbt_deps", "deps")

    with TaskGroup(group_id="dbt_staging") as dbt_staging:
        stg_customers = dbt_task("run_stg_customers", "run", "--select", "stg_customers")
        stg_orders = dbt_task("run_stg_orders", "run", "--select", "stg_orders")
        stg_products = dbt_task("run_stg_products", "run", "--select", "stg_products")

    run_intermediate = dbt_task(
        "run_int_order_items_enriched",
        "run",
        "--select",
        "int_order_items_enriched",
    )

    snapshot_customers = dbt_task(
        "snapshot_dim_customer",
        "snapshot",
        "--select",
        "dim_customer_snapshot",
    )

    with TaskGroup(group_id="dbt_marts") as dbt_marts:
        dim_date = dbt_task("run_dim_date", "run", "--select", "dim_date")
        dim_product = dbt_task("run_dim_product", "run", "--select", "dim_product")
        dim_customer = dbt_task("run_dim_customer", "run", "--select", "dim_customer")
        fact_orders = dbt_task("run_fact_orders", "run", "--select", "fact_orders")

        dim_date >> fact_orders
        dim_product >> fact_orders
        dim_customer >> fact_orders

    dbt_test = dbt_task("dbt_test", "test")

    start >> ingest_raw_data >> dbt_deps >> dbt_staging

    [stg_orders, stg_products] >> run_intermediate
    stg_customers >> snapshot_customers

    dbt_deps >> dim_date
    stg_products >> dim_product
    snapshot_customers >> dim_customer
    run_intermediate >> fact_orders
    [run_intermediate, dbt_marts] >> dbt_test >> finish
