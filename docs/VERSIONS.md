# Phiên bản đã khoá trên lab DIH (04/11/2026)

Lấy trực tiếp từ cụm bằng lệnh kiểm kê. Đây là bản chuẩn khi mâu thuẫn với tài liệu cài đặt mục 0.9.
Trước khi cài mới hoặc nâng cấp, đối chiếu bảng này và các quy tắc ở cuối. Khi chuyển sang VCB, ghi lại digest thực tế.

## Nền tảng và công cụ

| Thành phần | Phiên bản đang chạy | Ghi chú |
| --- | --- | --- |
| OpenShift | 4.20.42 (kubelet v1.33.13, CRI-O 1.33.13) | UPI, 3 master + 3 worker |
| Hệ điều hành node | RHCOS 9.6.20261002-0, kernel 5.14.0-570.147.1.el9_6 | giống nhau trên 6 node |
| Helper | RHEL 9.8 | DNS, HAProxy, MinIO tạm, nơi chạy oc/helm |
| oc | 4.20.42 (Kustomize v5.6.0) | trùng phiên bản cụm |
| Helm | v3.16.4 | |
| podman / skopeo | 5.8.2 / 1.22.2 | |
| oc-mirror | dùng --v2 | bản v1 đã deprecated; từ 4.21 bắt buộc chỉ định --v1 hoặc --v2 |
| OpenShift GitOps (OLM) | openshift-gitops-operator.v1.22.2 | ArgoCD, Dex, Redis 7, console plugin từ registry.redhat.io theo digest, qua IDMS |
| LVM Storage (OLM) | lvms-operator.v4.20.2 | StorageClass lvms-vg1 |

## Dịch vụ DIH

| Dịch vụ | Chart / operator | Ảnh và tag | Cách cài |
| --- | --- | --- | --- |
| CloudNativePG | chart cloudnative-pg 0.29.1, operator 1.30.1 | cloudnative-pg:1.30.1; postgresql:17.11 (Debian 17.11-1.pgdg11+2, chỉ extension plpgsql) | Helm cnpg, ns cnpg-system |
| Keycloak | Operator 26.8.1, CRD k8s.keycloak.org/v2beta1 | keycloak:26.8.1, keycloak-operator:26.8.1 | manifest |
| OPA | | opa:1.22.0-static | manifest |
| Dagster | chart dagster 1.13.28 | webserver, daemon: dagster-k8s:1.13.28; code location: dih/dagster-pipelines:uat-005 | ArgoCD dih-uat-dagster |
| oauth2-proxy | | oauth2-proxy:v7.15.5 | ArgoCD dih-uat-dagster-auth |
| Spark Operator | chart và ảnh 2.5.2 (controller và webhook dùng chung ảnh) | spark-operator/controller:2.5.2 | ArgoCD dih-uat-spark-operator |
| Spark runtime | | dih/spark-iceberg:4.0.5-ice1.12.0-oc1 (không Python, SparkPi) và ...-py-oc1 (có Python, smoke) | SparkApplication |
| MinIO tạm | | pgsty/minio RELEASE.2026-08-04T00-00-00Z; pgsty/mc RELEASE.2026-10-26T00-00-00Z | podman minio-lab trên helper; giấy phép AGPLv3 |
| Starburst, Kafka, Prometheus, OpenMetadata | | | chưa cài |

## Bộ phụ thuộc bên trong ảnh

