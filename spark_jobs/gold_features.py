from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col,
    max as spark_max,
    count,
    sum as spark_sum,
    avg,
    datediff,
    to_date,
    lit,
    when,
)

spark = SparkSession.builder \
    .appName("RetailGold") \
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

SILVER = "/opt/delta_lake/silver"
GOLD   = "/opt/delta_lake/gold"

df = spark.read.format("delta").load(f"{SILVER}/orders_master")

# Last date in the Olist dataset — used as "today" for recency calculation
SNAPSHOT = "2018-10-17"

rfm = df.groupBy("customer_unique_id").agg(
    datediff(
        lit(SNAPSHOT).cast("date"),
        spark_max(to_date("order_purchase_ts")),
    ).alias("recency_days"),
    count("order_id").alias("frequency"),
    spark_sum("order_value").alias("monetary_total"),
    avg("order_value").alias("avg_order_value"),
    avg("review_score").alias("avg_review_score"),
    avg("delivery_days").alias("avg_delivery_days"),
)

gold_df = rfm.withColumn(
    "is_churned",
    when((col("frequency") == 1) & (col("recency_days") > 180), 1)
    .otherwise(0),
)


gold_df.write.format("delta") \
    .mode("overwrite") \
    .save(f"{GOLD}/customer_features")


gold_df.write.format("parquet") \
    .mode("overwrite") \
    .save(f"{GOLD}/customer_features_parquet")

print(f"[gold] customer_features: {gold_df.count()} rows")
gold_df.groupBy("is_churned").count().show()

gold_df.toPandas().to_csv(f"{GOLD}/customer_features.csv", index=False)

spark.stop()
