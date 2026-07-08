# vulcano

![Version: 1.6.1](https://img.shields.io/badge/Version-1.6.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.9.31](https://img.shields.io/badge/AppVersion-1.9.31-informational?style=flat-square)

Vulcano - Complete application deployment with MongoDB, RabbitMQ, and optional CSI driver

**Homepage:** <https://github.com/rafaelhutter/vulcano-helm-chart>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Moovit | <support@moovit.de> |  |

## Source Code

* <https://github.com/rafaelhutter/vulcano-helm-chart>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://registry-1.docker.io/cloudpirates | mongodb(mongodb) | 0.10.3 |
| oci://registry-1.docker.io/cloudpirates | rabbitmq(rabbitmq) | 0.2.12 |

## Installation

You can either pull the packaged chart from the GitHub Pages helm repo, or clone the source tree and install from disk. Either way, all real credentials live in `install-values.yaml`, which is **gitignored** and never committed.

For a multi-instance deployment (shared MongoDB + RabbitMQ, multiple Vulcano releases pointing at them), see [Shared Services / Multi-Instance Deployment](#shared-services--multi-instance-deployment) further down.

### Option A — install from the helm repo (preferred)

```bash
helm repo add rafaelhutter https://rafaelhutter.github.io/vulcano-helm-chart
helm repo update

# Grab a values template, edit it, then install:
curl -fsSL -o install-values.yaml \
  https://raw.githubusercontent.com/rafaelhutter/vulcano-helm-chart/main/examples/values.yaml
$EDITOR install-values.yaml

helm upgrade vulcano rafaelhutter/vulcano --install \
  -n vulcano-app --create-namespace \
  -f install-values.yaml
```

### Option B — install from a source checkout

#### 1. Clone the repository

```bash
git clone https://github.com/rafaelhutter/vulcano-helm-chart.git
cd vulcano-helm-chart
```

#### 2. Create `install-values.yaml`

`install-values.yaml` is **gitignored** (it holds real credentials). Copy the example template as a starting point and edit it for your environment:

```bash
cp examples/values.yaml install-values.yaml
$EDITOR install-values.yaml
```

The file collects everything in one place — no `--set` flags needed:

```yaml
global:
  namespace: "vulcano-app"
  domain: "vulcano.example.com"

imagePullSecrets:
  enabled: true
  dockerUsername: "moovit"
  dockerPassword: "DOCKER_PAT"            # provided by Moovit

vulcano:
  ingress:
    enabled: true
    hosts:
      - "vulcano.example.com"
    tls:
      enabled: true
      letsencrypt:
        enabled: true
        clusterIssuer: "letsencrypt-prod"
        email: "admin@example.com"
  license:
    key: ""                                # provided by Moovit

mongodb:
  auth:
    rootUsername: "admin"
    rootPassword: "CHANGE_ME"

rabbitmq:
  auth:
    username: "vulcano"
    password: "CHANGE_ME"
    erlangCookie: "RANDOM_LONG_STRING"

auth:
  mode: "MICROSOFT"
  microsoft:
    authority: "https://login.microsoftonline.com/YOUR_TENANT_ID"
    clientId: "YOUR_CLIENT_ID"
```

#### 3. Install the chart

```bash
helm upgrade vulcano --install \
  -n vulcano-app \
  --create-namespace \
  -f install-values.yaml \
  .
```

Or run the bundled wrapper, which does the same thing using `examples/values.yaml`:

```bash
bash examples/install.sh
```

## Advanced Configuration

### Existing Secrets (MongoDB & RabbitMQ)

By default the chart creates Kubernetes Secrets for MongoDB and RabbitMQ credentials from the plaintext values in `values.yaml`.
If you manage secrets externally (e.g. via [Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/), External Secrets Operator, Vault, etc.) you can skip secret creation and point the chart to an existing Secret instead:

```yaml
mongodb:
  auth:
    existingSecret: "bw-mongodb-secrets"       # chart will NOT create a mongodb-credentials Secret
    existingPasswordKey: "mongodb-root-password"
    existingUsernameKey: ""                     # leave empty to use rootUser value directly

rabbitmq:
  auth:
    existingSecret: "bw-rabbitmq-secrets"      # chart will NOT create a rabbitmq-credentials Secret
    existingPasswordKey: "bw-rabbitmq-password"
    existingErlangCookieKey: "bw-rabbitmq-erlang-cookie"
```

### MongoDB Data Preservation Across Upgrades

The `cloudpirates/mongodb` sub-chart provisions its persistent volume via a
StatefulSet `volumeClaimTemplate`. With the chart's `fullnameOverride: "mongodb"`
that produces a PVC named **`data-mongodb-0`** (template name `data` +
StatefulSet name `mongodb` + ordinal `0`).

This matters in two scenarios:

**1. `helm uninstall` followed by `helm install`.**
Kubernetes does **not** delete PVCs created by `volumeClaimTemplates` when the
parent StatefulSet is removed. The PVC (and its underlying PV) survive
`helm uninstall`. When you reinstall the chart with the same release name and
the same `mongodb.fullnameOverride`, the new StatefulSet picks up the existing
`data-mongodb-0` PVC and binds to the existing data automatically — **no
restore step needed**.

**2. Migrating from an older deployment of the same chart family.**
If the cluster already runs a MongoDB deployed via a different chart
(Bitnami, custom Helm, etc.), the existing PVC will have a different name
(typically `datadir-mongodb-0` for Bitnami). Tell the new chart to reuse it:

```yaml
mongodb:
  persistence:
    existingClaim: "datadir-mongodb-0"   # or whatever the existing PVC is called
```

When `existingClaim` is set the sub-chart skips the `volumeClaimTemplate`
entirely and mounts the named PVC as the `data` volume directly.

**Verifying before you deploy**

```bash
kubectl get pvc -n <namespace>
kubectl get statefulset -n <namespace> mongodb \
  -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}'
```

If the PVC list contains `data-mongodb-0` and the second command returns
`data`, a plain `helm upgrade --install` will reuse the existing data.

**Pinning the MongoDB image for byte-for-byte data compatibility**

Each chart release bumps the sub-chart's default Mongo image (e.g. `8.2.4`).
Minor upgrades (`8.0 → 8.2`) are safe under WiredTiger, but if you need an
exact image match for the on-disk data — for instance to restore a backup
from a frozen environment — pin the tag explicitly:

```yaml
mongodb:
  image:
    tag: "8.0.12"
```

**Belt-and-suspenders: take a `mongodump` snapshot before any change**

```bash
MONGO_PW=$(kubectl get secret mongodb -n <ns> \
  -o jsonpath='{.data.mongodb-root-password}' | base64 -d)

STAMP=$(date +%Y%m%d-%H%M)
kubectl exec -n <ns> mongodb-0 -- \
  mongodump --host localhost:27017 -u root -p "$MONGO_PW" \
            --authenticationDatabase admin --db <database> --gzip \
            --archive=/tmp/mongo-${STAMP}.gz

kubectl cp <ns>/mongodb-0:/tmp/mongo-${STAMP}.gz ./mongo-${STAMP}.gz
```

To restore later, copy the archive back to a Mongo pod and run
`mongorestore --gzip --archive=/tmp/mongo-...gz --drop --db <database> ...`
against the new instance.

### Migrating an existing database into the chart

When you move a Vulcano instance from an older/external deployment onto this
chart, the on-disk PVC reuse described above (`existingClaim`) only works if the
old data lives in a PVC the new StatefulSet can adopt. When it doesn't — the
source is a different cluster, a standalone Docker MongoDB, or a managed
database — migrate the data with a logical `mongodump` / `mongorestore`.

> **The Vulcano backend must NOT be running while the restore happens.** A
> running backend reads and writes the database concurrently, which races the
> restore and can corrupt or partially overwrite the imported data. Restore into
> a fresh MongoDB *before* the backend starts, or scale the backend to zero
> first (see step 3).

**1. Dump the source database (old environment)**

Run this against the **source** MongoDB — adjust host, credentials and
`--db` to match the system you are migrating away from:

```bash
STAMP=$(date +%Y%m%d-%H%M)

# Against a Mongo running in Kubernetes:
kubectl exec -n <old-ns> <old-mongo-pod> -- \
  mongodump --host localhost:27017 -u <user> -p <password> \
            --authenticationDatabase admin --db <database> --gzip \
            --archive=/tmp/vulcano-${STAMP}.gz

kubectl cp <old-ns>/<old-mongo-pod>:/tmp/vulcano-${STAMP}.gz ./vulcano-${STAMP}.gz

# …or against a standalone / external Mongo reachable from your machine:
# mongodump --uri "mongodb://<user>:<password>@<host>:27017" \
#           --db <database> --gzip --archive=./vulcano-${STAMP}.gz
```

Keep this archive safe — it is your rollback point.

**2. Deploy the chart (backend will start empty)**

Install/upgrade the release as usual. The new MongoDB comes up empty (or with
whatever the adopted PVC already held). The backend will start and connect to
the empty database — that's fine, you stop it in the next step before restoring.

**3. Stop the Vulcano backend**

Scale the backend deployment to zero so nothing touches the database during the
restore:

```bash
kubectl scale deployment vulcano -n <ns> --replicas=0
kubectl get pods -n <ns> -l app=vulcano   # confirm none Running
```

> Tip: if you control the rollout, you can also skip step 2's backend entirely
> by restoring before the very first deploy — but scaling to zero is the
> reliable, repeatable path.

**4. Restore into the new MongoDB**

Copy the archive to a Mongo pod and `mongorestore` it. On a replica set, target
the **primary**; `--drop` clears the (empty/stale) target collections first:

```bash
NS=<ns>; DB=<database>
MONGO_PW=$(kubectl get secret mongodb -n "$NS" \
  -o jsonpath='{.data.mongodb-root-password}' | base64 -d)

# Find the primary (single-node sets just return mongodb-0):
PRIMARY=$(kubectl exec -n "$NS" mongodb-0 -- \
  mongosh --quiet -u root -p "$MONGO_PW" --authenticationDatabase admin \
    --eval "rs.status().members.find(m => m.stateStr === 'PRIMARY').name" \
  | cut -d. -f1 | tr -d '\r')
PRIMARY=${PRIMARY:-mongodb-0}

kubectl cp ./vulcano-<stamp>.gz "$NS/$PRIMARY:/tmp/restore.gz"

kubectl exec -n "$NS" "$PRIMARY" -- \
  mongorestore --host localhost:27017 -u root -p "$MONGO_PW" \
               --authenticationDatabase admin --db "$DB" \
               --gzip --archive=/tmp/restore.gz --drop \
               --numParallelCollections=1

kubectl exec -n "$NS" "$PRIMARY" -- rm -f /tmp/restore.gz
```

If your dump used `--db` (namespaced archive), `mongorestore --db "$DB"` lands
it in the same database. For a full-cluster archive drop the `--db` flag on both
commands.

**5. Restart the Vulcano backend**

```bash
kubectl scale deployment vulcano -n <ns> --replicas=1
kubectl rollout status deployment vulcano -n <ns>
```

Verify the application sees the migrated data, then delete the source archive
once you're confident the migration succeeded.

### Automated MongoDB Backups (S3)

For off-cluster backups the chart ships an optional `mongoBackup` component: a
long-running **Deployment** of
[`moovit/mongodb-s3-backup`](https://hub.docker.com/r/moovit/mongodb-s3-backup)
that `mongodump`s MongoDB and uploads the archive to an S3 bucket, pruning old
backups beyond `retainCount`. The image is a backup **daemon** — it takes a
backup on start (`INIT_BACKUP`) and then repeats on its own internal ~24h timer
(this is the same way it runs under Docker Swarm with `restart: always`).

Enable it in the release that **owns** the MongoDB you want to back up — i.e.
the shared-services release (`vulcano-common`) for the shared instance, or a
per-customer release that runs its own MongoDB. The MongoDB host, user and
password are derived automatically from the chart's `mongodb.*` config (the
password is read from the live `mongodb` secret), so you only supply the S3
destination and AWS credentials:

```yaml
mongoBackup:
  enabled: true
  retainCount: 30
  s3:
    bucket: "my-vulcano-backups"
    backupFolder: "surfplanet/shared-vulcano"
    # AWS keys belong in your gitignored secret values file:
    accessKeyId: "<AWS_ACCESS_KEY_ID>"
    secretAccessKey: "<AWS_SECRET_ACCESS_KEY>"
```

Already have the AWS keys in a Secret (e.g. via Bitwarden / `extraObjects`)?
Point at it instead and the chart won't create its own:

```yaml
mongoBackup:
  enabled: true
  s3:
    bucket: "my-vulcano-backups"
    backupFolder: "surfplanet/shared-vulcano"
    existingSecret: "my-aws-secret"            # keys: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
```

S3-compatible stores (MinIO, Wasabi, …) work via `s3.endpointUrl` and
`s3.region`. To dump a single database set `database:`; to keep the full
cluster dump, leave it empty.

> **Private image / pull secrets:** `vulcano-common` ships with
> `imagePullSecrets` disabled. If the backup image is not anonymously pullable,
> enable image pull secrets in that release so the backup pod can pull it.

**Verify / run a backup on demand:**

```bash
kubectl get deploy mongo-backup -n <ns>
kubectl logs -f deploy/mongo-backup -n <ns>   # expect: dump + S3 upload OK
# Force an extra backup now (the daemon backs up on start):
kubectl rollout restart deploy/mongo-backup -n <ns>
```

**Restore** from S3 by running the same image with `INIT_RESTORE=1` (it pulls
the latest archive from `BUCKET`/`BACKUP_FOLDER` and `mongorestore`s it). See
the operational runbook in `AI_AGENT_GUIDE.md` for the exact one-off Job.

### Dry-run pre-flight

`helm install` accepts `--dry-run=server`, which renders the chart, sends it
to the Kubernetes API for server-side validation (admission webhooks, RBAC,
CRD existence, schema checks), and returns the result without persisting
anything. Use it whenever you're unsure whether a values change will apply
cleanly:

```bash
helm upgrade --install vulcano vulcano-helm-chart/vulcano \
  --version 1.3.0 -n vulcano-app \
  -f values.yaml -f values.secret.yaml \
  --dry-run=server
```

> `--dry-run=client` only renders templates locally but **still requires
> cluster connectivity** to query API capabilities. There is no fully
> offline dry-run; use `helm template ...` if you need pure local rendering.

### SMB CSI – Active Directory domain authentication

The chart's `smbcreds` Secret only emits `username` + `password` keys; there
is no separate `domain` key. To authenticate against a Windows / AD share,
encode the domain into the username field with a backslash:

```yaml
smbCsi:
  enabled: true
  uri: "//fileserver.corp.example.com/share"
  username: "CORP\\svc_vulcano"
  # password: -> values.secret.yaml
```

The `smb.csi.k8s.io` driver accepts both `DOMAIN\user` and `user@DOMAIN`
formats. Use double-backslash in YAML — single backslash is a YAML escape
character.

### Shared Services / Multi-Instance Deployment

You can deploy MongoDB and RabbitMQ **once** into a shared namespace (e.g. `vulcano-common`) and then point multiple independent Vulcano instances to those services. This avoids running a separate database stack per customer / environment.

The `deployments/` folder in this repository follows the recommended layout:

```
deployments/
  vulcano-common/
    values.yaml            # shared services (MongoDB + RabbitMQ), committed
    values.secret.yaml     # credentials, gitignored
  vulcano-<instance>/
    values.yaml            # per-instance config, committed
    values.secret.yaml     # credentials, gitignored
```

Secret files are excluded from git via `.gitignore` (`deployments/**/*.secret.yaml`).

**Step 1 – Deploy the shared services (once)**

Create a `values.yaml` and a `values.secret.yaml` (see `examples/shared-services-values.yaml` as a template), then run:

```bash
helm upgrade --install vulcano-common /path/to/vulcano-helm-chart \
  --namespace vulcano-common \
  --create-namespace \
  --values deployments/vulcano-common/values.yaml \
  --values deployments/vulcano-common/values.secret.yaml
```

This installs MongoDB + RabbitMQ into the `vulcano-common` namespace. After the rollout the services are reachable cluster-internally at:

| Service | FQDN |
|---------|------|
| MongoDB (replicaset) | `mongodb-headless.vulcano-common.svc.cluster.local:27017` |
| RabbitMQ | `rabbitmq.vulcano-common.svc.cluster.local:5672` |

> **⚠️ MongoDB ReplicaSet – manual initiation required on first install**
>
> The `cloudpirates/mongodb` sub-chart does **not** automatically initiate the ReplicaSet.
> After all 3 pods are `Running`, exec into the primary and run:
>
> ```bash
> kubectl exec -it mongodb-0 -n vulcano-common -- mongosh \
>   -u admin -p <rootPassword> --authenticationDatabase admin \
>   --eval 'rs.initiate({
>     _id: "rs0",
>     members: [
>       { _id: 0, host: "mongodb-0.mongodb-headless.vulcano-common.svc.cluster.local:27017" },
>       { _id: 1, host: "mongodb-1.mongodb-headless.vulcano-common.svc.cluster.local:27017" },
>       { _id: 2, host: "mongodb-2.mongodb-headless.vulcano-common.svc.cluster.local:27017" }
>     ]
>   })'
> ```
>
> Verify with `rs.status()` — one member should show `"stateStr": "PRIMARY"`.

> **ℹ️ RabbitMQ – `cloudpirates/rabbitmq` secret key names**
>
> The `cloudpirates/rabbitmq` sub-chart writes its Secret with the keys
> `password` and `erlang-cookie` (no `rabbitmq-` prefix). The chart defaults
> match this:
>
> ```yaml
> rabbitmq:
>   auth:
>     existingPasswordKey: "password"
>     existingErlangCookieKey: "erlang-cookie"
> ```
>
> If you point the chart at an externally managed Secret (e.g. Bitwarden,
> External Secrets) whose keys are named differently — for instance
> `rabbitmq-password` from a legacy Bitnami import — override these keys to
> match your external Secret's actual field names.

**Step 2 – Deploy each Vulcano instance**

Use `examples/vulcano-only-values.yaml` as a starting point. The key settings are:

```yaml
mongodb:
  enabled: false          # do NOT deploy MongoDB inside this release
  externalHost: "mongodb-headless.vulcano-common.svc.cluster.local"
  auth:
    rootUser: "admin"
    rootPassword: "SAME_AS_SHARED_SERVICES"  # must match shared-services values
  replicaSet:
    enabled: true
    name: "rs0"

rabbitmq:
  enabled: false          # do NOT deploy RabbitMQ inside this release
  externalHost: "rabbitmq.vulcano-common.svc.cluster.local"
  auth:
    username: "vulcano"
    password: "SAME_AS_SHARED_SERVICES"      # must match shared-services values
```

Then deploy the instance:

```bash
helm upgrade --install vulcano-customer1 /path/to/vulcano-helm-chart \
  --namespace vulcano-customer1 \
  --create-namespace \
  --values deployments/vulcano-customer1/values.yaml \
  --values deployments/vulcano-customer1/values.secret.yaml
```

Repeat Step 2 for every additional Vulcano instance, changing `global.namespace`, `global.domain`, and `vulcano.ingress.hosts` each time.

> **ℹ️ SMB CSI – use IP address for the server**
>
> If the SMB server hostname is not resolvable from within the cluster (e.g. it's a local NAS hostname),
> use its IP address in `smbCsi.uri`:
>
> ```yaml
> smbCsi:
>   uri: "//10.0.0.201/RAID/vulcano/myinstance"   # IP, not hostname
> ```

> **ℹ️ RabbitMQ – external access for render nodes**
>
> By default RabbitMQ is only reachable inside the cluster (`ClusterIP`). To allow render nodes in
> the same LAN to connect, add a `rabbitmq-external` NodePort service via `extraObjects` in your
> shared-services values (see `deployments/vulcano-common/values.yaml` for a working example):
>
> ```yaml
> extraObjects:
>   - apiVersion: v1
>     kind: Service
>     metadata:
>       name: rabbitmq-external
>       namespace: "vulcano-common"
>     spec:
>       type: NodePort
>       selector:
>         app.kubernetes.io/name: rabbitmq
>       ports:
>         - name: amqp
>           port: 5672
>           targetPort: amqp
>           nodePort: 32672      # fixed – survives helm upgrade
>         - name: management
>           port: 15672
>           targetPort: mgmt
>           nodePort: 31672      # Management UI
> ```
>
> The render node `application.properties`:
>
> ```properties
> spring.rabbitmq.addresses=amqp://<user>:<password>@10.10.10.35:32672,amqp://<user>:<password>@10.10.10.46:32672,amqp://<user>:<password>@10.10.10.51:32672
> ```
>
> Management UI: `http://<node-ip>:31672`
>
> Using a dedicated `extraObjects` service (instead of patching the sub-chart service) ensures the
> NodePort is **declarative** and survives every `helm upgrade` without manual intervention.

> **ℹ️ RabbitMQ – LoadBalancer alternative**
>
> If the cluster has a LoadBalancer controller (MetalLB on bare metal, or a cloud LB), you can give the
> broker its own IP instead of per-node ports — then every tenant reuses the native `5672` and there is
> no NodePort collision to manage. AMQP is raw TCP, so it belongs on the LoadBalancer; the management UI
> is HTTP and should go through an Ingress (or stay `ClusterIP`) — do **not** publish the admin UI on the
> LoadBalancer IP.
>
> ```yaml
> extraObjects:
>   - apiVersion: v1
>     kind: Service
>     metadata:
>       name: rabbitmq-external
>       namespace: "vulcano-common"
>       annotations:
>         metallb.universe.tf/loadBalancerIPs: "10.10.10.60"   # replaces the deprecated spec.loadBalancerIP
>     spec:
>       type: LoadBalancer
>       loadBalancerSourceRanges:        # whitelist render-node IPs; omit if the LB is already private
>         - 10.0.0.0/24
>       selector:
>         app.kubernetes.io/name: rabbitmq
>         app.kubernetes.io/instance: vulcano-shared   # must equal the Helm release name
>       ports:
>         - name: amqp
>           port: 5672
>           targetPort: amqp
> ```
>
> Render nodes then use `amqp://<user>:<password>@10.10.10.60:5672`. Requires a LoadBalancer controller
> with an address pool, or the Service stays `<pending>` — NodePort (above) needs no such infrastructure,
> which is why the shipped `deployments/` use it.

> **ℹ️ Let's Encrypt HTTP-01 challenge**
>
> For automatic TLS via cert-manager, ports **80 and 443** must be reachable from the internet at the
> domain's public IP. Ensure your router forwards both ports to at least one cluster node running the
> ingress controller.

> **⚠️ ingress-nginx is retired (EOL March 2026)**
>
> Upstream [ingress-nginx maintenance halted in March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)
> — no further releases, bug-fixes, or security patches. The chart still defaults to
> `vulcano.ingress.className: nginx` and existing installs keep working, but plan a migration:
> enable the **opt-in Gateway API** support (`vulcano.gateway.enabled=true` + a `parentRef`,
> which renders an `HTTPRoute`), or switch to a maintained alternative Ingress controller.

### Extra Objects

`extraObjects` lets you deploy arbitrary Kubernetes resources alongside the chart. Every entry supports Helm templating via `tpl`, so you can reference `.Release.Name`, `.Values.*`, etc.

Typical use-cases:
- **Bitwarden / External Secrets** – create secrets from an external vault and reference them via `existingSecret` above
- **Custom PVCs / PVs** – provision a PVC with a special storage class (e.g. CSI SMB) and hand it to the Vulcano pod via `vulcano.storage.existingClaim`

```yaml
extraObjects:
  # Bitwarden Secrets Manager – delivers credentials into K8s Secrets
  - apiVersion: k8s.bitwarden.com/v1
    kind: BitwardenSecret
    metadata:
      name: rabbitmq
      namespace: "{{ .Values.global.namespace }}"
    spec:
      organizationId: "<org-id>"
      secretName: bw-rabbitmq-secrets
      map:
        password: "bw-rabbitmq-password"
  # Custom PVC with CSI SMB
  - apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: smb-vulcano-data
      namespace: "{{ .Values.global.namespace }}"
    spec:
      accessModes:
        - ReadWriteMany
      storageClassName: smb
      resources:
        requests:
          storage: 1Ti
```

------

### Persistent Storage

The chart creates a PVC for Vulcano application data by default. You can customise every aspect:

```yaml
vulcano:
  storage:
    size: "50Gi"
    storageClass: "longhorn"          # storage class; leave empty for cluster default
    accessModes: ReadWriteOnce
    labels: {}
    annotations:
      helm.sh/resource-policy: keep   # prevent accidental deletion on helm uninstall
    existingClaim: ""                 # mount a pre-existing PVC instead of creating one
```

When `existingClaim` is set the chart skips PVC creation entirely and mounts the referenced claim directly into the Vulcano pod.

#### Per-folder PVCs (`extraMounts`)

When individual Vulcano folders need different backing storage — e.g. `/data/highres` on fast NVMe while `/data/highres_templates` lives on a separate share — list them under `vulcano.storage.extraMounts`. Each entry is mounted on top of the primary mount on both the `vulcano` and `filetransfer` pods (filetransfer mounts read-only), so the on-disk file tree stays consistent across the components.

For every entry provide `name` + `mountPath` and **either**:

- `existingClaim` — reference a PVC you have already provisioned (the chart will not create one), or
- `pvc` / `size` / `accessModes` / `storageClass` / `labels` / `annotations` — let the chart template a new PVC alongside the primary one. If `pvc` is omitted the PVC name defaults to `vulcano-<name>`.

```yaml
vulcano:
  storage:
    mountPath: "/data"
    pvc: "vulcano-data"
    size: "50Gi"

    extraMounts:
      # /data/highres backed by a pre-provisioned fast-storage PVC
      - name: highres
        mountPath: "/data/highres"
        existingClaim: "vulcano-highres-fast-nvme"

      # /data/highres_templates backed by a PVC the chart creates
      - name: highres-templates
        mountPath: "/data/highres_templates"
        size: "200Gi"
        accessModes: "ReadWriteMany"
        storageClass: "longhorn"
```

> SMB-CSI provisioning (`smbCsi.enabled`) only applies to the primary PVC. For SMB-backed extras, provision the PV/PVC yourself (e.g. via `extraObjects`) and reference it with `existingClaim`.

### Optional sidekick Deployments

The chart can deploy two optional companion services in the same release as the Vulcano backend. Both are off by default — flip `<component>.enabled: true` to bring them up.

#### `filetransfer`

A separate deployment that ships rendered output to external destinations (FTP / SFTP / ZDF Upload Portal via TUS). It mounts `vulcano.storage` **read-only** and authenticates against the Vulcano API as the `service_admin` user (password is sourced from the shared `vulcano-credentials` Secret).

```yaml
filetransfer:
  enabled: true
  port: 8999
  properties:
    transfer.type: "ftp"                   # ftp | sftp | zdf
    transfer.destination: "/data/transfer" # FTP/SFTP only — must be on a mounted path
    transfer.logApiRequests: "false"

  # ZDF mode only — declarative TUS targets.
  # Each target name is referenced in the API call; inviteCode is per-target.
  zdfTargets:
    TARGET1:
      inviteCode: ""   # sensitive – put in values.secret.yaml
```

If you use `vulcano.storage.extraMounts`, filetransfer automatically gets the same set of mounts read-only so its view of the filesystem matches Vulcano's.

#### `dflconnector`

Bridges the DFL (Deutsche Fußball Liga) data-feed websocket / REST API into Vulcano: subscribes to configured services, fetches initial fixtures, and posts updates back to Vulcano. Authenticates as `service_admin` (hardcoded username in the connector code; password from `vulcano-credentials`).

```yaml
dflconnector:
  enabled: true
  port: 8080
  properties:
    vulcano.base.url: "http://vulcano:8889/"
    vulcano.dfl.competitionId: "DFL-COM-000001,DFL-COM-000002"
    vulcano.dfl.seasonId: "DFL-SEA-0001K9"
    vulcano.dfl.services: "DFL-05.01-Tabelle,DFL-02.01-Spielinformationen,..."
    vulcano.dfl.websocket.clientId: "<assigned-by-dfl>"
    vulcano.dfl.websocket.url: "wss://ws.distribution.production.datahub-sts.de/DeliveryPlatform/websocket/ServiceRegistration"
    vulcano.logRequests: "false"           # flip to "true" to log every outgoing Vulcano API call
```

The connector requires Mongo (it uses its own DB). Override `vulcano.base.url` if Vulcano is reached via a different service name (e.g. when running in a non-namespaced setup).

### Spring Boot MongoDB binding (legacy vs. new)

Since chart **1.2.0** the MongoDB env vars are emitted under **both** key prefixes on every pod that talks to Mongo (vulcano, dflconnector):

| Prefix | Used by |
|---|---|
| `spring.data.mongodb.*` | Spring Boot ≤ 3.3 |
| `spring.mongodb.*`      | Spring Boot ≥ 3.4 (renamed binding) |

You don't need to configure anything to get both — the chart's `vulcano.mongodb.env` template emits the full set automatically. This lets the chart work against apps before and after the Spring Boot upgrade without per-pod overrides.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| adminUsers | string | `"admin1@domain.com\nadmin2@domain.com\n"` | List of email addresses for users with administrative privileges. One email per line. These users will have full system access including project deletion and user management. |
| adobe.apiKey | string | `""` |  |
| adobe.clientId | string | `""` |  |
| adobe.clientToken | string | `""` |  |
| adobe.dumpFilepath | string | `""` |  |
| adobe.enabled | bool | `false` |  |
| adobe.librariesIgnore | string | `""` |  |
| adobe.scan | string | `""` |  |
| adobe.secret | string | `""` |  |
| affinity | object | `{}` | Affinity rules for pod scheduling |
| auth.keycloak.authority | string | `nil` | Keycloak authority URL |
| auth.keycloak.clientId | string | `nil` | Keycloak client ID |
| auth.keycloak.clientSecret | string | `nil` | Keycloak client secret |
| auth.keycloak.existingPasswordKey | string | `"keycloak-client-secret"` | Key inside existingSecret that holds the client secret |
| auth.keycloak.existingSecret | string | `""` | Name of an existing K8s Secret containing the Keycloak client secret (when set, clientSecret is ignored) |
| auth.microsoft.authority | string | `nil` | Microsoft Azure AD authority URL |
| auth.microsoft.clientId | string | `nil` | Microsoft Azure AD client ID |
| auth.mode | string | `"MICROSOFT"` | Authentication mode (MICROSOFT, KEYCLOAK, HELMUT, BID) |
| auth.secret | string | `nil` | Authentication secret key |
| auth.serviceAdminPassword | string | `nil` | Service admin password for authentication. Stored in the vulcano-credentials Secret and shared by the vulcano, dflconnector and filetransfer deployments. |
| auth.serviceAdminPasswordExistingSecret | string | `""` | Name of an existing K8s Secret holding the service admin password. When set, serviceAdminPassword is ignored, the chart does NOT write it to vulcano-credentials, and all three deployments read it from this Secret (keeps it out of values/Git). |
| auth.serviceAdminPasswordExistingSecretKey | string | `"service-admin-password"` | Key inside serviceAdminPasswordExistingSecret that holds the password. |
| commonAnnotations | object | `{}` | Annotations to add to all deployed objects |
| commonLabels | object | `{}` | Labels to add to all deployed objects |
| dataFeedMapping.ignoreDelete | string | `"false"` | Ignore Delete Messages from Datafeed |
| dataFeedMapping.skipUpdates | string | `"false"` | Skip Asset Creation for Updates from Datafeed |
| dflconnector | object | `{"enabled":false,"port":8080,"properties":{"logging.level.de.moovit.vulcanodflconnector":"INFO","logging.level.root":"INFO","logstash.enabled":"false","server.port":"8080","vulcano.base.url":"http://vulcano:8889/","vulcano.cache.db.expireAfterWriteMinutes":"15","vulcano.cache.db.maximumSize":"1000","vulcano.cache.http.expireAfterWriteMinutes":"1","vulcano.cache.http.maximumSize":"500","vulcano.dfl.competitionId":"","vulcano.dfl.listOfServicesUrl":"https://httpget.distribution.production.datahub-sts.de/DeliveryPlatform/REST/ListOfServices/{clientId}","vulcano.dfl.liveTableParameters":"","vulcano.dfl.pullOnceUrl":"https://httpget.distribution.production.datahub-sts.de/DeliveryPlatform/REST/PullOnce/{clientId}/{serviceId}/{parameterId}","vulcano.dfl.seasonId":"","vulcano.dfl.serviceInformationUrl":"https://httpget.distribution.production.datahub-sts.de/DeliveryPlatform/REST/ServiceInformation/{clientId}/{serviceId}","vulcano.dfl.services":"","vulcano.dfl.websocket.clientId":"","vulcano.dfl.websocket.clientName":"Vulcano","vulcano.dfl.websocket.connect-timeout":"30000","vulcano.dfl.websocket.max-message-size":"50MB","vulcano.dfl.websocket.message-timeout":"300000","vulcano.dfl.websocket.ping-interval-seconds":"10","vulcano.dfl.websocket.pong-timeout-millis":"20000","vulcano.dfl.websocket.url":"wss://ws.distribution.production.datahub-sts.de/DeliveryPlatform/websocket/ServiceRegistration","vulcano.logRequests":"false"},"resources":{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"256Mi"}}}` | ------------------------------------------------------------------------- |
| extraObjects | list | `[]` | Extra Kubernetes objects to deploy alongside the chart. Useful for BitwardenSecrets, custom PVCs, StorageClasses, or any other resource. Supports templating via tpl – you can reference .Release.Name, .Values, etc. Example (Bitwarden Secrets Manager): extraObjects:   - apiVersion: k8s.bitwarden.com/v1     kind: BitwardenSecret     metadata:       name: rabbitmq       namespace: "{{ .Release.Namespace }}"     spec:       organizationId: "<org-id>"       secretName: bw-rabbitmq-secrets       map:         - bwSecretId: <uuid>           secretKeyName: "rabbitmq-password"         - bwSecretId: <uuid>           secretKeyName: "rabbitmq-erlang-cookie"       authToken:         secretName: bw-auth-token         secretKey: token |
| features.afxCreateMogrt | string | `"true"` | Enable creation of MOGRT files during rendering |
| features.afxRender | string | `"true"` | Enable After Effects rendering functionality |
| features.afxRenderMassJobLimit | string | `"-1"` | Maximum number of assets that can be rendered simultaneously in mass rendering operations |
| features.afxRenderOnDemand | string | `"false"` | Enable on-demand rendering capabilities |
| features.afxRenderOnDemandExtended | string | `"false"` | If enabled, users can both add an asset to a project and mark it as 'Preparing' |
| features.afxRenderPreview | string | `"true"` | Enable preview rendering functionality in AfxRenderer |
| features.afxRenderTemplates | string | `""` | Comma-separated list of After Effects render templates selectable per project in preferences (Vulcano 1.9.31+). Empty falls back to the global template. → vulcano.afx.render.templates |
| features.cloudmode | string | `"false"` | Enable cloud-based rendering mode |
| features.ignoreMogrt | string | `"false"` | Ignore MOGRT files during template scanning and processing |
| features.logThirdPartyRequests | string | `"false"` | Enable detailed logging of all HTTP requests made to external APIs |
| features.maxNameLength | string | `"200"` | Maximum character limit for asset names and file names |
| filetransfer | object | `{"enabled":false,"name":"vulcano-transfer","port":8999,"properties":{"server.port":"8999","springdoc.api-docs.path":"/api-docs","springdoc.swagger-ui.path":"/docs","transfer.logApiRequests":"false","transfer.type":"","vulcano.baseUrl":"http://vulcano:8889"},"resources":{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"256Mi"}}}` | ------------------------------------------------------------------------- |
| folderScanner.allowEmptyFolder | string | `"true"` | Allow creation and preservation of empty folders in the file system structure |
| folderScanner.defaultBin | string | `"Templates"` | Default folder name used for organizing templates and assets when no specific bin is specified |
| folderScanner.maxDepth | string | `"10"` | Maximum folder depth level for recursive scanning operations |
| folderScanner.recreateMissingHighres | string | `"true"` | Automatically re-render missing high-resolution files when detected during system checks |
| folderScanner.startD3 | string | `"false"` | Enable Delta Tre sports data integration |
| folderScanner.startWatcher | string | `"true"` | Enable automatic file system monitoring to detect changes in template folders |
| folders.customCertificatesSecret | string | `""` | Name of a Kubernetes Secret whose keys are mounted as certificate files into /etc/certs inside the Vulcano pod. Each key in the Secret becomes a file at /etc/certs/<key>. Leave empty to disable the certificate mount. |
| folders.fonts | string | `""` | Active fonts folder for the Font Manager (Vulcano 1.9.31+). Holds fonts that are active and distributed to render nodes; must sit on the shared PVC. Leave empty to derive `<vulcano.storage.mountPath>/fonts` automatically, so it follows the mount for every deployment without a per-environment override. → vulcano.folderscanner.fontFolder |
| folders.fontsInactive | string | `""` | Inactive (deactivated) fonts folder, backend-managed and not used in rendering. Empty derives `<vulcano.storage.mountPath>/fonts_inactive`. → vulcano.folderscanner.fontInactiveFolder |
| folders.media.clientFolder | string | `"/data/highres"` | Client-side path mapping for media files in path replacement operations |
| folders.media.extension | string | `".mov"` | Comma-separated list of allowed media file extensions for processing |
| folders.media.folder | string | `"/data/highres"` | Root directory path where generated high-resolution media files are stored |
| folders.media.templatesFolder | string | `"/data/highres_templates"` | Directory path containing After Effects project templates and MOGRT files |
| folders.output.deletedFolder | string | `"/highres_deleted"` | Folder path where deleted high-resolution rendered files are moved before permanent deletion |
| folders.pathMapRenderNode | string | `"Z:"` | Path mapping configuration for render nodes in distributed rendering setups |
| folders.pathMapServer | string | `"/data"` | Server-side path mapping configuration for shared storage access |
| folders.proxy | string | `"/data/lowres"` | Directory path where low-resolution proxy files are stored |
| folders.templates | string | `"/data/templates"` | Root directory path containing all After Effects templates and project files |
| folders.templatesClient | string | `""` | Client-side path mapping for template files |
| folders.thumbnails | string | `"/data/thumbs"` | Directory path where thumbnail images are stored |
| folderscanner.mediaFolder.recreateFolderStructure | string | `"true"` | Recreate the folder structure for media folders |
| folderscanner.mediaFolder.templates.client | string | `"/Volumes/helmut_1/vulcano/highres_templates"` | Client-side path mapping for template media files. Used to replace server template paths with client-accessible paths in HiresApiDelegateImpl.mapHiresPath() for template folder access |
| fullnameOverride | string | `"vulcano"` | Override the full release name. Defaults to "vulcano" (not the release name) so upgrades keep matching resource names already live in every existing deployment; the fullname helper would otherwise rename Deployment/ Service/ConfigMaps/Ingress to the release name and orphan the originals. |
| global | object | `{"namespace":"vulcano-app"}` | Global configuration for the Vulcano deployment |
| global.namespace | string | `"vulcano-app"` | Kubernetes namespace for the deployment |
| helmut | object | `{"apiToken":"","baseUrl":null,"clientId":"","clientSecret":"","cosmo":{"baseBreadcrumb":"","mappingDest":"","mappingSrc":"","sync":""},"logRequest":"","pageSize":""}` | ------------------------------------------------------------------------- |
| hostAliases | list | `[]` | Static /etc/hosts entries injected into the Vulcano pod. Useful when the pod must reach a hostname that the cluster cannot resolve to an internal address (e.g. a self-hosted Keycloak whose public hostname does not NAT-loop back into the cluster). Each item: { ip: <addr>, hostnames: [<host>, ...] }. |
| housekeeping.enabled | string | `"false"` | Enable automatic cleanup and maintenance tasks |
| housekeeping.maxAge | string | `"14"` | Maximum age in days for housekeeping items before they are automatically cleaned up |
| imagePullSecrets | object | `{"enabled":true,"secrets":[{"name":"docker-io"}]}` | Image Pull Secrets configuration |
| imagePullSecrets.enabled | bool | `true` | Enable image pull secrets |
| images | object | `{"dflconnector":{"pullPolicy":"IfNotPresent","repository":"moovit/de.moovit.vulcano-dfl-connector","tag":"0.2.20"},"filetransfer":{"pullPolicy":"IfNotPresent","repository":"moovit/vulcano-filetransfer","tag":"0.0.10"},"vulcano":{"pullPolicy":"IfNotPresent","repository":"moovit/vulcano","tag":"1.9.31"}}` | Docker Image Configuration |
| images.vulcano.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| images.vulcano.repository | string | `"moovit/vulcano"` | Docker repository for Vulcano application |
| images.vulcano.tag | string | `"1.9.31"` | Docker image tag |
| integrations | object | `{"adobe":{"apiKey":"CCHomeWeb1","clientId":"","clientToken":"","dumpFilepath":"","enabled":false,"librariesIgnore":"\"Library to Ignore\"","scan":"false","secret":""},"helmut":{"apiToken":"","baseUrl":"","clientId":"","clientSecret":"","cosmoBaseBreadcrumb":"","cosmoMappingDest":"","cosmoMappingSrc":"","cosmoSync":"false","existingPasswordKey":"helmut-client-secret","existingSecret":"","logRequest":"false","pageSize":"50"},"ndr":{"bidLookupUrl":"","existingPasswordKey":"ndr-vdb-password","existingSecret":"","vdbPassword":"","vdbServer":"","vdbSimulate":"false","vdbUsername":"","wikiUrl":"","wildcardBid":""},"octopus":{"api":"","clientDelayInMs":"5000","enabled":false,"existingPasswordKey":"octopus-password","existingSecret":"","password":"","startClient":"false","username":""},"vidispine":{"baseUrl":"","baseUrlAuth":"","clientId":"","clientSecret":"","defaultLocation":"","existingPasswordKey":"vidispine-client-secret","existingSecret":"","locationValuesUrl":"","storage":"","workflow":"","workflowMogrt":"","workflowVersion":"","workflowVersionMogrt":""}}` | ------------------------------------------------------------------------- |
| integrations.adobe | object | `{"apiKey":"CCHomeWeb1","clientId":"","clientToken":"","dumpFilepath":"","enabled":false,"librariesIgnore":"\"Library to Ignore\"","scan":"false","secret":""}` | Adobe Creative Cloud Libraries integration |
| integrations.adobe.apiKey | string | `"CCHomeWeb1"` | Adobe API Key for accessing Adobe Creative Cloud services |
| integrations.adobe.clientId | string | `""` | Adobe IMS Client ID for OAuth authentication flow |
| integrations.adobe.clientToken | string | `""` | OAuth access token for Adobe Creative Cloud Libraries API authentication |
| integrations.adobe.dumpFilepath | string | `""` | File path where a JSON dump of all available Adobe CC Libraries elements will be created |
| integrations.adobe.enabled | bool | `false` | Enable Adobe Creative Cloud Libraries integration for syncing MOGRT templates |
| integrations.adobe.librariesIgnore | string | `"\"Library to Ignore\""` | Comma-separated list of Adobe Creative Cloud Library names that should be excluded from synchronization |
| integrations.adobe.scan | string | `"false"` | Enable automatic synchronization of Adobe Creative Cloud Libraries every 2 minutes |
| integrations.adobe.secret | string | `""` | Adobe IMS Client Secret for OAuth authentication |
| integrations.helmut | object | `{"apiToken":"","baseUrl":"","clientId":"","clientSecret":"","cosmoBaseBreadcrumb":"","cosmoMappingDest":"","cosmoMappingSrc":"","cosmoSync":"false","existingPasswordKey":"helmut-client-secret","existingSecret":"","logRequest":"false","pageSize":"50"}` | Authentication token for Helmut4 media asset management system integration |
| integrations.helmut.apiToken | string | `""` | Authentication token for Helmut4 media asset management system integration |
| integrations.helmut.baseUrl | string | `""` | Base URL of the Helmut4 server API (e.g., https://helmut.company.com/api) |
| integrations.helmut.clientId | string | `""` | OAuth client identifier for Helmut4 API authentication |
| integrations.helmut.clientSecret | string | `""` | OAuth client secret for secure Helmut4 API authentication |
| integrations.helmut.cosmoBaseBreadcrumb | string | `""` | Base breadcrumb path for Helmut4 Cosmo workspace navigation |
| integrations.helmut.cosmoMappingDest | string | `""` | Destination path mapping for Helmut4 Cosmo integration |
| integrations.helmut.cosmoMappingSrc | string | `""` | Source path mapping for Helmut4 Cosmo integration |
| integrations.helmut.cosmoSync | string | `"false"` | Enable synchronization between Vulcano assets and Helmut4 Cosmo workspace |
| integrations.helmut.existingPasswordKey | string | `"helmut-client-secret"` | Key inside existingSecret that holds the client secret |
| integrations.helmut.existingSecret | string | `""` | Name of an existing K8s Secret containing the Helmut4 client secret (when set, clientSecret is ignored) |
| integrations.helmut.logRequest | string | `"false"` | Enable detailed logging of HTTP requests made to Helmut4 API |
| integrations.helmut.pageSize | string | `"50"` | Number of items per page when fetching data from Helmut4 API |
| integrations.ndr | object | `{"bidLookupUrl":"","existingPasswordKey":"ndr-vdb-password","existingSecret":"","vdbPassword":"","vdbServer":"","vdbSimulate":"false","vdbUsername":"","wikiUrl":"","wildcardBid":""}` | URL endpoint for looking up BID information in the NDR VDB system |
| integrations.ndr.bidLookupUrl | string | `""` | URL endpoint for looking up BID (Broadcast ID) information in the NDR VDB system |
| integrations.ndr.existingPasswordKey | string | `"ndr-vdb-password"` | Key inside existingSecret that holds the VDB password |
| integrations.ndr.existingSecret | string | `""` | Name of an existing K8s Secret containing the NDR VDB password (when set, vdbPassword is ignored) |
| integrations.ndr.vdbPassword | string | `""` | Password for authenticating with the NDR VDB system |
| integrations.ndr.vdbServer | string | `""` | Server hostname or URL for the NDR VDB system |
| integrations.ndr.vdbSimulate | string | `"false"` | Enable simulation mode for VDB operations without making actual network calls |
| integrations.ndr.vdbUsername | string | `""` | Username for authenticating with the NDR VDB system |
| integrations.ndr.wikiUrl | string | `""` | URL to the NDR VDB documentation wiki |
| integrations.ndr.wildcardBid | string | `""` | Wildcard BID pattern used for broadcast ID matching in the NDR VDB system |
| integrations.octopus | object | `{"api":"","clientDelayInMs":"5000","enabled":false,"existingPasswordKey":"octopus-password","existingSecret":"","password":"","startClient":"false","username":""}` | API endpoint URL for Octopus newsroom system integration |
| integrations.octopus.api | string | `""` | API endpoint URL for Octopus newsroom system integration |
| integrations.octopus.clientDelayInMs | string | `"5000"` | Delay in milliseconds between Octopus client polling requests |
| integrations.octopus.enabled | bool | `false` | Enable Octopus newsroom system integration |
| integrations.octopus.existingPasswordKey | string | `"octopus-password"` | Key inside existingSecret that holds the password |
| integrations.octopus.existingSecret | string | `""` | Name of an existing K8s Secret containing the Octopus password (when set, password is ignored) |
| integrations.octopus.password | string | `""` | Password for authenticating with the Octopus newsroom system |
| integrations.octopus.startClient | string | `"false"` | Enable the Octopus client for receiving and processing MOS messages |
| integrations.octopus.username | string | `""` | Username for authenticating with the Octopus newsroom system |
| integrations.vidispine | object | `{"baseUrl":"","baseUrlAuth":"","clientId":"","clientSecret":"","defaultLocation":"","existingPasswordKey":"vidispine-client-secret","existingSecret":"","locationValuesUrl":"","storage":"","workflow":"","workflowMogrt":"","workflowVersion":"","workflowVersionMogrt":""}` | Base URL for Vidispine media asset management system API |
| integrations.vidispine.baseUrl | string | `""` | Base URL for Vidispine media asset management system API |
| integrations.vidispine.baseUrlAuth | string | `""` | Authentication endpoint URL for Vidispine system |
| integrations.vidispine.clientId | string | `""` | OAuth client identifier for Vidispine API authentication |
| integrations.vidispine.clientSecret | string | `""` | OAuth client secret for secure Vidispine API authentication |
| integrations.vidispine.defaultLocation | string | `""` | Default location value to be pre-selected in the location selector |
| integrations.vidispine.existingPasswordKey | string | `"vidispine-client-secret"` | Key inside existingSecret that holds the client secret |
| integrations.vidispine.existingSecret | string | `""` | Name of an existing K8s Secret containing the Vidispine client secret (when set, clientSecret is ignored) |
| integrations.vidispine.locationValuesUrl | string | `""` | URL for retrieving allowed values for the Location metadata field from Vidispine |
| integrations.vidispine.storage | string | `""` | Vidispine storage identifier for file operations |
| integrations.vidispine.workflow | string | `""` | Default workflow identifier in Vidispine for processing uploaded assets |
| integrations.vidispine.workflowMogrt | string | `""` | Specific workflow identifier for MOGRT files in Vidispine |
| integrations.vidispine.workflowVersion | string | `""` | Version number of the default Vidispine workflow to use |
| integrations.vidispine.workflowVersionMogrt | string | `""` | Version number of the MOGRT-specific workflow in Vidispine |
| logging.fileMaxSize | string | `"10MB"` | Maximum size of the log file before it gets rotated |
| logging.fileName | string | `"/data/LOGS/vulcano_k8s.log"` | Path to the log file where application logs are written |
| logging.filePath | string | `"/data/logs"` | Directory written into Spring Boot's `logging.file.path` setting (controls log directory). Leave empty to fall back to the JVM-arg derived path (`vulcano.storage.mountPath + /logs`). |
| logging.level.org | string | `"INFO"` | Logging level for the org package |
| logging.level.securityFilter | string | `"WARN"` | Logging level for the security filter |
| management.endpoint.caches.enabled | string | `"true"` | Enable the caches actuator endpoint |
| management.endpoint.health.group.readiness.include | string | `"rabbit,diskSpace,mongo,ping"` | Components to include in the readiness health check |
| management.endpoint.health.showDetails | string | `"always"` | When to show full health details in the health endpoint response |
| management.endpoint.prometheus.enabled | string | `"true"` | Enable the Prometheus actuator endpoint |
| management.endpoints.web.exposure.include | string | `"health,beans,loggers,env,prometheus,metrics"` | Comma-separated list of actuator endpoints to expose via web |
| management.health.livenessstate.enabled | string | `"true"` | Enable the liveness state health indicator |
| management.health.livenessstate.showDetails | string | `"always"` | Show detailed information in liveness state health checks |
| management.health.readinessstate.enabled | string | `"true"` | Enable the readiness state health indicator |
| management.health.readinessstate.showDetails | string | `"always"` | Show detailed information in readiness state health checks |
| management.metrics.distribution.percentilesHistogram | string | `"true"` |  |
| management.metrics.distribution.slo | string | `"50ms, 100ms, 200ms, 300ms, 500ms, 1s"` |  |
| management.metrics.enable.all | string | `"true"` |  |
| management.metrics.tags.application | string | `"vulcano-backend"` |  |
| management.otlp.logging.enabled | string | `"false"` | Enable log export. → management.logging.export.enabled |
| management.otlp.logging.endpoint | string | `"http://localhost:4318/v1/logs"` | OTLP logs endpoint. → management.opentelemetry.logging.export.otlp.endpoint |
| management.otlp.metrics.enabled | string | `"false"` | Enable metrics export. → management.otlp.metrics.export.enabled |
| management.otlp.metrics.endpoint | string | `"http://localhost:4318/v1/metrics"` | OTLP metrics endpoint. → management.otlp.metrics.export.url |
| management.otlp.tracing.enabled | string | `"false"` | Enable trace export. → management.tracing.export.enabled |
| management.otlp.tracing.endpoint | string | `"http://localhost:4318/v1/traces"` | OTLP traces endpoint. → management.opentelemetry.tracing.export.otlp.endpoint |
| management.otlp.tracing.samplingProbability | string | `"0.1"` | Fraction of traces to sample (0.0–1.0; 0.1 = 10% for prod, 1.0 for dev). → management.tracing.sampling.probability |
| management.prometheus.metrics.export.enabled | string | `"true"` |  |
| mongoBackup | object | `{"affinity":{},"database":"","enabled":false,"extraOpts":"--authenticationDatabase admin","image":{"pullPolicy":"IfNotPresent","repository":"docker.io/moovit/mongodb-s3-backup","tag":"latest"},"initBackup":true,"mongo":{"host":"","port":27017,"username":""},"nodeSelector":{},"resources":{},"retainCount":30,"s3":{"accessKeyId":"","backupFolder":"","bucket":"","endpointUrl":"","existingSecret":"","existingSecretAccessKeyIdKey":"AWS_ACCESS_KEY_ID","existingSecretSecretAccessKeyKey":"AWS_SECRET_ACCESS_KEY","region":"","secretAccessKey":""},"timezone":"Europe/Berlin","tolerations":[]}` | MongoDB → S3 backup (optional) Runs the moovit/mongodb-s3-backup image as a long-running Deployment that `mongodump`s MongoDB and uploads to S3 (initial backup on start, then the image's own internal ~24h loop — same as the Docker Swarm setup). Enable it in the release that owns the MongoDB you want to back up (e.g. vulcano-common for the shared instance). Connection details default to the chart's mongodb.* config; only the S3 destination + AWS credentials are required. |
| mongoBackup.affinity | object | `{}` | Affinity for the backup pod (falls back to chart-level affinity) |
| mongoBackup.database | string | `""` | Specific database to dump (MONGODB_DB). Empty = all databases. |
| mongoBackup.enabled | bool | `false` | Enable the MongoDB backup Deployment |
| mongoBackup.extraOpts | string | `"--authenticationDatabase admin"` | Extra mongodump flags. Defaults pin the auth database for the root user. |
| mongoBackup.image.pullPolicy | string | `"IfNotPresent"` | Backup image pull policy |
| mongoBackup.image.repository | string | `"docker.io/moovit/mongodb-s3-backup"` | Backup image repository |
| mongoBackup.image.tag | string | `"latest"` | Backup image tag |
| mongoBackup.initBackup | bool | `true` | Take a backup immediately on pod start (INIT_BACKUP). After that the image loops on its own internal ~24h timer. |
| mongoBackup.mongo | object | `{"host":"","port":27017,"username":""}` | MongoDB connection overrides. Blank values derive from the mongodb.* config. |
| mongoBackup.mongo.host | string | `""` | Override MongoDB host (default: derived from mongodb config) |
| mongoBackup.mongo.port | int | `27017` | MongoDB port |
| mongoBackup.mongo.username | string | `""` | Override MongoDB user (default: mongodb.auth.rootUsername) |
| mongoBackup.nodeSelector | object | `{}` | Node selector for the backup pod (falls back to chart-level nodeSelector) |
| mongoBackup.resources | object | `{}` | Resource requests/limits for the backup container |
| mongoBackup.retainCount | int | `30` | Number of backups to keep in S3 (older ones are pruned) |
| mongoBackup.s3.accessKeyId | string | `""` | AWS access key id (used only when existingSecret is empty; put in values.secret.yaml) |
| mongoBackup.s3.backupFolder | string | `""` | Folder/prefix inside the bucket |
| mongoBackup.s3.bucket | string | `""` | Target S3 bucket name |
| mongoBackup.s3.endpointUrl | string | `""` | Custom S3-compatible endpoint URL (ENDPOINT_URL). Optional. |
| mongoBackup.s3.existingSecret | string | `""` | Name of an existing Secret holding the AWS credentials. When set, the chart does NOT create the mongo-backup-credentials secret. |
| mongoBackup.s3.existingSecretAccessKeyIdKey | string | `"AWS_ACCESS_KEY_ID"` | Key in existingSecret holding the access key id |
| mongoBackup.s3.existingSecretSecretAccessKeyKey | string | `"AWS_SECRET_ACCESS_KEY"` | Key in existingSecret holding the secret access key |
| mongoBackup.s3.region | string | `""` | Bucket region (BUCKET_REGION). Optional. |
| mongoBackup.s3.secretAccessKey | string | `""` | AWS secret access key (used only when existingSecret is empty; put in values.secret.yaml) |
| mongoBackup.timezone | string | `"Europe/Berlin"` | Timezone for the container (IANA name); affects backup timestamp naming. Empty = UTC. |
| mongoBackup.tolerations | list | `[]` | Tolerations for the backup pod (falls back to chart-level tolerations) |
| mongodb | object | `{"auth":{"existingSecret":"","existingSecretPasswordKey":"mongodb-root-password","rootPassword":"bitte","rootUsername":"root"},"database":"vulcano","enabled":true,"externalHost":"","fullnameOverride":"mongodb","metrics":{"enabled":false},"persistence":{"enabled":true,"size":"50Gi","storageClassName":""},"port":27017,"replicaCount":3,"replicaSet":{"enabled":true,"name":"rs0"},"resources":{"limits":{"cpu":"2000m","memory":"4Gi"},"requests":{"cpu":"1000m","memory":"2Gi"}}}` | MongoDB Configuration |
| mongodb.auth.existingSecret | string | `""` | Name of an existing Kubernetes Secret containing MongoDB credentials. When set, rootPassword is ignored and the chart will NOT create a mongodb-credentials secret. |
| mongodb.auth.existingSecretPasswordKey | string | `"mongodb-root-password"` | Key inside existingSecret that holds the root password (chart default: "mongodb-root-password") |
| mongodb.auth.rootPassword | string | `"bitte"` | MongoDB root password (ignored when existingSecret is set) |
| mongodb.auth.rootUsername | string | `"root"` | MongoDB root username |
| mongodb.database | string | `"vulcano"` | MongoDB database name used by Vulcano (defaults to 'vulcano' if not set) |
| mongodb.enabled | bool | `true` | Enable MongoDB deployment as part of this release. Set to false when using an external MongoDB (e.g. deployed in vulcano-common). |
| mongodb.externalHost | string | `""` | External MongoDB host. When set (and enabled=false), Vulcano connects to this host. Credentials from auth.rootUsername / auth.rootPassword (or auth.existingSecret) are still used. Example: "mongodb-headless.vulcano-common.svc.cluster.local" |
| mongodb.fullnameOverride | string | `"mongodb"` | Full name override for MongoDB resources |
| mongodb.persistence.enabled | bool | `true` | Enable MongoDB persistence |
| mongodb.persistence.size | string | `"50Gi"` | MongoDB persistent volume size |
| mongodb.persistence.storageClassName | string | `""` | Storage class name for MongoDB |
| mongodb.port | int | `27017` | MongoDB port Vulcano connects to (defaults to 27017). Override for non-standard external ports. |
| mongodb.replicaCount | int | `3` | Number of MongoDB replicas |
| mongodb.replicaSet.enabled | bool | `true` | Enable MongoDB replica set mode. Required when replicaCount > 1. Switches the connection to the headless service and emits replica-set-name. |
| mongodb.replicaSet.name | string | `"rs0"` | MongoDB replica set name. Must match the name the sub-chart was initialized with. |
| nameOverride | string | `""` | Override the chart name |
| ndr.bidLookupUrl | string | `""` |  |
| ndr.wikiUrl | string | `""` |  |
| ndr.wildcardBid | string | `""` |  |
| nodeSelector | object | `{}` | Node selector for pod scheduling |
| octopus.api | string | `""` |  |
| octopus.client.delayInMS | string | `""` |  |
| octopus.enabled | bool | `false` |  |
| octopus.password | string | `""` |  |
| octopus.startClient | string | `""` |  |
| octopus.username | string | `""` |  |
| project.delete.ownerOnly | string | `"true"` | Only allow project deletion by the owner |
| project.sendToUrls | string | `""` | URLs to send project data to external systems |
| rabbitmq | object | `{"auth":{"erlangCookie":"VULCANO_SECRET_COOKIE","existingErlangCookieKey":"erlang-cookie","existingPasswordKey":"password","existingSecret":"","password":"vulcano0479","username":"vulcano"},"enabled":true,"externalHost":"","fullnameOverride":"rabbitmq","jobUpdateQueue":"vulcano-job-updates","metrics":{"enabled":false},"persistence":{"enabled":false},"port":5672,"replicaCount":3,"resources":{"limits":{"cpu":"1000m","memory":"2Gi"},"requests":{"cpu":"500m","memory":"1Gi"}},"service":{"type":"NodePort"}}` | RabbitMQ Configuration |
| rabbitmq.auth.erlangCookie | string | `"VULCANO_SECRET_COOKIE"` | Erlang cookie for RabbitMQ clustering (ignored when existingSecret is set) |
| rabbitmq.auth.existingErlangCookieKey | string | `"erlang-cookie"` | Key inside existingSecret that holds the Erlang cookie |
| rabbitmq.auth.existingPasswordKey | string | `"password"` | Key inside existingSecret that holds the RabbitMQ password. Default "password" matches the keys written by the cloudpirates/rabbitmq sub-chart's own Secret. Override only when pointing at an externally managed Secret that uses a different key name (e.g. "rabbitmq-password" from a Bitwarden mapping or legacy Bitnami secret). |
| rabbitmq.auth.existingSecret | string | `""` | Name of an existing Kubernetes Secret containing RabbitMQ credentials. When set, password and erlangCookie are ignored and the chart will NOT create a rabbitmq-credentials secret. |
| rabbitmq.auth.password | string | `"vulcano0479"` | RabbitMQ admin password (ignored when existingSecret is set) |
| rabbitmq.auth.username | string | `"vulcano"` | RabbitMQ admin username |
| rabbitmq.enabled | bool | `true` | Enable RabbitMQ deployment as part of this release. Set to false when using an external RabbitMQ (e.g. deployed in vulcano-common). |
| rabbitmq.externalHost | string | `""` | External RabbitMQ host. When set (and enabled=false), Vulcano connects to this host. Credentials from auth.username / auth.password (or auth.existingSecret) are still used. Example: "rabbitmq.vulcano-common.svc.cluster.local" |
| rabbitmq.fullnameOverride | string | `"rabbitmq"` | Full name override for RabbitMQ resources |
| rabbitmq.jobUpdateQueue | string | `"vulcano-job-updates"` | Name of the RabbitMQ queue used as the return channel from render nodes back to the server. Only set this if you need to run multiple isolated Vulcano instances sharing the same RabbitMQ broker. Defaults to "vulcano-job-updates" when not set. |
| rabbitmq.metrics.enabled | bool | `false` | Enable RabbitMQ metrics |
| rabbitmq.persistence.enabled | bool | `false` | Enable RabbitMQ persistence |
| rabbitmq.port | int | `5672` | RabbitMQ AMQP port Vulcano connects to (defaults to 5672). Override for non-standard external ports. |
| rabbitmq.replicaCount | int | `3` | Number of RabbitMQ replicas |
| rabbitmq.service.type | string | `"NodePort"` | RabbitMQ service type (ClusterIP, NodePort, LoadBalancer) |
| rbac.create | bool | `true` |  |
| securityContext.fsGroup | int | `1001` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `1001` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `"vulcano"` |  |
| smbCsi.domain | string | `""` | Optional Active Directory domain for SMB authentication. When set, the CSI driver passes `domain=<value>` to mount.cifs instead of relying on DOMAIN\username parsing. Leave empty for non-AD shares or when the username field already carries the domain prefix. |
| smbCsi.enabled | bool | `false` |  |
| smbCsi.password | string | `"password"` |  |
| smbCsi.uri | string | `"//xxx.xxx.xxx.xxx/mountpoint"` |  |
| smbCsi.username | string | `"username"` |  |
| spring.jackson.defaultPropertyInclusion | string | `"NON_NULL"` |  |
| spring.jackson.mapper.acceptCaseInsensitiveEnums | string | `"true"` |  |
| spring.jpa.hibernate.ddlAuto | string | `"update"` |  |
| spring.jpa.hibernate.naming.physicalStrategy | string | `"org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl"` |  |
| spring.main.lazyInitialization | string | `"false"` |  |
| spring.mvc.pathmatch.matchingStrategy | string | `"ANT_PATH_MATCHER"` |  |
| spring.servlet.multipart.enabled | string | `"true"` |  |
| spring.threads.virtual.enabled | string | `"false"` |  |
| springdoc.swaggerUi.path | string | `"/doc"` |  |
| tolerations | list | `[]` | Tolerations for pod scheduling on tainted nodes |
| tomcat.multipart.maxFileSize | string | `"1000MB"` | Maximum file size for multipart uploads |
| tomcat.multipart.maxRequestSize | string | `"1000MB"` | Maximum request size for multipart uploads |
| vdb.server | string | `""` |  |
| vdb.simulate | string | `""` |  |
| vidispine.baseUrl | string | `""` |  |
| vidispine.baseUrlAuth | string | `""` |  |
| vidispine.clientId | string | `""` |  |
| vidispine.clientSecret | string | `""` |  |
| vidispine.defaultLocation | string | `""` |  |
| vidispine.locationValuesUrl | string | `""` |  |
| vidispine.storage | string | `""` |  |
| vidispine.workflow | string | `""` |  |
| vidispine.workflowMogrt | string | `""` |  |
| vidispine.workflowVersion | string | `""` |  |
| vidispine.workflowVersionMogrt | string | `""` |  |
| vulcano.allowDownload | string | `"true"` | Enable download functionality for rendered assets in the web interface |
| vulcano.allowDuplicates | string | `"true"` | Allow creation of assets with duplicate names |
| vulcano.allowLinebreaksByDefault | string | `"false"` | Enable line breaks in text properties by default when creating new assets |
| vulcano.autologout.disable | string | `"false"` | Completely disable automatic logout functionality |
| vulcano.autologout.hours | string | `"1"` | Number of hours of inactivity before users are automatically logged out |
| vulcano.completedAssetInterceptor | string | `""` | HTTP endpoint URL that receives completed asset data and can MODIFY it before final storage |
| vulcano.completedWebhook | string | `""` | HTTP webhook URL for NOTIFICATION purposes only - receives completed asset data but cannot modify it |
| vulcano.createAssetInterceptor | string | `""` | HTTP endpoint URL that will be called when a new asset is created |
| vulcano.enabled | bool | `true` |  |
| vulcano.extraEnvVars | list | `[]` | Additional environment variables injected into the vulcano container. Useful for settings the chart does not expose directly. |
| vulcano.folder.createUserFolder | string | `"false"` | Enable creation of user-specific folders for organizing generated assets |
| vulcano.folder.globalParent | string | `""` | Global parent folder path component inserted in generated asset folder structure when user folders are enabled |
| vulcano.frontend.enableTimecodeForAssets | string | `"false"` | If enabled, a Timecode input will appear in the PreferenceView for assets |
| vulcano.gateway.enabled | bool | `false` | Enable Gateway API routing (renders an HTTPRoute). Mutually independent from `ingress.enabled` – do not enable both for the same host. |
| vulcano.gateway.hostnames | list | `[]` | Hostnames for the route. Falls back to `vulcano.ingress.hosts` when empty. |
| vulcano.gateway.parentRef | object | `{"name":"","namespace":"","sectionName":""}` | Reference to the existing Gateway this route attaches to. |
| vulcano.gateway.parentRef.name | string | `""` | Name of the Gateway (required when gateway.enabled=true) |
| vulcano.gateway.parentRef.namespace | string | `""` | Namespace of the Gateway (defaults to the release namespace when empty) |
| vulcano.gateway.parentRef.sectionName | string | `""` | Listener section name on the Gateway (optional; e.g. "https") |
| vulcano.gateway.path | string | `"/"` | Path prefix to match |
| vulcano.gateway.timeouts | object | `{"backendRequest":"3600s","request":"3600s"}` | Request timeouts (Gateway API v1) – generous defaults for slow renders and large /hires downloads, mirroring the legacy nginx proxy timeouts. |
| vulcano.graphicGenerator.rendition.formats | string | `"Facebook=1080x1920,Instagram=1080x1080"` | Comma-separated list of named output formats produced by the graphics generator (e.g. social-media renditions). Format: "Name1=WxH,Name2=WxH". Empty disables custom format generation. Used by the Packaging Machine (Beta, Vulcano 1.9.31+). NOTE: the Packaging Machine also requires the reframer binary on every render node (`vulcano.media.reframer`); that is a per-render-node setting and is out of scope for this server chart. |
| vulcano.home.base | string | `"/home"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/proxy-body-size" | string | `"500m"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/proxy-buffering" | string | `"off"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/proxy-max-temp-file-size" | string | `"0"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/proxy-read-timeout" | string | `"3600"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/proxy-send-timeout" | string | `"3600"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/server-snippets" | string | `"location /ws {\n proxy_set_header Upgrade $http_upgrade;\n proxy_http_version 1.1;\n proxy_set_header X-Forwarded-Host $http_host;\n proxy_set_header X-Forwarded-Proto $scheme;\n proxy_set_header X-Forwarded-For $remote_addr;\n proxy_set_header Host $host;\n proxy_set_header Connection \"upgrade\";\n proxy_cache_bypass $http_upgrade;\n}\n"` |  |
| vulcano.ingress.className | string | `"nginx"` | Ingress class name |
| vulcano.ingress.enabled | bool | `true` | Enable ingress (legacy Ingress API). See the `gateway` block below for the Gateway API alternative. |
| vulcano.ingress.hosts | list | `["vulcano.example.com"]` | Ingress hosts (supports multiple domains) |
| vulcano.ingress.path | string | `"/"` |  |
| vulcano.ingress.tls | object | `{"enabled":false,"existing":{"secretName":"tls-vulcano-cert"},"letsencrypt":{"clusterIssuer":"letsencrypt-prod","email":"admin@example.com","enabled":false},"source":"letsencrypt"}` | Enable TLS |
| vulcano.license | object | `{"existingSecret":"","existingSecretKey":"license-key","key":""}` | JWT license key for application licensing. Stored in a Secret (vulcano-credentials), never the ConfigMap. To keep the key out of values.yaml/Git entirely, leave `key` empty and reference an externally managed Secret via `existingSecret`. |
| vulcano.license.existingSecret | string | `""` | Name of an existing Secret holding the license key. When set, `key` is ignored and the chart does NOT store the license in vulcano-credentials. |
| vulcano.license.existingSecretKey | string | `"license-key"` | Key inside existingSecret that holds the license JWT (default: license-key). |
| vulcano.license.key | string | `""` | License JWT. When set (and existingSecret is empty), written to the vulcano-credentials Secret under key `license-key`. |
| vulcano.livenessProbe.enabled | bool | `false` |  |
| vulcano.livenessProbe.failureThreshold | int | `3` |  |
| vulcano.livenessProbe.initialDelaySeconds | int | `30` |  |
| vulcano.livenessProbe.periodSeconds | int | `10` |  |
| vulcano.livenessProbe.timeoutSeconds | int | `3` |  |
| vulcano.maxPropertiesInNames | string | `"5"` | Maximum number of template properties that can be used in auto-generated asset names |
| vulcano.maxPropertyLength | string | `"10"` | Maximum character length for individual property values used in asset names |
| vulcano.media.dockerHighresPath | string | `""` |  |
| vulcano.output.namePattern | string | `""` | Template pattern for PatternBasedOutputNameGenerator using placeholder syntax |
| vulcano.panel.loginRequired | string | `"true"` | Require authentication for the Adobe Premiere Pro panel |
| vulcano.projects.sortBy | string | `"NAME"` | Sorting criteria for project lists in searchProjects API |
| vulcano.readinessProbe.enabled | bool | `false` |  |
| vulcano.readinessProbe.failureThreshold | int | `3` |  |
| vulcano.readinessProbe.initialDelaySeconds | int | `30` |  |
| vulcano.readinessProbe.periodSeconds | int | `10` |  |
| vulcano.readinessProbe.timeoutSeconds | int | `3` |  |
| vulcano.replicaCount | int | `1` |  |
| vulcano.resources.limits.cpu | string | `"2000m"` |  |
| vulcano.resources.limits.memory | string | `"4Gi"` |  |
| vulcano.resources.requests.cpu | string | `"500m"` |  |
| vulcano.resources.requests.memory | string | `"2Gi"` |  |
| vulcano.searchProjectOnPageOpen | string | `"true"` | Automatically load and display projects when the main page is opened |
| vulcano.service.port | int | `8889` | Service port |
| vulcano.service.targetPort | int | `8889` | Target port |
| vulcano.service.type | string | `"ClusterIP"` | Service type (ClusterIP, NodePort, LoadBalancer) |
| vulcano.showAllBins | string | `"false"` | Controls whether the frontend displays all bins in the project structure or only those with content |
| vulcano.storage.accessModes | string | `"ReadWriteOnce"` | Access mode for the PVC |
| vulcano.storage.annotations | object | `{}` | Annotations for the PVC. Example: set helm.sh/resource-policy: keep to prevent deletion on helm uninstall |
| vulcano.storage.existingClaim | string | `""` | Name of an existing PVC to mount instead of creating a new one. When set, no PVC is created by the chart. Useful for custom CSI storage classes or pre-provisioned PV/PVCs. The PVC/PV itself can be deployed via extraObjects. |
| vulcano.storage.extraMounts | list | `[]` | Additional per-folder mounts layered on top of the primary mount. Each entry is mounted on both the vulcano and filetransfer pods so the file tree stays consistent (filetransfer mounts read-only).  Each item requires `name` + `mountPath`, plus EITHER:   - `existingClaim`: use a pre-provisioned PVC (chart creates nothing), OR   - `pvc` (+ optional `size`/`accessModes`/`storageClass`/`labels`/`annotations`):     chart templates a fresh PVC for the entry. |
| vulcano.storage.labels | object | `{}` | Additional labels for the PVC |
| vulcano.storage.mountPath | string | `"/data"` |  |
| vulcano.storage.pvc | string | `"smb-vulcano-data"` | Name of the PVC that is created by the chart (used when existingClaim is empty) |
| vulcano.storage.size | string | `"10Gi"` |  |
| vulcano.storage.storageClass | string | `"longhorn"` | Storage class for the PVC (leave empty for cluster default, set to "-" to omit storageClassName entirely) |
| vulcano.strategy | string | `""` | Deployment update strategy. Leave empty for auto-detect (recommended): the chart picks "RollingUpdate" when ALL volumes are ReadWriteMany, and falls back to "Recreate" if any volume is ReadWriteOnce – otherwise a rolling update would hit a Multi-Attach error when the new pod is scheduled on a different node than the old one. Set explicitly to "Recreate" or "RollingUpdate" to override. |
| vulcano.subtitle | string | `""` | Custom subtitle text displayed in the web interface header |
| vulcano.useCustomFileName | string | `"false"` | Allow users to specify custom filenames when creating assets instead of using auto-generated names |
| vulcano.webconfig.disable | string | `"false"` | Disable the web-based configuration interface |

------

Autogenerated from chart metadata using [helm-docs](https://github.com/norwoodj/helm-docs)
