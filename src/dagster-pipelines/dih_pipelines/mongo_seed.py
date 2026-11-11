import os
from datetime import datetime, timezone

from dagster import AssetExecutionContext, Failure, MaterializeResult, asset

# Dữ liệu giả, chỉ dùng cho lab.
SAMPLE = [
    {"_id": "C001", "name": "Nguyen Van A", "segment": "retail",    "city": "Hanoi",  "balance_band": "B2"},
    {"_id": "C002", "name": "Tran Thi B",   "segment": "sme",       "city": "HCMC",   "balance_band": "B3"},
    {"_id": "C003", "name": "Le Van C",     "segment": "retail",    "city": "Danang", "balance_band": "B1"},
    {"_id": "C004", "name": "Pham Thi D",   "segment": "corporate", "city": "Hanoi",  "balance_band": "B4"},
    {"_id": "C005", "name": "Hoang Van E",  "segment": "retail",    "city": "HCMC",   "balance_band": "B2"},
]


def _client():
    from pymongo import MongoClient

    for k in ("MONGO_HOST", "MONGO_USER", "MONGO_PASSWORD"):
        if not os.environ.get(k):
            raise Failure(f"Thiếu biến môi trường {k}")
    return MongoClient(
        host=os.environ["MONGO_HOST"],
        port=27017,
        username=os.environ["MONGO_USER"],
        password=os.environ["MONGO_PASSWORD"],
        authSource="dih_lab",
        replicaSet="rs0",
        tls=True,
        tlsCAFile=os.environ.get("MONGO_CA_FILE", "/ca/ca.crt"),
        serverSelectionTimeoutMS=10000,
    )


@asset(group_name="mongo")
def mongo_seed_customers(context: AssetExecutionContext) -> MaterializeResult:
    """Upsert 5 khách hàng mẫu vào dih_lab.customers (chạy lại không nhân đôi)."""
    coll = _client()["dih_lab"]["customers"]
    now = datetime.now(timezone.utc)
    for doc in SAMPLE:
        fields = {k: v for k, v in doc.items() if k != "_id"}
        fields["updated_at"] = now
        coll.update_one({"_id": doc["_id"]}, {"$set": fields}, upsert=True)
    n = coll.count_documents({})
    context.log.info(f"dih_lab.customers: {n} tài liệu")
    return MaterializeResult(metadata={"documents": n})
