from dagster import asset, Definitions

from .spark_job import spark_iceberg_smoke
from .catalog import openmetadata_ingest_postgres
from .mongo_seed import mongo_seed_customers
from .spark_mongo import spark_mongo_to_iceberg


@asset(group_name="smoke")
def hello(context):
    context.log.info("dih-pipelines hoat dong")
    return 1


defs = Definitions(assets=[hello, spark_iceberg_smoke, openmetadata_ingest_postgres, mongo_seed_customers, spark_mongo_to_iceberg])
