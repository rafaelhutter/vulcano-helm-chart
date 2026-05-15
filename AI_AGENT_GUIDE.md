# AI Agent Guide – Vulcano Cluster Setup

This guide describes every critical step when bringing up and operating MongoDB and RabbitMQ for Vulcano on an RKE2 Kubernetes cluster. It is based on issues we actually hit in production and their fixes.

---

## Cluster facts (Surfplanet)

| Parameter | Value |
|-----------|-------|
| `KUBECONFIG` | `/Users/r.hutter/.kube/rancher.surfplanet.yaml` |
| Cluster nodes (IPs) | `10.10.10.35`, `10.10.10.46`, `10.10.10.51`, `10.10.10.80` |
| Shared-services namespace | `vulcano-common` |
| Helm release name (shared) | **`vulcano-shared`** ← not `vulcano-common`! |
| Helm release name (app) | `vulcano-test` (namespace `vulcano-test`) |
| Helm chart path | `/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart` |
| Shared values | `deployments/vulcano-common/values.yaml` + `values.secret.yaml` |
| App values | `deployments/vulcano-test/values.yaml` + `values.secret.yaml` |

> **⚠️ Important:** The Helm release name for the shared services MUST be `vulcano-shared` (not `vulcano-common`).
> Helm uses the release name as the `app.kubernetes.io/instance` label — and the selector of the
> `rabbitmq-external` NodePort service references that label. Wrong release name → no endpoints → no connection.

---

## 1. MongoDB ReplicaSet

### Problem
The `cloudpirates/mongodb` sub-chart **does not initiate the ReplicaSet automatically**. After the first `helm install` all three pods run standalone with no RS link. Vulcano will start, but without ReplicaSet features (no primary failover).

### Detection
```bash
kubectl exec -it mongodb-0 -n vulcano-common -- mongosh \
  -u admin -p <rootPassword> --authenticationDatabase admin \
  --eval 'rs.status().ok'
# Returns 0 when the RS has not been initiated
```

### Fix: initiate the RS once, manually
```bash
kubectl exec -it mongodb-0 -n vulcano-common -- mongosh \
  -u admin -p <rootPassword> --authenticationDatabase admin \
  --eval 'rs.initiate({
    _id: "rs0",
    members: [
      { _id: 0, host: "mongodb-0.mongodb-headless.vulcano-common.svc.cluster.local:27017" },
      { _id: 1, host: "mongodb-1.mongodb-headless.vulcano-common.svc.cluster.local:27017" },
      { _id: 2, host: "mongodb-2.mongodb-headless.vulcano-common.svc.cluster.local:27017" }
    ]
  })'
```

Verify (after ~10 s):
```bash
kubectl exec -it mongodb-0 -n vulcano-common -- mongosh \
  -u admin -p <rootPassword> --authenticationDatabase admin \
  --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
# Expected output: one PRIMARY, two SECONDARY
```

### `values.yaml` configuration
```yaml
mongodb:
  enabled: true
  fullnameOverride: "mongodb"
  architecture: "replicaset"
  replicaCount: 3
  replicaSet:
    enabled: true
    name: "rs0"
  persistence:
    enabled: true
    size: "20Gi"
    storageClassName: "longhorn"
    resourcePolicy: "keep"
```

> **`resourcePolicy: keep`** prevents the PVCs from being deleted on `helm uninstall`. Never deploy without it!

---

## 2. RabbitMQ cluster

### Problem: peer discovery MUST be enabled
Without `peerDiscoveryK8sPlugin.enabled: true`, all three RabbitMQ pods come up as **completely isolated standalone instances**. They don't know about each other; every pod has its own queue world.

**Symptoms:**
- Connections "come and go" (render nodes round-robin to different pods)
- Queues appear and disappear
- Sometimes `vulcano.jobs` exists, sometimes not
- Management UI shows different cluster sizes depending on which pod you hit (1 instead of 3)

