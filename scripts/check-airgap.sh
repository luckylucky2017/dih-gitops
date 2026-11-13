#!/bin/bash
# Kiểm tra repo không tham chiếu registry công cộng (môi trường air-gapped 100%).
# Cho phép đường dẫn mirror trong Harbor dạng "mirror/docker.io/..." (không tính là registry công cộng).
cd "$(dirname "$0")/.." || exit 2
PAT='(?<!mirror/)(?<![A-Za-z0-9.-])(docker\.io|index\.docker\.io|registry-1\.docker\.io|quay\.io|ghcr\.io|registry\.k8s\.io|k8s\.gcr\.io|gcr\.io|registry\.redhat\.io|public\.ecr\.aws|mcr\.microsoft\.com|registry\.connect\.redhat\.com)/'
ALLOW=scripts/airgap-allow.txt
touch "$ALLOW"
HITS=$(grep -rnP "$PAT" envs apps src bootstrap mirror 2>/dev/null \
  --include='*.yaml' --include='*.yml' --include='Containerfile*' --include='Dockerfile*' --include='*.sh' --include='*.tpl' \
  | grep -v 'harbor\.ocp\.example\.local' | grep -vE '^[^:]+:[0-9]+:\s*#' | grep -vE '\.bak' \
  | { [ -s "$ALLOW" ] && grep -vEf "$ALLOW" || cat; })
if [ -n "$HITS" ]; then
  echo "AIRGAP FAIL - tham chiếu registry công cộng:"; echo "$HITS"; exit 1
fi
echo "AIRGAP OK"
