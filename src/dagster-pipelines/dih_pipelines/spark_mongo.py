import time
from pathlib import Path

import yaml
from dagster import AssetExecutionContext, Failure, MaterializeResult, asset
from kubernetes import client, config

from .mongo_seed import mongo_seed_customers

NS = "dih-proc"
GROUP, VERSION, PLURAL = "sparkoperator.k8s.io", "v1beta2", "sparkapplications"
TERMINAL_OK = {"COMPLETED"}
TERMINAL_BAD = {"FAILED", "SUBMISSION_FAILED", "FAILING", "INVALIDATING", "UNKNOWN"}
TIMEOUT_S = 900


@asset(group_name="spark", deps=[mongo_seed_customers])
def spark_mongo_to_iceberg(context: AssetExecutionContext) -> MaterializeResult:
    """Chạy job Spark: đọc dih_lab.customers từ MongoDB, ghi bảng Iceberg dih.curated.customers."""
    config.load_incluster_config()
    api = client.CustomObjectsApi()

    body = yaml.safe_load((Path(__file__).parent / "mongo-iceberg.yaml").read_text())
    name = f"mongo-iceberg-{context.run_id[:8]}"
    body["metadata"]["name"] = name
    body["metadata"]["namespace"] = NS
    body["metadata"].setdefault("labels", {})["dagster/run-id"] = context.run_id

    api.create_namespaced_custom_object(GROUP, VERSION, NS, PLURAL, body)
    context.log.info(f"Submitted SparkApplication {name}")

    state, start = "", time.time()
    while time.time() - start < TIMEOUT_S:
        obj = api.get_namespaced_custom_object(GROUP, VERSION, NS, PLURAL, name)
        state = (obj.get("status", {}).get("applicationState", {}) or {}).get("state", "")
        context.log.info(f"{name}: {state or 'PENDING'}")
        if state in TERMINAL_OK:
            api.delete_namespaced_custom_object(GROUP, VERSION, NS, PLURAL, name)
            return MaterializeResult(metadata={"spark_application": name, "state": state, "table": "dih.curated.customers"})
        if state in TERMINAL_BAD:
            # giữ lại SparkApplication để điều tra
            raise Failure(f"SparkApplication {name} kết thúc với trạng thái {state}")
        time.sleep(10)

    raise Failure(f"SparkApplication {name} quá {TIMEOUT_S}s, trạng thái cuối: {state or 'PENDING'}")