**Diagnosis:**
```bash
# Poll several times — shows different answers per pod when broken:
for i in 1 2 3 4 5; do
  curl -s -u "vulcano:<password>" "http://10.10.10.35:31672/api/nodes" | \
    python3 -c "import json,sys; n=json.load(sys.stdin); print(len(n), [x['name'].split('.')[0].split('@')[1] for x in n])"
  sleep 1
done
# BROKEN: returns "1 ['rabbitmq-0']", then "1 ['rabbitmq-1']", then "1 ['rabbitmq-2']"
# OK:     always returns "3 ['rabbitmq-0', 'rabbitmq-1', 'rabbitmq-2']"
```

### Fix: enable peer discovery
```yaml
rabbitmq:
  enabled: true
  fullnameOverride: "rabbitmq"
  replicaCount: 3

  auth:
    username: "vulcano"
    existingErlangCookieKey: "erlang-cookie"   # ← cloudpirates sub-chart key name
    existingPasswordKey: "password"             # ← cloudpirates sub-chart key name

  # ↓ MANDATORY – without this there is no real cluster
  peerDiscoveryK8sPlugin:
    enabled: true
    addressType: hostname

  rbac:
    create: true        # peer discovery needs RBAC (read endpoints)
  serviceAccount:
    create: true

  service:
    type: ClusterIP

  persistence:
    enabled: false      # RabbitMQ data is transient; queues are re-declared by the app

  metrics:
    enabled: false
```

> **`existingErlangCookieKey: "erlang-cookie"`** and **`existingPasswordKey: "password"`**: the cloudpirates sub-chart writes secret keys **without** the `rabbitmq-` prefix. The main chart's defaults (`rabbitmq-erlang-cookie`, `rabbitmq-password`) do not match — these overrides are mandatory.

### Re-installing after a broken cluster state

If pods are running isolated and `helm upgrade` does not help:

```bash
# 1. Delete the StatefulSet (pods are deleted with it; PVCs remain — but persistence=false anyway)
kubectl --kubeconfig /Users/r.hutter/.kube/rancher.surfplanet.yaml \
  delete statefulset rabbitmq -n vulcano-common

# 2. Delete old Secret + ConfigMap
kubectl --kubeconfig /Users/r.hutter/.kube/rancher.surfplanet.yaml \
  delete secret rabbitmq configmap rabbitmq-config -n vulcano-common --ignore-not-found

# 3. Check Helm release status (may be "failed" after an aborted upgrade)
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml helm ls -n vulcano-common

# 4. If "failed": roll back to the last good revision
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml \
  helm rollback vulcano-shared <revision> -n vulcano-common

# 5. Then run the normal upgrade
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml helm upgrade vulcano-shared \
  "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart" \
  --namespace vulcano-common \
  --values "deployments/vulcano-common/values.yaml" \
  --values "deployments/vulcano-common/values.secret.yaml"
```

---

## 3. RabbitMQ NodePort for external render nodes

Render nodes run outside the cluster and must reach RabbitMQ via a stable node IP + port.

### Why `extraObjects` instead of the sub-chart service?
The sub-chart ignores `nodePorts` values in its `service` block. The only reliable approach is a separate Service via `extraObjects`.

### Configuration
```yaml
extraObjects:
  - apiVersion: v1
    kind: Service
    metadata:
      name: rabbitmq-external
      namespace: "vulcano-common"
    spec:
      type: NodePort
      selector:
        app.kubernetes.io/name: rabbitmq
        app.kubernetes.io/instance: vulcano-shared   # ← BOTH labels required!
      ports:
        - name: amqp
          port: 5672
          targetPort: amqp
          nodePort: 32672
        - name: management
          port: 15672
          targetPort: mgmt
          nodePort: 31672
```

> **`app.kubernetes.io/instance: vulcano-shared`** is critical. Without it the Service has no endpoints (0 pods selected). The value must equal the Helm release name.

