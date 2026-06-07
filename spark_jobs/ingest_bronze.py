from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("RetailBronze") \
    .master("local[*]") \
    .config("spark.jars.packages",
            "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions",
            "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.driver.memory", "1500m") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

RAW_PATH    = "/opt/data/raw"
BRONZE_PATH = "/opt/delta_lake/bronze"

# Each CSV becomes an independent Delta table in the Bronze layer.
# Nothing is changed, cleaned, or joined — Bronze is a faithful copy
# of the source. If anything downstream breaks, you reprocess from here.
tables = {
    "orders":    "olist_orders_dataset.csv",
    "customers": "olist_customers_dataset.csv",
    "items":     "olist_order_items_dataset.csv",
    "reviews":   "olist_order_reviews_dataset.csv",
    "payments":  "olist_order_payments_dataset.csv",
}

for table_name, filename in tables.items():
    df = spark.read.csv(
        f"{RAW_PATH}/{filename}",
        header      = True,
        inferSchema = True,
    )
    df.write.format("delta") \
        .mode("overwrite") \
        .save(f"{BRONZE_PATH}/{table_name}")
    print(f"[bronze] {table_name}: {df.count()} rows written")

spark.stop()
