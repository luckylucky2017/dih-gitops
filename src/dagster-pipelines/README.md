# dagster-pipelines

Ảnh code location Dagster (dih-pipelines). Tag hiện tại: uat-006.

Build trên helper (có Internet), đẩy lên Harbor:

    cd src/dagster-pipelines
    podman build -t harbor.ocp.example.local/mirror/dih/dagster-pipelines:<tag> -f Containerfile .
    podman push --authfile /root/harbor-auth.json harbor.ocp.example.local/mirror/dih/dagster-pipelines:<tag>

Sau khi đẩy: đổi tag ở CẢ HAI file envs/uat/dagster/values.yaml (code location)
và envs/uat/dagster/values-images.yaml (pipelineRun.image.tag).

Không để secret trong thư mục này: OM_TOKEN và PG_METADATA_PASSWORD lấy từ Secret của cụm.
