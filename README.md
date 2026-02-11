# vulcano

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.5.140](https://img.shields.io/badge/AppVersion-1.5.140-informational?style=flat-square)

Vulcano - Complete application deployment with MongoDB, RabbitMQ, and optional CSI driver

**Homepage:** <https://github.com/moovit/vulcano>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Moovit | <support@moovit.de> |  |

## Source Code

* <https://github.com/moovit/vulcano>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://registry-1.docker.io/cloudpirates | mongodb(mongodb) | 0.10.3 |
| oci://registry-1.docker.io/cloudpirates | rabbitmq(rabbitmq) | 0.2.12 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| adminUsers | string | `"admin1@domain.com\nadmin2@domain.com\n"` |  |
| adobe.apiKey | string | `"CCHomeWeb1"` | Adobe API Key for accessing Adobe Creative Cloud services |
| adobe.clientId | string | `""` | Adobe IMS Client ID for OAuth authentication flow |
| adobe.clientToken | string | `""` | OAuth access token for Adobe Creative Cloud Libraries API authentication |
| adobe.dumpFilepath | string | `""` | File path where a JSON dump of all available Adobe CC Libraries elements will be created |
| adobe.enabled | bool | `false` |  |
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
| config.labels | object | `{"app":"vulcano","version":"1.9.12"}` | Labels for all resources |
| dataFeedMapping.ignoreDelete | string | `"false"` | Ignore Delete Messages from Datafeed |
| dataFeedMapping.skipUpdates | string | `"false"` | Skip Asset Creation for Updates from Datafeed |
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
| folderscanner.mediaFolder.recreateFolderStructure | string | `"true"` |  |
| folderscanner.mediaFolder.templates.client | string | `"/Volumes/helmut_1/vulcano/highres_templates"` |  |
| global | object | `{"domain":"vulcano.example.com","namespace":"vulcano-app"}` | Global configuration for the Vulcano deployment |
| global.domain | string | `"vulcano.example.com"` | Domain name for ingress and services |
| global.namespace | string | `"vulcano-app"` | Kubernetes namespace for the deployment |
| helmut.apiToken | string | `""` | Authentication token for Helmut4 media asset management system integration |
| helmut.baseUrl | string | `nil` | Base URL of the Helmut4 server API (e.g., https://helmut.company.com/api) |
| helmut.clientId | string | `""` | OAuth client identifier for Helmut4 API authentication |
| helmut.clientSecret | string | `""` | OAuth client secret for secure Helmut4 API authentication |
| helmut.cosmo.baseBreadcrumb | string | `""` |  |
| helmut.cosmo.mappingDest | string | `""` |  |
| helmut.cosmo.mappingSrc | string | `""` |  |
| helmut.cosmo.sync | string | `"false"` |  |
| helmut.enabled | bool | `false` |  |
| helmut.logRequest | string | `"false"` | Enable detailed logging of HTTP requests made to Helmut4 API |
| helmut.pageSize | string | `"50"` |  |
| housekeeping.enabled | string | `"false"` | Enable automatic cleanup and maintenance tasks |
| housekeeping.maxAge | string | `"14"` | Maximum age in days for housekeeping items before they are automatically cleaned up |
| imagePullSecrets | object | `{"enabled":true,"secrets":[{"name":"docker-io"}]}` | Image Pull Secrets configuration |
| imagePullSecrets.enabled | bool | `true` | Enable image pull secrets |
| images | object | `{"vulcano":{"pullPolicy":"IfNotPresent","repository":"moovit/vulcano","tag":"1.9.12"}}` | Docker Image Configuration |
| images.vulcano.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| images.vulcano.repository | string | `"moovit/vulcano"` | Docker repository for Vulcano application |
| images.vulcano.tag | string | `"1.9.12"` | Docker image tag |
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
| logging.fileMaxSize | string | `"10MB"` |  |
| logging.fileName | string | `"/data/LOGS/vulcano_k8s.log"` |  |
| logging.level.org | string | `"INFO"` |  |
| logging.level.securityFilter | string | `"WARN"` |  |
| management.endpoint.caches.enabled | string | `"true"` |  |
| management.endpoint.health.group.readiness.include | string | `"rabbit,diskSpace,mongo,ping"` |  |
| management.endpoint.health.showDetails | string | `"always"` |  |
| management.endpoint.prometheus.enabled | string | `"true"` |  |
| management.endpoints.web.exposure.include | string | `"health,beans,loggers,env,prometheus,metrics"` |  |
| management.health.livenessstate.enabled | string | `"true"` |  |
| management.health.livenessstate.showDetails | string | `"always"` |  |
| management.health.readinessstate.enabled | string | `"true"` |  |
| management.health.readinessstate.showDetails | string | `"always"` |  |
| management.metrics.distribution.percentilesHistogram | string | `"true"` |  |
| management.metrics.distribution.slo | string | `"50ms, 100ms, 200ms, 300ms, 500ms, 1s"` |  |
| management.metrics.enable.all | string | `"true"` |  |
| management.metrics.tags.application | string | `"vulcano-backend"` |  |
| management.prometheus.metrics.export.enabled | string | `"true"` |  |
| mongodb | object | `{"architecture":"replicaset","auth":{"rootPassword":"bitte","rootUser":"root"},"enabled":true,"fullnameOverride":"mongodb","metrics":{"enabled":false},"persistence":{"enabled":true,"resourcePolicy":"keep","size":"20Gi","storageClassName":""},"replicaCount":3}` | MongoDB Configuration |
| mongodb.architecture | string | `"replicaset"` | MongoDB architecture (standalone or replicaset) |
| mongodb.auth.rootPassword | string | `"bitte"` | MongoDB root password |
| mongodb.auth.rootUser | string | `"root"` | MongoDB root username |
| mongodb.enabled | bool | `true` | Enable MongoDB deployment |
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
| octopus.enabled | bool | `false` |  |
| octopus.password | string | `""` | Password for authenticating with the Octopus newsroom system |
| octopus.startClient | string | `"false"` | Enable the Octopus client for receiving and processing MOS messages |
| octopus.username | string | `""` | Username for authenticating with the Octopus newsroom system |
| podSecurityPolicy.enabled | bool | `false` |  |
| project.delete.ownerOnly | string | `"true"` | Only allow project deletion by the owner |
| project.sendToUrls | string | `""` | URLs to send project data to external systems |
| rabbitmq | object | `{"auth":{"erlangCookie":"VULCANO_SECRET_COOKIE","password":"vulcano0479","username":"vulcano"},"enabled":true,"fullnameOverride":"rabbitmq","jobUpdateQueue":"vulcano-job-updates","metrics":{"enabled":false},"persistence":{"enabled":false},"replicaCount":3,"service":{"type":"NodePort"}}` | RabbitMQ Configuration |
| rabbitmq.auth.erlangCookie | string | `"VULCANO_SECRET_COOKIE"` | Erlang cookie for RabbitMQ clustering |
| rabbitmq.auth.password | string | `"vulcano0479"` | RabbitMQ admin password |
| rabbitmq.auth.username | string | `"vulcano"` | RabbitMQ admin username |
| rabbitmq.enabled | bool | `true` | Enable RabbitMQ deployment |
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
| vulcano.storage.mountPath | string | `"/data"` |  |
| vulcano.storage.pvc | string | `"smb-vulcano-data"` |  |
| vulcano.storage.size | string | `"10Gi"` |  |
| vulcano.subtitle | string | `""` | Custom subtitle text displayed in the web interface header |
| vulcano.useCustomFileName | string | `"false"` | Allow users to specify custom filenames when creating assets instead of using auto-generated names |
| vulcano.webconfig.disable | string | `"false"` | Disable the web-based configuration interface |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
