#!/bin/bash
# Dùng: mirror-images.sh <file danh sách image>  (mỗi dòng: registry/path:tag)
# Đích:  harbor.ocp.example.local/mirror/<registry>/<path>:<tag>
set -uo pipefail
LIST="$1"; DEST=harbor.ocp.example.local/mirror; AUTH=/root/harbor-auth.json
ok=0; skip=0; fail=0
while read -r src; do
  [ -z "$src" ] && continue
  dst="$DEST/$src"
  if skopeo inspect --raw --authfile "$AUTH" "docker://$dst" >/dev/null 2>&1; then
    echo "SKIP (đã có): $dst"; skip=$((skip+1)); continue
  fi
  echo "COPY: $src -> $dst"
  if skopeo copy --all --authfile "$AUTH" "docker://$src" "docker://$dst"; then ok=$((ok+1)); else echo "LỖI: $src"; fail=$((fail+1)); fi
done < "$LIST"
echo "xong: copy=$ok bỏ qua=$skip lỗi=$fail"
[ "$fail" -eq 0 ]
