# AI Agent Guide – Vulcano Cluster Setup

Diese Anleitung beschreibt alle kritischen Punkte beim Aufsetzen und Betreiben von MongoDB und RabbitMQ für Vulcano in einem RKE2-Kubernetes-Cluster. Sie basiert auf tatsächlich aufgetretenen Fehlern und deren Lösungen.

---

## Cluster-Fakten (Surfplanet)

| Parameter | Wert |
|-----------|------|
| `KUBECONFIG` | `/Users/r.hutter/.kube/rancher.surfplanet.yaml` |
| Cluster-Nodes (IPs) | `10.10.10.35`, `10.10.10.46`, `10.10.10.51`, `10.10.10.80` |
| Shared-Services Namespace | `vulcano-common` |
| Helm Release Name (Shared) | **`vulcano-shared`** ← nicht `vulcano-common`! |
| Helm Release Name (App) | `vulcano-test` (Namespace `vulcano-test`) |
| Helm Chart Pfad | `/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart` |
| Values Shared | `deployments/vulcano-common/values.yaml` + `values.secret.yaml` |
| Values App | `deployments/vulcano-test/values.yaml` + `values.secret.yaml` |

> **⚠️ Wichtig:** Der Helm Release-Name für Shared Services muss `vulcano-shared` sein (nicht `vulcano-common`).
> Helm nutzt den Release-Namen als Label `app.kubernetes.io/instance` — und der `rabbitmq-external`-NodePort-Selector
> referenziert dieses Label. Falscher Release-Name → keine Endpoints → keine Verbindung.

---

## 1. MongoDB ReplicaSet

### Problem
Der `cloudpirates/mongodb` Sub-Chart **initiiert den ReplicaSet nicht automatisch**. Nach dem ersten `helm install` laufen alle 3 Pods einzeln ohne RS-Verbindung. Vulcano startet aber, läuft jedoch ohne ReplicaSet-Features (kein Primary-Failover).

### Erkennung
```bash
kubectl exec -it mongodb-0 -n vulcano-common -- mongosh \
  -u admin -p <rootPassword> --authenticationDatabase admin \
  --eval 'rs.status().ok'
# Gibt 0 zurück wenn RS nicht initiiert
```

### Lösung: RS einmalig manuell initiieren
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

Verifizieren (nach ~10s):
```bash
kubectl exec -it mongodb-0 -n vulcano-common -- mongosh \
  -u admin -p <rootPassword> --authenticationDatabase admin \
  --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
# Erwartete Ausgabe: einer PRIMARY, zwei SECONDARY
```

### Konfiguration in values.yaml
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

> **`resourcePolicy: keep`** verhindert, dass die PVCs bei `helm uninstall` gelöscht werden. Nie ohne diesen Wert deployen!

---

## 2. RabbitMQ Cluster

### Problem: Peer Discovery MUSS aktiviert werden
Ohne `peerDiscoveryK8sPlugin.enabled: true` starten alle 3 RabbitMQ-Pods als **völlig isolierte Standalone-Instanzen**. Sie kennen sich nicht. Jeder Pod hat seine eigene Queue-Welt.

**Symptome:**
- Verbindungen „kommen und gehen" (Rendernode verbindet sich Round-Robin zu verschiedenen Pods)
- Queues erscheinen und verschwinden
- Manchmal gibt es `vulcano.jobs`, manchmal nicht
- Management-UI zeigt je nach getrofftem Pod unterschiedliche Cluster-Größe (1 statt 3)

**Diagnose:**
```bash
# Mehrfach abfragen – zeigt je nach Pod verschiedene Antworten bei FEHLER:
for i in 1 2 3 4 5; do
  curl -s -u "vulcano:<password>" "http://10.10.10.35:31672/api/nodes" | \
    python3 -c "import json,sys; n=json.load(sys.stdin); print(len(n), [x['name'].split('.')[0].split('@')[1] for x in n])"
  sleep 1
done
# FEHLER: gibt mal "1 ['rabbitmq-0']", mal "1 ['rabbitmq-1']", mal "1 ['rabbitmq-2']" zurück
# OK:     gibt immer "3 ['rabbitmq-0', 'rabbitmq-1', 'rabbitmq-2']" zurück
```

### Lösung: Peer Discovery aktivieren
```yaml
rabbitmq:
  enabled: true
  fullnameOverride: "rabbitmq"
  replicaCount: 3

  auth:
    username: "vulcano"
    existingErlangCookieKey: "erlang-cookie"   # ← cloudpirates sub-chart key name
    existingPasswordKey: "password"             # ← cloudpirates sub-chart key name

  # ↓ PFLICHT – ohne das kein echter Cluster
  peerDiscoveryK8sPlugin:
    enabled: true
    addressType: hostname

  rbac:
    create: true        # Peer Discovery braucht RBAC (endpoints lesen)
  serviceAccount:
    create: true

  service:
    type: ClusterIP

  persistence:
    enabled: false      # RabbitMQ-Daten sind flüchtig, queues werden von App neu deklariert

  metrics:
    enabled: false
```

> **`existingErlangCookieKey: "erlang-cookie"`** und **`existingPasswordKey: "password"`**: Der cloudpirates Sub-Chart schreibt die Secret-Keys ohne `rabbitmq-` Prefix. Die Defaults des Hauptcharts (`rabbitmq-erlang-cookie`, `rabbitmq-password`) passen nicht — diese Overrides sind zwingend notwendig.

### Neuinstallation bei beschädigtem Cluster-Zustand

Wenn die Pods isoliert laufen und `helm upgrade` nicht hilft:

