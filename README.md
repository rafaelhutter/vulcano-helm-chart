# vulcano

![Version: 1.0.1](https://img.shields.io/badge/Version-1.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.9.13](https://img.shields.io/badge/AppVersion-1.9.13-informational?style=flat-square)

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

> **⚠️ RabbitMQ – `cloudpirates/rabbitmq` secret key names**
>
> The `cloudpirates/rabbitmq` sub-chart writes secrets with the keys `erlang-cookie` and `password`
> (without the `rabbitmq-` prefix used by other charts). Set these overrides in the shared-services values:
>
> ```yaml
> rabbitmq:
>   auth:
>     existingErlangCookieKey: "erlang-cookie"
>     existingPasswordKey: "password"
> ```

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

Repeat Step 2 for every additional Vulcano instance, changing `global.namespace`, `global.domain`, and `vulcano.ingress.host` each time.

> **ℹ️ SMB CSI – use IP address for the server**
>
> If the SMB server hostname is not resolvable from within the cluster (e.g. it's a local NAS hostname),
> use its IP address in `smbCsi.uri`:
>
> ```yaml
> smbCsi:
>   uri: "//10.0.0.201/RAID/vulcano/myinstance"   # IP, not hostname
> ```

> **ℹ️ Let's Encrypt HTTP-01 challenge**
>
> For automatic TLS via cert-manager, ports **80 and 443** must be reachable from the internet at the
> domain's public IP. Ensure your router forwards both ports to at least one cluster node running the
> nginx ingress controller.

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
        - bwSecretId: <uuid>
          secretKeyName: "bw-rabbitmq-password"
        - bwSecretId: <uuid>
          secretKeyName: "bw-rabbitmq-erlang-cookie"
      authToken:
        secretName: bw-auth-token
        secretKey: token

  # Custom PVC – e.g. CSI SMB or any other storage class
  - apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: vulcano-data-smb
      namespace: "{{ .Values.global.namespace }}"
      annotations:
        helm.sh/resource-policy: keep
    spec:
      accessModes:
        - ReadWriteMany
      storageClassName: "sp-tanzu2025-sms"
      resources:
        requests:
          storage: 8Gi
```

Then reference the PVC:

```yaml
vulcano:
  storage:
    existingClaim: "vulcano-data-smb"
```

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

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| adminUsers | string | `"admin1@domain.com\nadmin2@domain.com\n"` | List of email addresses for users with administrative privileges. One email per line. These users will have full system access including project deletion and user management. |
| adobe.apiKey | string | `"CCHomeWeb1"` | Adobe API Key for accessing Adobe Creative Cloud services |
| adobe.clientId | string | `""` | Adobe IMS Client ID for OAuth authentication flow |
| adobe.clientToken | string | `""` | OAuth access token for Adobe Creative Cloud Libraries API authentication |
| adobe.dumpFilepath | string | `""` | File path where a JSON dump of all available Adobe CC Libraries elements will be created |
| adobe.enabled | bool | `false` | Enable Adobe Creative Cloud Libraries integration for syncing MOGRT templates |
| adobe.librariesIgnore | string | `"\"Library to Ignore\""` | Comma-separated list of Adobe Creative Cloud Library names that should be excluded from synchronization |
| adobe.scan | string | `"false"` | Enable automatic synchronization of Adobe Creative Cloud Libraries every 2 minutes |
| adobe.secret | string | `""` | Adobe IMS Client Secret for OAuth authentication |
| affinity | object | `{}` | Affinity rules for pod scheduling |
| auth.keycloak.authority | string | `nil` | Keycloak authority URL |
| auth.keycloak.clientId | string | `nil` | Keycloak client ID |
| auth.keycloak.clientSecret | string | `nil` | Keycloak client secret |
| auth.microsoft.authority | string | `nil` | Microsoft Azure AD authority URL |
| auth.microsoft.clientId | string | `nil` | Microsoft Azure AD client ID |
| auth.mode | string | `"MICROSOFT"` | Authentication mode (MICROSOFT, KEYCLOAK, etc.) |
| auth.secret | string | `nil` | Authentication secret key |
| auth.serviceAdminPassword | string | `nil` | Service admin password for authentication |
| config.labels | object | `{"app":"vulcano","version":"1.9.13"}` | Labels for all resources |
| dataFeedMapping.ignoreDelete | string | `"false"` | Ignore Delete Messages from Datafeed |
| dataFeedMapping.skipUpdates | string | `"false"` | Skip Asset Creation for Updates from Datafeed |
| extraObjects | list | `[]` | Extra Kubernetes objects to deploy alongside the chart. Supports Helm templating via `tpl`. Useful for External/Bitwarden Secrets, custom PVCs, StorageClasses, etc. See *Advanced Configuration* above. |
| features.afxCreateMogrt | string | `"true"` | Enable creation of MOGRT files during rendering |
| features.afxRender | string | `"true"` | Enable After Effects rendering functionality |
| features.afxRenderMassJobLimit | string | `"-1"` | Maximum number of assets that can be rendered simultaneously in mass rendering operations |
| features.afxRenderOnDemand | string | `"false"` | Enable on-demand rendering capabilities |
| features.afxRenderOnDemandExtended | string | `"false"` | If enabled, users can both add an asset to a project and mark it as 'Preparing' |
| features.afxRenderPreview | string | `"true"` | Enable preview rendering functionality in AfxRenderer |
| features.cloudmode | string | `"false"` | Enable cloud-based rendering mode |
| features.ignoreMogrt | string | `"false"` | Ignore MOGRT files during template scanning and processing |
| features.logThirdPartyRequests | string | `"false"` | Enable detailed logging of all HTTP requests made to external APIs |
| features.maxNameLength | string | `"200"` | Maximum character limit for asset names and file names |
| folderScanner.allowEmptyFolder | string | `"true"` | Allow creation and preservation of empty folders in the file system structure |
| folderScanner.defaultBin | string | `"Templates"` | Default folder name used for organizing templates and assets when no specific bin is specified |
| folderScanner.maxDepth | string | `"10"` | Maximum folder depth level for recursive scanning operations |
| folderScanner.recreateMissingHighres | string | `"true"` | Automatically re-render missing high-resolution files when detected during system checks |
| folderScanner.startD3 | string | `"false"` | Enable Delta Tre sports data integration |
| folderScanner.startWatcher | string | `"true"` | Enable automatic file system monitoring to detect changes in template folders |
| folders.customCertificates | string | `"/etc/certs"` | Enable support for custom SSL certificates |
| folders.media.clientFolder | string | `"/data/highres"` | Client-side path mapping for media files in path replacement operations |
| folders.media.extension | string | `".mov"` | Comma-separated list of allowed media file extensions for processing |
| folders.media.folder | string | `"/data/highres"` | Root directory path where generated high-resolution media files are stored |
| folders.media.mediaExtension | string | `".mov"` | Comma-separated list of allowed media file extensions for processing |
| folders.media.templatesFolder | string | `"/data/highres_templates"` | Directory path containing After Effects project templates and MOGRT files |
| folders.output.deletedFolder | string | `"/highres_deleted"` | Folder path where deleted high-resolution rendered files are moved before permanent deletion |
| folders.output.deletedhires | string | `"/highres_deleted"` | Folder path where deleted high-resolution rendered files are moved before permanent deletion |
| folders.pathMapRenderNode | string | `"Z:"` | Path mapping configuration for render nodes in distributed rendering setups |
| folders.pathMapServer | string | `"/data"` | Server-side path mapping configuration for shared storage access |
| folders.proxy | string | `"/data/lowres"` | Directory path where low-resolution proxy files are stored |
| folders.templates | string | `"/data/templates"` | Root directory path containing all After Effects templates and project files |
| folders.templatesClient | string | `""` | Client-side path mapping for template files |
| folders.thumbnails | string | `"/data/thumbs"` | Directory path where thumbnail images are stored |
| folderscanner.mediaFolder.recreateFolderStructure | string | `"true"` | Recreate the folder structure for media folders |
| folderscanner.mediaFolder.templates.client | string | `"/Volumes/helmut_1/vulcano/highres_templates"` | Client-side path mapping for template media files. Used to replace server template paths with client-accessible paths in HiresApiDelegateImpl.mapHiresPath() for template folder access |
| global | object | `{"domain":"vulcano.example.com","namespace":"vulcano-app"}` | Global configuration for the Vulcano deployment |
| global.domain | string | `"vulcano.example.com"` | Domain name for ingress and services |
| global.namespace | string | `"vulcano-app"` | Kubernetes namespace for the deployment |
| helmut.apiToken | string | `""` | Authentication token for Helmut4 media asset management system integration |
| helmut.baseUrl | string | `nil` | Base URL of the Helmut4 server API (e.g., https://helmut.company.com/api) |
| helmut.clientId | string | `""` | OAuth client identifier for Helmut4 API authentication |
| helmut.clientSecret | string | `""` | OAuth client secret for secure Helmut4 API authentication |
| helmut.cosmo.baseBreadcrumb | string | `""` | Base breadcrumb path for Helmut4 Cosmo workspace navigation. Defines the starting point for project and asset browsing |
| helmut.cosmo.mappingDest | string | `""` | Destination path mapping for Helmut4 Cosmo integration. Maps Vulcano asset locations to Cosmo workspace structure |
| helmut.cosmo.mappingSrc | string | `""` | Source path mapping for Helmut4 Cosmo integration. Maps Cosmo workspace paths to Vulcano internal structure |
| helmut.cosmo.sync | string | `"false"` | Enable synchronization between Vulcano assets and Helmut4 Cosmo workspace. Keeps asset metadata and status in sync |
| helmut.enabled | bool | `false` | Enable Helmut4 media asset management system integration |
| helmut.logRequest | string | `"false"` | Enable detailed logging of HTTP requests made to Helmut4 API |
| helmut.pageSize | string | `"50"` | Number of items per page when fetching data from Helmut4 API |
| housekeeping.enabled | string | `"false"` | Enable automatic cleanup and maintenance tasks |
| housekeeping.maxAge | string | `"14"` | Maximum age in days for housekeeping items before they are automatically cleaned up |
| imagePullSecrets | object | `{"enabled":true,"secrets":[{"name":"docker-io"}]}` | Image Pull Secrets configuration |
| imagePullSecrets.enabled | bool | `true` | Enable image pull secrets |
| images | object | `{"vulcano":{"pullPolicy":"IfNotPresent","repository":"moovit/vulcano","tag":"1.9.13"}}` | Docker Image Configuration |
| images.vulcano.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| images.vulcano.repository | string | `"moovit/vulcano"` | Docker repository for Vulcano application |
| images.vulcano.tag | string | `"1.9.13"` | Docker image tag |
| integrations.helmut | object | `{"apiToken":"","baseUrl":"","clientId":"","clientSecret":"","cosmoBaseBreadcrumb":"","cosmoMappingDest":"","cosmoMappingSrc":"","cosmoSync":"false","logRequest":"false","pageSize":"50"}` | Authentication token for Helmut4 media asset management system integration |
| integrations.helmut.apiToken | string | `""` | Authentication token for Helmut4 media asset management system integration |
| integrations.helmut.baseUrl | string | `""` | Base URL of the Helmut4 server API (e.g., https://helmut.company.com/api) |
| integrations.helmut.clientId | string | `""` | OAuth client identifier for Helmut4 API authentication |
| integrations.helmut.clientSecret | string | `""` | OAuth client secret for secure Helmut4 API authentication |
| integrations.helmut.cosmoBaseBreadcrumb | string | `""` | Base breadcrumb path for Helmut4 Cosmo workspace navigation |
| integrations.helmut.cosmoMappingDest | string | `""` | Destination path mapping for Helmut4 Cosmo integration |
| integrations.helmut.cosmoMappingSrc | string | `""` | Source path mapping for Helmut4 Cosmo integration |
| integrations.helmut.cosmoSync | string | `"false"` | Enable synchronization between Vulcano assets and Helmut4 Cosmo workspace |
| integrations.helmut.logRequest | string | `"false"` | Enable detailed logging of HTTP requests made to Helmut4 API |
| integrations.helmut.pageSize | string | `"50"` | Number of items per page when fetching data from Helmut4 API |
| integrations.ndr | object | `{"bidLookupUrl":"","vdbPassword":"","vdbServer":"","vdbSimulate":"false","vdbUsername":"","wikiUrl":"","wildcardBid":""}` | URL endpoint for looking up BID information in the NDR VDB system |
| integrations.ndr.bidLookupUrl | string | `""` | URL endpoint for looking up BID (Broadcast ID) information in the NDR VDB system |
| integrations.ndr.vdbPassword | string | `""` | Password for authenticating with the NDR VDB system |
| integrations.ndr.vdbServer | string | `""` | Server hostname or URL for the NDR VDB system |
| integrations.ndr.vdbSimulate | string | `"false"` | Enable simulation mode for VDB operations without making actual network calls |
| integrations.ndr.vdbUsername | string | `""` | Username for authenticating with the NDR VDB system |
| integrations.ndr.wikiUrl | string | `""` | URL to the NDR VDB documentation wiki |
| integrations.ndr.wildcardBid | string | `""` | Wildcard BID pattern used for broadcast ID matching in the NDR VDB system |
| integrations.octopus | object | `{"api":"","clientDelayInMs":"5000","password":"","startClient":"false","username":""}` | API endpoint URL for Octopus newsroom system integration |
| integrations.octopus.api | string | `""` | API endpoint URL for Octopus newsroom system integration |
| integrations.octopus.clientDelayInMs | string | `"5000"` | Delay in milliseconds between Octopus client polling requests |
| integrations.octopus.password | string | `""` | Password for authenticating with the Octopus newsroom system |
| integrations.octopus.startClient | string | `"false"` | Enable the Octopus client for receiving and processing MOS messages |
| integrations.octopus.username | string | `""` | Username for authenticating with the Octopus newsroom system |
| integrations.vidispine | object | `{"baseUrl":"","baseUrlAuth":"","clientId":"","clientSecret":"","defaultLocation":"","locationValuesUrl":"","storage":"","workflow":"","workflowMogrt":"","workflowVersion":"","workflowVersionMogrt":""}` | Base URL for Vidispine media asset management system API |
| integrations.vidispine.baseUrl | string | `""` | Base URL for Vidispine media asset management system API |
| integrations.vidispine.baseUrlAuth | string | `""` | Authentication endpoint URL for Vidispine system |
| integrations.vidispine.clientId | string | `""` | OAuth client identifier for Vidispine API authentication |
| integrations.vidispine.clientSecret | string | `""` | OAuth client secret for secure Vidispine API authentication |
| integrations.vidispine.defaultLocation | string | `""` | Default location value to be pre-selected in the location selector |
| integrations.vidispine.locationValuesUrl | string | `""` | URL for retrieving allowed values for the Location metadata field from Vidispine |
| integrations.vidispine.storage | string | `""` | Vidispine storage identifier for file operations |
| integrations.vidispine.workflow | string | `""` | Default workflow identifier in Vidispine for processing uploaded assets |
| integrations.vidispine.workflowMogrt | string | `""` | Specific workflow identifier for MOGRT files in Vidispine |
| integrations.vidispine.workflowVersion | string | `""` | Version number of the default Vidispine workflow to use |
| integrations.vidispine.workflowVersionMogrt | string | `""` | Version number of the MOGRT-specific workflow in Vidispine |
| logging.fileMaxSize | string | `"10MB"` | Maximum size of the log file before it gets rotated |
| logging.fileName | string | `"/data/LOGS/vulcano_k8s.log"` | Path to the log file where application logs are written |
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
| management.prometheus.metrics.export.enabled | string | `"true"` |  |
| mongodb | object | `{...}` | MongoDB Configuration |
| mongodb.architecture | string | `"replicaset"` | MongoDB architecture (standalone or replicaset) |
| mongodb.auth.existingErlangCookieKey | string | `""` | *(n/a for MongoDB)* |
| mongodb.auth.existingPasswordKey | string | `"mongodb-root-password"` | Key inside `existingSecret` that holds the root password |
| mongodb.auth.existingSecret | string | `""` | Name of an existing Secret with MongoDB credentials. When set, `rootPassword` is ignored and no `mongodb-credentials` Secret is created by this chart |
| mongodb.auth.existingUsernameKey | string | `""` | Key inside `existingSecret` that holds the username. Leave empty to use `rootUser` directly |
| mongodb.auth.rootPassword | string | `"bitte"` | MongoDB root password (ignored when `existingSecret` is set) |
| mongodb.auth.rootUser | string | `"root"` | MongoDB root username |
| mongodb.enabled | bool | `true` | Enable MongoDB deployment as part of this release. Set to `false` when connecting to an external MongoDB (e.g. from `vulcano-common`) |
| mongodb.externalHost | string | `""` | External MongoDB hostname. When set (and `enabled=false`), Vulcano connects to this host. Credentials from `auth.rootUser` / `auth.rootPassword` (or `auth.existingSecret`) are still required. Example: `mongodb-headless.vulcano-common.svc.cluster.local` |
| mongodb.fullnameOverride | string | `"mongodb"` | Full name override for MongoDB resources |
| mongodb.persistence.enabled | bool | `true` | Enable MongoDB persistence |
| mongodb.persistence.resourcePolicy | string | `"keep"` | Resource policy for persistent volumes |
| mongodb.persistence.size | string | `"20Gi"` | MongoDB persistent volume size |
| mongodb.persistence.storageClassName | string | `""` | Storage class name for MongoDB |
| mongodb.replicaCount | int | `3` | Number of MongoDB replicas |
| ndr.bidLookupUrl | string | `nil` | URL endpoint for looking up BID (Broadcast ID) information in the NDR VDB system |
| ndr.wikiUrl | string | `nil` | URL to the NDR VDB documentation wiki |
| ndr.wildcardBid | string | `"xxxxx"` | Wildcard BID pattern used for broadcast ID matching in the NDR VDB system |
| nodeSelector | object | `{}` | Node selector for pod scheduling |
| octopus.api | string | `""` | API endpoint URL for Octopus newsroom system integration |
| octopus.client.delayInMS | string | `"1000"` | Delay in milliseconds between Octopus client polling requests |
| octopus.enabled | bool | `false` | Enable Octopus newsroom system integration for receiving MOS messages |
| octopus.password | string | `""` | Password for authenticating with the Octopus newsroom system |
| octopus.startClient | string | `"false"` | Enable the Octopus client for receiving and processing MOS messages |
| octopus.username | string | `""` | Username for authenticating with the Octopus newsroom system |
| podSecurityPolicy.enabled | bool | `false` |  |
| project.delete.ownerOnly | string | `"true"` | Only allow project deletion by the owner |
| project.sendToUrls | string | `""` | URLs to send project data to external systems |
| rabbitmq | object | `{...}` | RabbitMQ Configuration |
| rabbitmq.auth.erlangCookie | string | `"VULCANO_SECRET_COOKIE"` | Erlang cookie for RabbitMQ clustering (ignored when `existingSecret` is set) |
| rabbitmq.auth.existingErlangCookieKey | string | `"rabbitmq-erlang-cookie"` | Key inside `existingSecret` that holds the Erlang cookie |
| rabbitmq.auth.existingPasswordKey | string | `"rabbitmq-password"` | Key inside `existingSecret` that holds the RabbitMQ password |
| rabbitmq.auth.existingSecret | string | `""` | Name of an existing Secret with RabbitMQ credentials. When set, `password` and `erlangCookie` are ignored and no `rabbitmq-credentials` Secret is created by this chart |
| rabbitmq.auth.password | string | `"vulcano0479"` | RabbitMQ admin password (ignored when `existingSecret` is set) |
| rabbitmq.auth.username | string | `"vulcano"` | RabbitMQ admin username |
| rabbitmq.enabled | bool | `true` | Enable RabbitMQ deployment as part of this release. Set to `false` when connecting to an external RabbitMQ (e.g. from `vulcano-common`) |
| rabbitmq.externalHost | string | `""` | External RabbitMQ hostname. When set (and `enabled=false`), Vulcano connects to this host. Credentials from `auth.username` / `auth.password` (or `auth.existingSecret`) are still required. Example: `rabbitmq.vulcano-common.svc.cluster.local` |
| rabbitmq.fullnameOverride | string | `"rabbitmq"` | Full name override for RabbitMQ resources |
| rabbitmq.jobUpdateQueue | string | `"vulcano-job-updates"` | Queue name for job updates |
| rabbitmq.metrics.enabled | bool | `false` | Enable RabbitMQ metrics |
| rabbitmq.persistence.enabled | bool | `false` | Enable RabbitMQ persistence |
| rabbitmq.replicaCount | int | `3` | Number of RabbitMQ replicas |
| rabbitmq.service.type | string | `"NodePort"` | RabbitMQ service type (ClusterIP, NodePort, LoadBalancer) |
| rbac.create | bool | `true` |  |
| securityContext.fsGroup | int | `1001` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `1001` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `"vulcano"` |  |
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
| vdb.server | string | `""` | Server hostname or URL for the NDR VDB system |
| vdb.simulate | string | `"true"` | Enable simulation mode for VDB operations without making actual network calls |
| vidispine.baseUrl | string | `""` | Base URL for Vidispine media asset management system API |
| vidispine.baseUrlAuth | string | `""` | Authentication endpoint URL for Vidispine system |
| vidispine.clientId | string | `""` | OAuth client identifier for Vidispine API authentication |
| vidispine.clientSecret | string | `""` | OAuth client secret for secure Vidispine API authentication |
| vidispine.defaultLocation | string | `""` | Default location value to be pre-selected in the location selector |
| vidispine.enabled | bool | `false` |  |
| vidispine.locationValuesUrl | string | `""` | URL for retrieving allowed values for the Location metadata field from Vidispine |
| vidispine.storage | string | `""` | Vidispine storage identifier for file operations |
| vidispine.workflow | string | `""` | Default workflow identifier in Vidispine for processing uploaded assets |
| vidispine.workflowMogrt | string | `""` | Specific workflow identifier for MOGRT files in Vidispine |
| vidispine.workflowMogrt | string | `""` | Specific workflow identifier for MOGRT files in Vidispine |
| vidispine.workflowVersion | string | `""` | Version number of the default Vidispine workflow to use |
| vidispine.workflowVersionMogrt | string | `""` | Version number of the MOGRT-specific workflow in Vidispine |
| vulcano.allowDownload | string | `"true"` | Enable download functionality for rendered assets in the web interface |
| vulcano.allowDuplicates | string | `"true"` | Allow creation of assets with duplicate names |
| vulcano.allowLinebreaksByDefault | string | `"false"` | Enable line breaks in text properties by default when creating new assets |
| vulcano.autologout.disable | string | `"false"` | Completely disable automatic logout functionality |
| vulcano.autologout.hours | string | `"1"` | Number of hours of inactivity before users are automatically logged out |
| vulcano.completedAssetInterceptor | string | `""` | HTTP endpoint URL that receives completed asset data and can MODIFY it before final storage |
| vulcano.completedWebhook | string | `""` | HTTP webhook URL for NOTIFICATION purposes only - receives completed asset data but cannot modify it |
| vulcano.createAssetInterceptor | string | `""` | HTTP endpoint URL that will be called when a new asset is created |
| vulcano.customCertificates | string | `"/etc/certs"` | Enable support for custom SSL certificates |
| vulcano.enabled | bool | `true` |  |
| vulcano.folder.createUserFolder | string | `"false"` | Enable creation of user-specific folders for organizing generated assets |
| vulcano.folder.globalParent | string | `""` | Global parent folder path component inserted in generated asset folder structure when user folders are enabled |
| vulcano.frontend.enableTimecodeForAssets | string | `"false"` | If enabled, a Timecode input will appear in the PreferenceView for assets |
| vulcano.home.base | string | `"/home"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/proxy-body-size" | string | `"500m"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/proxy-read-timeout" | string | `"3600"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/proxy-send-timeout" | string | `"3600"` |  |
| vulcano.ingress.annotations."nginx.ingress.kubernetes.io/server-snippets" | string | `"location /ws {\n proxy_set_header Upgrade $http_upgrade;\n proxy_http_version 1.1;\n proxy_set_header X-Forwarded-Host $http_host;\n proxy_set_header X-Forwarded-Proto $scheme;\n proxy_set_header X-Forwarded-For $remote_addr;\n proxy_set_header Host $host;\n proxy_set_header Connection \"upgrade\";\n proxy_cache_bypass $http_upgrade;\n}\n"` |  |
| vulcano.ingress.className | string | `"nginx"` | Ingress class name |
| vulcano.ingress.enabled | bool | `true` | Enable ingress |
| vulcano.ingress.host | string | `"vulcano.example.com"` | Ingress host |
| vulcano.ingress.path | string | `"/"` |  |
| vulcano.ingress.tls | object | `{"enabled":false}` | Enable TLS |
| vulcano.ingress.tls.enabled | bool | `false` |  |
| vulcano.ingress.tls.existing.secretName | string | `"tls-vulcano-cert"` |  |
| vulcano.ingress.tls.letsencrypt.clusterIssuer | string | `"letsencrypt-prod"` |  |
| vulcano.ingress.tls.letsencrypt.email | string | `"admin@example.com"` |  |
| vulcano.ingress.tls.letsencrypt.enabled | bool | `false` |  |
| vulcano.ingress.tls.source | string | `"letsencrypt"` |  |
| vulcano.license | object | `{"key":""}` | JWT license key for application licensing |
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
| vulcano.storage.annotations | object | `{}` | Annotations for the PVC. Use `helm.sh/resource-policy: keep` to prevent deletion on `helm uninstall` |
| vulcano.storage.existingClaim | string | `""` | Name of an existing PVC to mount instead of creating a new one. No PVC is created when set. Pair with `extraObjects` to manage the PVC via the chart |
| vulcano.storage.labels | object | `{}` | Additional labels for the PVC |
| vulcano.storage.mountPath | string | `"/data"` |  |
| vulcano.storage.pvc | string | `"smb-vulcano-data"` | Name of the PVC created by the chart (ignored when `existingClaim` is set) |
| vulcano.storage.size | string | `"10Gi"` |  |
| vulcano.storage.storageClass | string | `"longhorn"` | Storage class for the PVC. Leave empty for cluster default, set to `"-"` to omit `storageClassName` entirely |
| vulcano.subtitle | string | `""` | Custom subtitle text displayed in the web interface header |
| vulcano.useCustomFileName | string | `"false"` | Allow users to specify custom filenames when creating assets instead of using auto-generated names |
| vulcano.webconfig.disable | string | `"false"` | Disable the web-based configuration interface |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
