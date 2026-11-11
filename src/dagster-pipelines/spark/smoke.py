import os
from pyspark.sql import SparkSession

p = "spark.sql.catalog.dih"
spark = (SparkSession.builder.appName("iceberg-smoke")
  .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
  .config(p, "org.apache.iceberg.spark.SparkCatalog")
  .config(p + ".catalog-impl", "org.apache.iceberg.jdbc.JdbcCatalog")
  .config(p + ".uri", "jdbc:postgresql://dih-pg-rw.dih-data.svc.cluster.local:5432/iceberg_catalog")
  .config(p + ".jdbc.user", os.environ["ICEBERG_DB_USER"])
  .config(p + ".jdbc.password", os.environ["ICEBERG_DB_PASSWORD"])
  .config(p + ".warehouse", "s3://curated/warehouse")
  .config(p + ".io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
  .config(p + ".s3.endpoint", "http://10.1.67.193:9000")
  .config(p + ".s3.path-style-access", "true")
  .config(p + ".client.region", "us-east-1")
  .getOrCreate())

spark.sql("CREATE NAMESPACE IF NOT EXISTS dih.smoke")
spark.range(1000).writeTo("dih.smoke.t1").createOrReplace()
print("SMOKE_COUNT=%d" % spark.table("dih.smoke.t1").count())
spark.sql("SELECT snapshot_id, operation FROM dih.smoke.t1.snapshots").show(truncate=False)
spark.stop()