### Connectivity test
```bash
# TCP reachability
nc -z -w 3 10.10.10.35 32672 && echo "OK" || echo "FAIL"

# AMQP auth test (Python/pika or via the management API)
curl -s -u "vulcano:<password>" "http://10.10.10.35:31672/api/whoami"
# Expected output: {"name":"vulcano","tags":["administrator"]}
```

### Render node `application.properties`
```properties
spring.rabbitmq.addresses=10.10.10.35:32672,10.10.10.46:32672,10.10.10.51:32672,10.10.10.80:32672
spring.rabbitmq.username=vulcano
spring.rabbitmq.password=<password>
spring.rabbitmq.virtual-host=/
```

> **`spring.rabbitmq.addresses`** (plural, multiple IPs) activates the multi-address path in `RabbitMQConnectionConfig.java`. **Do not** use `spring.rabbitmq.host` — that only ever talks to a single pod.

---

## 4. Verifying cluster health

### Quick check: is everything OK?
```bash
PASSWORD="<password>"   # set this to the RabbitMQ admin password

echo "=== Pods ==="
kubectl --kubeconfig /Users/r.hutter/.kube/rancher.surfplanet.yaml get pods -n vulcano-common

echo "=== RabbitMQ cluster ==="
curl -s -u "vulcano:$PASSWORD" "http://10.10.10.35:31672/api/nodes" | python3 -c "
import json,sys
nodes=json.load(sys.stdin)
print(f'Nodes: {len(nodes)} (expected: 3)')
for n in nodes:
  print(f\"  {n['name'].split('.')[0].split('@')[1]}: running={n['running']}, partitions={n['partitions']}\")
"

echo "=== Queues ==="
curl -s -u "vulcano:$PASSWORD" "http://10.10.10.35:31672/api/queues" | python3 -c "
import json,sys
queues=json.load(sys.stdin)
for q in queues:
  print(f\"  {q['name']}: state={q.get('state','?')}, consumers={q.get('consumers',0)}, messages={q.get('messages',0)}\")
"
```

**Expected result:**
- 3 pods: `rabbitmq-0/1/2` all `1/1 Running`
- 3 cluster nodes, all `running=True`, `partitions=[]`
- Queues `vulcano.jobs` and `vulcano-job-updates` in state `running`

---

## 5. Standard Helm upgrade command

```bash
# Shared services
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml helm upgrade vulcano-shared \
  "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart" \
  --namespace vulcano-common \
  --values "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart/deployments/vulcano-common/values.yaml" \
  --values "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart/deployments/vulcano-common/values.secret.yaml"

# Vulcano app (vulcano-test)
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml helm upgrade vulcano-test \
  "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart" \
  --namespace vulcano-test \
  --values "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart/deployments/vulcano-test/values.yaml" \
  --values "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart/deployments/vulcano-test/values.secret.yaml"
```

> **Always use the local chart path**, not the published chart — the local copy carries the latest bug fixes.

---

## 6. Common failures and their root causes

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| RabbitMQ queues come and go | `peerDiscoveryK8sPlugin.enabled: false` — three standalone instances | Set `enabled: true`, recreate the StatefulSet |
| `rabbitmq-external` has no endpoints | Selector is missing `app.kubernetes.io/instance: vulcano-shared` | Add the missing selector label |
| Render node `ACCESS_REFUSED` | `spring.rabbitmq.host` instead of `spring.rabbitmq.addresses` → single-address path | Configure `addresses` with all four node IPs |
| `helm upgrade` fails with "ownership conflict" | Wrong release name (e.g. `vulcano-common` instead of `vulcano-shared`) | Always use the release name `vulcano-shared` |
| MongoDB connection error `not primary` | RS not initiated | Run `rs.initiate()` manually |
| `helm upgrade` status: `failed` | Previous upgrade aborted | `helm rollback vulcano-shared <last-good-revision>`, then upgrade again |
