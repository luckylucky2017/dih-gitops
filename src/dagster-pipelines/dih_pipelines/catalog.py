import os
from pathlib import Path

import yaml
from dagster import asset

_NEEDED = ("OM_TOKEN", "PG_METADATA_PASSWORD")


@asset(group_name="catalog")
def openmetadata_ingest_postgres(context):
    """Đưa metadata của iceberg_catalog (dih-pg) vào OpenMetadata."""
    missing = [k for k in _NEEDED if not os.environ.get(k)]
    if missing:
        raise RuntimeError(f"thieu bien moi truong: {missing}")
    from metadata.workflow.metadata import MetadataWorkflow

    text = (Path(__file__).parent / "ingestion" / "postgres.yaml").read_text()
    cfg = yaml.safe_load(os.path.expandvars(text))
    wf = MetadataWorkflow.create(cfg)
    wf.execute()
    wf.raise_from_status()
    wf.print_status()
    wf.stop()