```bash
# 1. StatefulSet löschen (Pods werden mitgelöscht, PVCs bleiben - aber persistence=false)
kubectl --kubeconfig /Users/r.hutter/.kube/rancher.surfplanet.yaml \
  delete statefulset rabbitmq -n vulcano-common

# 2. Altes Secret + ConfigMap löschen
kubectl --kubeconfig /Users/r.hutter/.kube/rancher.surfplanet.yaml \
  delete secret rabbitmq configmap rabbitmq-config -n vulcano-common --ignore-not-found

# 3. Helm-Release-Status prüfen (könnte "failed" sein nach abgebrochenem Upgrade)
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml helm ls -n vulcano-common

# 4. Falls "failed": rollback auf letzte funktionierende Revision
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml \
  helm rollback vulcano-shared <revision> -n vulcano-common

# 5. Dann normales Upgrade
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml helm upgrade vulcano-shared \
  "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart" \
  --namespace vulcano-common \
  --values "deployments/vulcano-common/values.yaml" \
  --values "deployments/vulcano-common/values.secret.yaml"
```

---

## 3. RabbitMQ NodePort für externe Rendernodes

Rendernodes laufen außerhalb des Clusters und müssen RabbitMQ über eine feste Node-IP + Port erreichen.

### Warum extraObjects statt Sub-Chart-Service?
Der Sub-Chart ignoriert `nodePorts`-Werte im `service`-Block. Die einzige zuverlässige Methode ist ein separater Service via `extraObjects`.

### Konfiguration
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
        app.kubernetes.io/instance: vulcano-shared   # ← BEIDE Labels nötig!
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

> **`app.kubernetes.io/instance: vulcano-shared`** ist kritisch. Fehlt dieses Label, hat der Service keine Endpoints (0 Pods selektiert). Der Wert muss dem Helm Release-Namen entsprechen.

### Connectivity-Test
```bash
# TCP-Erreichbarkeit
nc -z -w 3 10.10.10.35 32672 && echo "OK" || echo "FEHLER"

# AMQP-Auth-Test (Python/pika oder über Management API)
curl -s -u "vulcano:<password>" "http://10.10.10.35:31672/api/whoami"
# Erwartete Ausgabe: {"name":"vulcano","tags":["administrator"]}
```

### Rendernode application.properties
```properties
spring.rabbitmq.addresses=10.10.10.35:32672,10.10.10.46:32672,10.10.10.51:32672,10.10.10.80:32672
spring.rabbitmq.username=vulcano
spring.rabbitmq.password=<password>
spring.rabbitmq.virtual-host=/
```

> **`spring.rabbitmq.addresses`** (Plural mit mehreren IPs): Aktiviert den Multi-Address-Pfad in `RabbitMQConnectionConfig.java`. **Nicht** `spring.rabbitmq.host` verwenden — das geht nur zu einem einzigen Pod.

---

## 4. Cluster-Gesundheit verifizieren

### Schnellcheck: Alles OK?
```bash
PASSWORD="wlIXjp0cBI9m4bNSqNjx35A9qATjz3n"

echo "=== Pods ==="
kubectl --kubeconfig /Users/r.hutter/.kube/rancher.surfplanet.yaml get pods -n vulcano-common

echo "=== RabbitMQ Cluster ==="
curl -s -u "vulcano:$PASSWORD" "http://10.10.10.35:31672/api/nodes" | python3 -c "
import json,sys
nodes=json.load(sys.stdin)
print(f'Nodes: {len(nodes)} (erwartet: 3)')
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

**Erwartetes Ergebnis:**
- 3 Pods: `rabbitmq-0/1/2` alle `1/1 Running`
- 3 Cluster-Nodes, alle `running=True`, `partitions=[]`
- Queues `vulcano.jobs` und `vulcano-job-updates` im Zustand `running`

---

## 5. Standard Helm-Upgrade-Befehl

```bash
# Shared Services
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml helm upgrade vulcano-shared \
  "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart" \
  --namespace vulcano-common \
  --values "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart/deployments/vulcano-common/values.yaml" \
  --values "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart/deployments/vulcano-common/values.secret.yaml"

# Vulcano App (vulcano-test)
KUBECONFIG=/Users/r.hutter/.kube/rancher.surfplanet.yaml helm upgrade vulcano-test \
  "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart" \
  --namespace vulcano-test \
  --values "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart/deployments/vulcano-test/values.yaml" \
  --values "/Users/r.hutter/Resilio Sync/_Workspace/git/vulcano-helm-chart/deployments/vulcano-test/values.secret.yaml"
```

> **Immer den lokalen Chart-Pfad verwenden**, nicht den publizierten Chart — der lokale enthält alle Bugfixes.

---

## 6. Häufige Fehler und deren Ursachen

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| RabbitMQ Queues kommen und gehen | `peerDiscoveryK8sPlugin.enabled: false` — 3 Standalone-Instanzen | `enabled: true` setzen, StatefulSet neu erstellen |
| `rabbitmq-external` hat keine Endpoints | Selector fehlt `app.kubernetes.io/instance: vulcano-shared` | Selector ergänzen |
| Rendernode `ACCESS_REFUSED` | `spring.rabbitmq.host` statt `spring.rabbitmq.addresses` → Single-Adress-Pfad | `addresses` mit allen 4 Node-IPs konfigurieren |
| `helm upgrade` schlägt fehl mit "ownership conflict" | Falscher Release-Name (z.B. `vulcano-common` statt `vulcano-shared`) | Immer Release-Name `vulcano-shared` verwenden |
| MongoDB-Verbindungsfehler `not primary` | RS nicht initiiert | `rs.initiate()` manuell ausführen |
| `helm upgrade` Status: `failed` | Vorheriges Upgrade abgebrochen | `helm rollback vulcano-shared <letzte-ok-revision>` dann neu upgraden |
