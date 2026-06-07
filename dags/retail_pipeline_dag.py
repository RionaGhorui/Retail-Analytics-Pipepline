from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago
from datetime import timedelta

SPARK_SUBMIT = (
    "spark-submit "
    "--master local[*] "
    "--packages io.delta:delta-core_2.12:2.4.0 "
    "/opt/spark_jobs/{script}"
)

default_args = {
    "owner":            "Riona",
    "retries":          2,
    "retry_delay":      timedelta(minutes=3),
    "email_on_failure": False,
}

with DAG(
    dag_id            = "retail_analytics_pipeline",
    default_args      = default_args,
    description       = "Medallion ETL + R churn modeling on Olist dataset",
    schedule_interval = "@daily",
    start_date        = days_ago(1),
    catchup           = False,
    tags              = ["retail", "medallion", "spark", "r"],
) as dag:

    bronze_ingest = BashOperator(
        task_id      = "bronze_ingest",
        bash_command = SPARK_SUBMIT.format(script="ingest_bronze.py"),
    )

    silver_transform = BashOperator(
        task_id      = "silver_transform",
        bash_command = SPARK_SUBMIT.format(script="silver_transform.py"),
    )

    gold_features = BashOperator(
        task_id      = "gold_features",
        bash_command = SPARK_SUBMIT.format(script="gold_features.py"),
    )

    r_modeling = BashOperator(
        task_id      = "r_modeling",
        bash_command = "Rscript /opt/r_scripts/churn_model.R",
    )

    bronze_ingest >> silver_transform >> gold_features >> r_modeling
