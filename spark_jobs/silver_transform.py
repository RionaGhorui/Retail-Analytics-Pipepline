from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, to_date, datediff

spark = SparkSession.builder \
    .appName("RetailSilver") \
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

BRONZE = "/opt/delta_lake/bronze"
SILVER = "/opt/delta_lake/silver"

orders    = spark.read.format("delta").load(f"{BRONZE}/orders")
customers = spark.read.format("delta").load(f"{BRONZE}/customers")
payments  = spark.read.format("delta").load(f"{BRONZE}/payments")
reviews   = spark.read.format("delta").load(f"{BRONZE}/reviews")

#1
# Filter to delivered orders only, parse timestamps, compute delivery duration.
orders_clean = orders \
    .filter(col("order_status") == "delivered") \
    .dropDuplicates(["order_id"]) \
    .withColumn("order_purchase_ts",
                to_timestamp("order_purchase_timestamp")) \
    .withColumn("delivery_days",
                datediff(
                    to_date("order_delivered_customer_date"),
                    to_date("order_purchase_timestamp"),
                )) \
    .select("order_id", "customer_id", "order_purchase_ts", "delivery_days")

#2
# One payment total per order (multiple payment methods sum together)
payments_agg = payments \
    .groupBy("order_id") \
    .agg({"payment_value": "sum"}) \
    .withColumnRenamed("sum(payment_value)", "order_value")

#3
# One review per order (take the first if duplicates exist)
reviews_clean = reviews \
    .dropDuplicates(["order_id"]) \
    .select("order_id", "review_score")

#4
# Build a flat master table: one row per order with all dimensions attached
silver_df = orders_clean \
    .join(
        customers.select("customer_id", "customer_unique_id", "customer_state"),
        on="customer_id", how="left",
    ) \
    .join(payments_agg, on="order_id", how="left") \
    .join(reviews_clean, on="order_id", how="left") \
    .filter(col("order_value").isNotNull())

silver_df.write.format("delta") \
    .mode("overwrite") \
    .save(f"{SILVER}/orders_master")

print(f"[silver] orders_master: {silver_df.count()} rows written")
spark.stop()
