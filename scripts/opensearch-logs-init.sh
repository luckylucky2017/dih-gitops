#!/usr/bin/env bash
# Idempotent: index template (1 shard, 0 replica) + ISM xoá index dih-logs-* sau N ngày.
# Chạy: oc -n dih-obs exec -i opensearch-logs-0 -c opensearch -- bash -s < scripts/opensearch-logs-init.sh
set -u
RET="${RETENTION_DAYS:-7}"
OS=http://localhost:9200
H='Content-Type: application/json'

echo "== index template dih-logs =="
curl -s -XPUT "$OS/_index_template/dih-logs" -H "$H" --data-binary @- <<JSON
{"index_patterns":["dih-logs-*"],"priority":100,
 "template":{"settings":{"index":{"number_of_shards":1,"number_of_replicas":0}}}}
JSON
echo

echo "== ISM policy dih-logs-retention (${RET} ngày) =="
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$OS/_plugins/_ism/policies/dih-logs-retention")
if [ "$CODE" = "200" ]; then
  echo "đã tồn tại, giữ nguyên (đổi thời hạn: sửa tay qua API _plugins/_ism/policies)"
else
  curl -s -XPUT "$OS/_plugins/_ism/policies/dih-logs-retention" -H "$H" --data-binary @- <<JSON | head -c 200
{"policy":{"description":"DIH logs: xoá sau ${RET} ngày","default_state":"hot",
 "states":[{"name":"hot","actions":[],"transitions":[{"state_name":"delete","conditions":{"min_index_age":"${RET}d"}}]},
           {"name":"delete","actions":[{"delete":{}}],"transitions":[]}],
 "ism_template":[{"index_patterns":["dih-logs-*"],"priority":100}]}}
JSON
  echo
fi

echo "== áp dụng cho index đã có =="
curl -s -XPUT "$OS/dih-logs-*/_settings" -H "$H" -d '{"index":{"number_of_replicas":0}}'; echo
curl -s -XPOST "$OS/_plugins/_ism/add/dih-logs-*" -H "$H" -d '{"policy_id":"dih-logs-retention"}' | head -c 200; echo

echo "== kết quả =="
curl -s "$OS/_cat/indices/dih-logs-*?v"
