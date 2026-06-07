# Retail Analytics Pipeline

This is an end-to-end data engineering and data science pipeline on the Olist Brazilian e-commerce dataset. I implemented a Medallion Architecture (Bronze -> Silver -> Gold) using Apache Spark with Delta Lake, orchestrated by Apache Airflow, with churn prediction and survival analysis in R.

---

## Architecture

```
Raw CSVs
   │
   ▼
[Spark] Bronze Layer       — Raw Delta tables, one per source CSV
   │
   ▼
[Spark] Silver Layer       — Cleaned, joined, one flat orders_master table
   │
   ▼
[Spark] Gold Layer         — One row per customer, RFM features + churn label
   │
   ▼
[R] Modeling               — Logistic regression + Kaplan-Meier survival curve
```

All four stages are tasks in a single Airflow DAG with dependency enforcement and automatic retries.

---

## Stack

| Tool | Role |
|---|---|
| Apache Spark 3.4 (local mode) | Distributed data processing across Medallion layers |
| Delta Lake 2.4 | ACID-compliant lakehouse storage with schema enforcement |
| Apache Airflow 2.8 | Pipeline orchestration — DAG, retries, dependency chain |
| R (arrow + glm + survival) | Churn modeling and Kaplan-Meier survival analysis |
| Docker | Single reproducible container — one command to run |

---

## Dataset

**Brazilian E-Commerce Public Dataset by Olist** — available on [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

Download all CSVs and place them in `data/raw/`. Required files:

```
data/raw/
├── olist_orders_dataset.csv
├── olist_customers_dataset.csv
├── olist_order_items_dataset.csv
├── olist_order_reviews_dataset.csv
└── olist_order_payments_dataset.csv
```

---

## Setup and Running

### Prerequisites

- Docker Desktop (allocate at least 4 GB RAM in Docker settings)
- Git

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/retail-analytics-pipeline.git
cd retail-analytics-pipeline

# 2. Add Olist CSVs to data/raw/ (see Dataset section above)

# 3. Build the Docker image — first time only, takes ~10 minutes
docker-compose build

# 4. Start the container
docker-compose up -d

# 5. Wait ~60 seconds for Airflow to initialize, then open:
#    http://localhost:8080  →  login: admin / admin

# 6. Trigger the pipeline:
#    DAGs → retail_analytics_pipeline → ▶ Trigger DAG

# 7. Watch four tasks complete in the graph view (~5-10 minutes total)

# 8. Find outputs on your machine at:
#    delta_lake/gold/survival_curve.png
#    delta_lake/gold/rfm_distribution.png
#    delta_lake/gold/model_summary.txt
```

To stop: `docker-compose down`

---

## Project Structure

```
retail-analytics-pipeline/
├── Dockerfile                       # Airflow + Java + R + PySpark in one image
├── docker-compose.yml               # Single service, 4 GB cap
├── dags/
│   └── retail_pipeline_dag.py       # Airflow DAG — 4 tasks, linear dependency chain
├── spark_jobs/
│   ├── ingest_bronze.py             # Raw CSV → Delta Bronze layer
│   ├── silver_transform.py          # Clean + join → Delta Silver layer
│   └── gold_features.py             # RFM features + churn label → Delta Gold layer
├── r_scripts/
│   └── churn_model.R                # Logistic regression + survival analysis + plots
├── data/
│   └── raw/                         # Olist CSVs go here (git-ignored)
└── delta_lake/                      # Generated Delta tables (git-ignored)
    ├── bronze/
    ├── silver/
    └── gold/
```

---

## Pipeline Details

### Bronze Layer (`ingest_bronze.py`)
Five Olist CSVs are read and written to Delta Lake with no modifications. Bronze is immutable — it is the source of truth. If any downstream layer is corrupted, reprocessing starts here.

### Silver Layer (`silver_transform.py`)
Filters to delivered orders only, parses timestamps, computes delivery duration, aggregates payment values per order, deduplicates reviews, and joins all tables into a single flat `orders_master` table. Uses `customer_unique_id` (Olist's actual unique customer key) rather than `customer_id` (which is per-order).

### Gold Layer (`gold_features.py`)
Aggregates `orders_master` to one row per unique customer with RFM features: recency (days since last purchase), frequency (order count), and monetary features. Applies a business-defined churn label: a single-purchase customer with no return in 180+ days. Also writes a plain Parquet copy for R consumption.

### R Modeling (`churn_model.R`)
Reads Gold Parquet via the `arrow` package (no JVM required). Fits a logistic regression using base R `glm()`. Evaluates with AUC-ROC via `pROC`. Fits a Kaplan-Meier survival curve using the `survival` and `survminer` packages. Saves plots and a model summary to `delta_lake/gold/`.

---
