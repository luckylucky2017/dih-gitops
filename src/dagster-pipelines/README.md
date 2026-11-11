# dagster-pipelines

Ảnh code location Dagster (dih-pipelines). Tag hiện tại: uat-006.

Build trên helper (có Internet), đẩy lên Harbor:

    cd src/dagster-pipelines
    podman build -t harbor.ocp.example.local/mirror/dih/dagster-pipelines:<tag> -f Containerfile .
    podman push --authfile /root/harbor-auth.json harbor.ocp.example.local/mirror/dih/dagster-pipelines:<tag>

Sau khi đẩy: đổi tag ở CẢ HAI file envs/uat/dagster/values.yaml (code location)
và envs/uat/dagster/values-images.yaml (pipelineRun.image.tag).

Không để secret trong thư mục này: OM_TOKEN và PG_METADATA_PASSWORD lấy từ Secret của cụm.

## Spark smoke (ConfigMap smoke-py)

Mã nằm ở spark/smoke.py, không có trong ảnh. Tạo lại ConfigMap (idempotent):

    oc -n dih-proc create configmap smoke-py \
      --from-file=smoke.py=src/dagster-pipelines/spark/smoke.py \
      --dry-run=client -o yaml | oc apply -f -

## Build không cần Internet (wheelhouse, dùng cho air-gapped)

PyPI từ helper đôi khi chập chờn (ReadTimeout), nên tải trước gói về thư mục ngoài Git:

    BASE=harbor.ocp.example.local/mirror/docker.io/library/python:3.12.16-slim
    podman run --rm --network=host -v /root/wheelhouse-uat007:/w:Z -v /root/pipcache:/root/.cache/pip:Z \
      $BASE pip wheel --retries 10 --timeout 120 -w /w <đúng danh sách gói trong Containerfile> setuptools wheel

Build từ thư mục đó, không có mạng:

    podman build --network=none --build-arg PIP_ARGS="--no-index --find-links /wheels" \
      -v /root/wheelhouse-uat007:/wheels:ro,Z -t <ảnh> -f Containerfile .

Không truyền --build-arg thì Containerfile cài trực tiếp từ PyPI (có retries/timeout).
Thư mục wheelhouse (khoảng 175 MB) KHÔNG đưa vào Git; ở VCB tạo nó từ mirror PyPI nội bộ.
