#!/usr/bin/env bash
# Thu phiên bản đang chạy làm cơ sở tham chiếu tương thích. Chỉ đọc, không in bí mật.
set -u
OUT="docs/version-snapshot-$(date +%F).txt"
{
echo "# Bản chụp phiên bản - $(date '+%F %H:%M %Z')"
echo "## Git"; git log -1 --format='%h %s'
echo "## OpenShift"
oc get clusterversion version -o jsonpath='{.status.desired.version}{"\n"}'
oc get nodes -o custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,OS:.status.nodeInfo.osImage,KERNEL:.status.nodeInfo.kernelVersion,CRIO:.status.nodeInfo.containerRuntimeVersion,IP:.status.addresses[0].address
echo "## CRD prometheus-operator (OCP)"
oc get crd prometheuses.monitoring.coreos.com -o jsonpath='{.metadata.annotations.operator\.prometheus\.io/version}{"\n"}'
echo "## Operator OLM (tên, trạng thái)"
oc get csv -A --no-headers 2>/dev/null | awk '{print $2, $NF}' | sort -u
echo "## Helm release (tên ns chart appVersion)"
helm list -A -o json | python3 -c 'import sys,json; [print(x["name"],x["namespace"],x["chart"],x["app_version"]) for x in json.load(sys.stdin)]'
echo "## Application ArgoCD (tên sync health revision)"
oc -n openshift-gitops get applications -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REV:.status.sync.revision --no-headers | awk '{print $1,$2,$3,substr($4,1,7)}'
echo "## Image đang chạy (image | digest | namespace) - dih-* và cnpg-system"
oc get pods -A -o json | python3 -c '
import sys,json
d=json.load(sys.stdin); seen={}
for p in d["items"]:
    ns=p["metadata"]["namespace"]
    if not (ns.startswith("dih-") or ns=="cnpg-system"): continue
    st=p["status"].get("containerStatuses",[])+p["status"].get("initContainerStatuses",[])
    for cs in st:
        dg=cs.get("imageID","").split("@")[-1][:19]
        seen.setdefault((cs["image"],dg),set()).add(ns)
for (img,dg),ns in sorted(seen.items()): print(img,"|",dg,"|",",".join(sorted(ns)))'
echo "## Helper"
cat /etc/redhat-release; uname -r
oc version --client 2>/dev/null | head -2; helm version --short
podman --version; skopeo --version; go version 2>/dev/null
/root/tools/gobin/mc --version 2>/dev/null | head -1
dnsmasq --version 2>/dev/null | head -1; haproxy -v 2>/dev/null | head -1
podman ps --format '{{.Names}} {{.Image}}'
echo "## Harbor"
curl -sk https://harbor.ocp.example.local/api/v2.0/systeminfo | python3 -c 'import sys,json; print("harbor", json.load(sys.stdin).get("harbor_version"))' 2>&1 | head -2
echo "## VM MongoDB 10.1.67.194"
ssh -o BatchMode=yes -o ConnectTimeout=6 10.1.67.194 'cat /etc/redhat-release; uname -r; mongod --version | head -1; mongosh --version 2>/dev/null' 2>&1 | head -6
} 2>&1 | tee "$OUT"
echo; echo "đã lưu: $OUT ($(wc -l < "$OUT") dòng)"
