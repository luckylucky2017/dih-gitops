import os

from pymongo import MongoClient
from pyspark.sql import SparkSession
from pyspark.sql.types import StringType, StructField, StructType, TimestampType

p = "spark.sql.catalog.dih"
spark = (SparkSession.builder.appName("mongo-to-iceberg")
  .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
  .config(p, "org.apache.iceberg.spark.SparkCatalog")
  .config(p + ".catalog-impl", "org.apache.iceberg.jdbc.JdbcCatalog")
  .config(p + ".uri", "jdbc:postgresql://dih-pg-rw.dih-data.svc.cluster.local:5432/iceberg_catalog")
  .config(p + ".jdbc.user", os.environ["ICEBERG_DB_USER"])
  .config(p + ".jdbc.password", os.environ["ICEBERG_DB_PASSWORD"])
  .config(p + ".warehouse", "s3://curated/warehouse")
  .config(p + ".io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
  .config(p + ".s3.endpoint", os.environ.get("S3_ENDPOINT", "http://10.1.67.193:9000"))
  .config(p + ".s3.path-style-access", "true")
  .config(p + ".client.region", "us-east-1")
  .getOrCreate())

client = MongoClient(
    host=os.environ["MONGO_HOST"], port=27017,
    username=os.environ["MONGO_USER"], password=os.environ["MONGO_PASSWORD"],
    authSource="dih_lab", replicaSet="rs0", tls=True,
    tlsCAFile=os.environ.get("MONGO_CA_FILE", "/ca/ca.crt"),
    serverSelectionTimeoutMS=10000)
docs = list(client["dih_lab"]["customers"].find().sort("_id", 1))
client.close()
if not docs:
    raise SystemExit("dih_lab.customers rỗng, dừng")

schema = StructType([
    StructField("customer_id", StringType(), False),
    StructField("name", StringType(), True),
    StructField("segment", StringType(), True),
    StructField("city", StringType(), True),
    StructField("balance_band", StringType(), True),
    StructField("updated_at", TimestampType(), True),
])
rows = [(d["_id"], d.get("name"), d.get("segment"), d.get("city"),
         d.get("balance_band"), d.get("updated_at")) for d in docs]
df = spark.createDataFrame(rows, schema)

spark.sql("CREATE NAMESPACE IF NOT EXISTS dih.curated")
df.writeTo("dih.curated.customers").createOrReplace()
print("MONGO_ICEBERG_COUNT=%d" % spark.table("dih.curated.customers").count())
spark.table("dih.curated.customers").orderBy("customer_id").show(truncate=False)
spark.stop()