| Ảnh | Thành phần và phiên bản |
| --- | --- |
| dih/spark-iceberg:4.0.5-ice1.12.0-py-oc1 | Spark 4.0.5; Scala 2.13.16; OpenJDK 17.0.20.1; Python 3.10.12; Hadoop client 3.4.1; Guava 33.4.0-jre; Jackson 2.18.6; json4s 4.0.7; iceberg-spark-runtime-4.0_2.13-1.12.0; iceberg-aws-bundle-1.12.0; PostgreSQL JDBC 42.7.14. Không có hadoop-aws: S3 chỉ qua S3FileIO của Iceberg. |
| dagster-k8s:1.13.28 (webserver, daemon) | Python 3.10.22; dagster, dagster-graphql, dagster-webserver, dagster-pipes, dagster-shared 1.13.28; dagster-k8s, dagster-postgres, dagster-aws và các thư viện dagster-* khác 0.29.28; SQLAlchemy 2.0.55; psycopg2-binary 2.9.13; kubernetes 37.0.1; grpcio 1.57.0; protobuf 7.36.2; pydantic 2.14.2 |
| dih/dagster-pipelines:uat-005 (code location, run pod) | Python 3.12.16; dagster 1.13.28; dagster-pipes 1.13.28; dagster-k8s và dagster-postgres 0.29.28; SQLAlchemy 2.0.55; psycopg2-binary 2.9.13; kubernetes 37.0.1; grpcio 1.85.1; protobuf 7.36.2; pydantic 2.14.2 |

## Quy tắc tương thích

- Dagster: lõi 1.N đi với thư viện dagster-* ở dải 0.(N+16) (1.13.28 với 0.29.28). Webserver, daemon, code location và run pod phải cùng lõi 1.13.28 và nâng đồng thời. Python khác nhau giữa webserver (3.10) và code location (3.12) chấp nhận được vì nói chuyện qua gRPC; các gói lệch giữa hai ảnh: grpcio, python-dateutil, filelock, multidict, oauthlib, platformdirs, google-auth, pycparser. Khoá gói của code location bằng file lock (ví dụ uv pip compile) trong images/dagster-pipelines/.
- Spark: Spark 4.0.5 với Scala 2.13 với iceberg-spark-runtime-4.0_2.13 1.12.0 với iceberg-aws-bundle 1.12.0. Không dùng Spark 4.1 hoặc 4.2 cho tới khi có Iceberg runtime tương ứng. Ảnh Spark phải là Java 17. Nếu cần đọc ghi s3a:// (ví dụ checkpoint Structured Streaming), phải thêm hadoop-aws 3.4.1 và AWS SDK bundle tương ứng vào ảnh.
- Spark Operator 2.5.2: CRD sparkoperator.k8s.io/v1beta2; ảnh Spark do spec.image của từng SparkApplication quyết định. Operator chỉ theo dõi namespace dih-proc (--namespaces=dih-proc).
- JDBC PostgreSQL 42.7.14 chạy với PostgreSQL 17.11. Catalog Iceberg dùng chung tên dih cho Spark và Starburst.
- Keycloak: Operator phải trùng số phiên bản với server (26.8.1). Nâng cấp operator và CRD trước, server sau, sao lưu CSDL keycloak trước.
- CloudNativePG: chart 0.29.1 với operator 1.30.1. Ảnh postgresql:17.11 dựa trên Debian 11, đã quá hạn hỗ trợ dài hạn [xác minh]; khi mirror cho VCB chọn tag dựa trên Debian mới hơn và kiểm tra lại runAsUser/runAsGroup.
- Starburst: engine Trino bên trong phải đọc được bảng Iceberg 1.12.0 (format v2) qua JDBC catalog; đối chiếu trước khi mirror.
- Ảnh dagster-pipelines: tag uat-001, uat-003, uat-004 còn được pod run cũ tham chiếu; không xoá khỏi Harbor cho tới khi pod đó được dọn.
- Không thuộc DIH: Helm release nginx-imagestreams (redhat-nginx-imagestreams 0.0.4) trong namespace default.

## Kiểm kê lại khi cần cập nhật

    oc get clusterversion; oc get csv -A; helm list -A
    oc get pods -A -o json | jq -r '.items[].status.containerStatuses[]? | [.image,.imageID] | @tsv' | sort -u
    oc exec -n dih-proc deploy/dagster-dagster-webserver -- pip freeze
    # trong ảnh Spark: /opt/spark/bin/spark-submit --version; ls /opt/spark/jars
