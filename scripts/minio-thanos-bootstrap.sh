#!/bin/bash
# Tạo bucket thanos, user thanos (quyền giới hạn bucket thanos) và Secret thanos-objstore (ns dih-obs).
# Không in khóa ra màn hình. Chạy lại được nhiều lần.
set -euo pipefail
MC=/root/tools/gobin/mc
EP=10.1.67.193:9000
RP=$(podman inspect minio-lab --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^MINIO_ROOT_PASSWORD=//p')
RU=$(podman inspect minio-lab --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^MINIO_ROOT_USER=//p')
[ -n "$RP" ] && [ -n "$RU" ] || { echo "Không đọc được khóa root của minio-lab"; exit 1; }
export MC_HOST_lab="http://${RU}:${RP}@${EP}"
$MC ls lab >/dev/null && echo "kết nối MinIO: OK"
$MC mb --ignore-existing lab/thanos
POL=$(mktemp); umask 077
cat > "$POL" <<JSON
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":["s3:ListBucket","s3:GetBucketLocation"],"Resource":["arn:aws:s3:::thanos"]},
 {"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:AbortMultipartUpload","s3:ListMultipartUploadParts"],"Resource":["arn:aws:s3:::thanos/*"]}
]}
JSON
$MC admin policy create lab thanos-rw "$POL" >/dev/null && echo "policy thanos-rw: OK"
rm -f "$POL"
if oc -n dih-obs get secret thanos-objstore >/dev/null 2>&1; then
  echo "Secret thanos-objstore đã có, bỏ qua tạo user/secret (xóa Secret nếu muốn tạo lại khóa)"
  exit 0
fi
TSK=$(openssl rand -hex 24)
$MC admin user add lab thanos "$TSK" >/dev/null
$MC admin policy attach lab thanos-rw --user thanos >/dev/null && echo "user thanos + policy: OK"
OBJ=$(mktemp)
cat > "$OBJ" <<YAML
type: S3
config:
  bucket: thanos
  endpoint: ${EP}
  access_key: thanos
  secret_key: ${TSK}
  insecure: true
YAML
oc -n dih-obs create secret generic thanos-objstore --from-file=objstore.yml="$OBJ" --dry-run=client -o yaml | oc apply -f - >/dev/null
rm -f "$OBJ"
export MC_HOST_thanos="http://thanos:${TSK}@${EP}"
echo "== kiểm tra quyền của user thanos =="
echo "tmp" | $MC pipe thanos/thanos/_selftest.txt >/dev/null && echo "ghi vào thanos: OK"
$MC rm thanos/thanos/_selftest.txt >/dev/null && echo "xóa trong thanos: OK"
if $MC ls thanos/curated >/dev/null 2>&1; then echo "CẢNH BÁO: user thanos đọc được bucket curated"; exit 1; else echo "bucket curated: bị chặn đúng"; fi
echo "xong"
