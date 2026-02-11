# Vulcano Helm Chart

A complete Kubernetes Helm chart for deploying the Vulcano application stack with optional MongoDB, RabbitMQ, and CSI SMB driver support.

## Features

- **Self-contained**: Removes ohmyhelm dependency, all deployments handled natively
- **Optional Components**: MongoDB and RabbitMQ can be enabled/disabled
- **SMB CSI Support**: Optional SMB CSI driver for file sharing
- **Complete RBAC**: Includes ServiceAccount, ClusterRole, and ClusterRoleBinding
- **ConfigMaps & Secrets**: Comprehensive configuration management
- **Production Ready**: Includes resource limits, probes, security contexts

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- (Optional) CSI SMB Driver v1.14.0+ for SMB mount support

## Installation

### 1. Add the Helm Repository (Optional)

```bash
# If using a custom repository
helm repo add vulcano https://example.com/helm/vulcano
helm repo update
```

### 2. Create Namespace and Install

```bash
# Create namespace
kubectl create namespace vulcano-app

# Install the chart
helm install vulcano ./helm-chart-new \
  -n vulcano-app \
  -f values.yaml
```

### 3. Installation with Custom Values

```bash
helm install vulcano ./helm-chart-new \
  -n vulcano-app \
  --set global.domain="vulcano.example.com" \
  --set mongodb.enabled=true \
  --set rabbitmq.enabled=true \
  --set smbCsi.enabled=true \
  --set smbCsi.uri="//storage.example.com/vulcano" \
  --set smbCsi.username="storageuser" \
  --set smbCsi.password="storagepass"
```

## Configuration

### Global Settings

| Key | Default | Description |
|-----|---------|-------------|
| `global.namespace` | `vulcano-app` | Kubernetes namespace |
| `global.domain` | `vulcano.example.com` | Domain for ingress |

### Image Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `images.vulcano.repository` | `moovit/vulcano` | Vulcano image repository |
| `images.vulcano.tag` | `1.5.140` | Vulcano image tag |

### Vulcano Service Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `vulcano.enabled` | `true` | Enable Vulcano deployment |
| `vulcano.replicaCount` | `1` | Number of replicas |
| `vulcano.service.type` | `ClusterIP` | Kubernetes service type |
| `vulcano.service.port` | `8889` | Service port |
| `vulcano.ingress.enabled` | `true` | Enable ingress |
| `vulcano.ingress.host` | `vulcano.example.com` | Ingress hostname |
| `vulcano.ingress.tls.enabled` | `false` | Enable TLS |
| `vulcano.ingress.tls.source` | `letsencrypt` | Certificate source: `letsencrypt` or `existing` |
| `vulcano.ingress.tls.letsencrypt.enabled` | `false` | Enable Let's Encrypt |
| `vulcano.ingress.tls.letsencrypt.clusterIssuer` | `letsencrypt-prod` | cert-manager cluster issuer |
| `vulcano.ingress.tls.letsencrypt.email` | `admin@example.com` | Email for Let's Encrypt |
| `vulcano.ingress.tls.existing.secretName` | `tls-vulcano-cert` | Existing TLS secret name |

### MongoDB Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `mongodb.enabled` | `true` | Enable MongoDB |
| `mongodb.auth.rootUser` | `root` | MongoDB root user |
| `mongodb.auth.rootPassword` | `bitte` | MongoDB root password |
| `mongodb.persistence.size` | `20Gi` | MongoDB storage size |

### RabbitMQ Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `rabbitmq.enabled` | `true` | Enable RabbitMQ |
| `rabbitmq.auth.username` | `vulcano` | RabbitMQ username |
| `rabbitmq.auth.password` | `vulcano0479` | RabbitMQ password |
| `rabbitmq.persistence.size` | `20Gi` | RabbitMQ storage size |

### SMB CSI Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `smbCsi.enabled` | `false` | Enable SMB CSI driver |
| `smbCsi.username` | `username` | SMB username |
| `smbCsi.password` | `password` | SMB password |
| `smbCsi.uri` | `//xxx.xxx.xxx.xxx/mountpoint` | SMB UNC path |

### Vulcano Folders Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `folders.templates` | `/data/_TEMPLATES` | Templates folder path |
| `folders.media.folder` | `/data/MEDIA` | Media folder path |
| `folders.proxy` | `/data/PROXY` | Proxy files folder |
| `folders.thumbnails` | `/data/THUMBS` | Thumbnails folder |

## Usage Examples

### Minimal Installation (No MongoDB/RabbitMQ)

```bash
helm install vulcano ./helm-chart-new \
  -n vulcano-app \
  --set mongodb.enabled=false \
  --set rabbitmq.enabled=false \
  --set 'mongodb.externalHost=mongodb.external.example.com' \
  --set 'rabbitmq.externalHost=rabbitmq.external.example.com'
```

### Full Production Installation

```bash
helm install vulcano ./helm-chart-new \
  -n vulcano-app \
  -f production-values.yaml \
  --set smbCsi.enabled=true \
  --set vuln cano.replicaCount=3 \
  --set mongodb.replicaCount=3 \
  --set rabbitmq.replicaCount=3
```

### Using External MongoDB and RabbitMQ

Create a custom `values.yaml`:

```yaml
mongodb:
  enabled: false
  externalHost: "mongodb.example.com"

rabbitmq:
  enabled: false
  externalHost: "rabbitmq.example.com"
```

Then install:

```bash
helm install vulcano ./helm-chart-new -n vulcano-app -f values.yaml
```

## Upgrading

```bash
# Update chart values
helm upgrade vulcano ./helm-chart-new \
  -n vulcano-app \
  -f values.yaml
```

## Uninstalling

```bash
# Remove the release (keeps PVCs by default)
helm uninstall vulcano -n vulcano-app

# To delete all resources including PVCs
kubectl delete pvc --all -n vulcano-app
```

## Troubleshooting

### Check Deployment Status

```bash
kubectl get deployments -n vulcano-app
kubectl get pods -n vulcano-app
kubectl logs deployment/vulcano -n vulcano-app
```

### Check Services

```bash
kubectl get svc -n vulcano-app
kubectl get ingress -n vulcano-app
```

### MongoDB Connection Issues

```bash
# Check MongoDB credentials
kubectl get secret mongodb-credentials -n vulcano-app -o yaml

# Test MongoDB connection
kubectl run -it --rm debug --image=mongo:latest --restart=Never -- \
  mongosh -u root -p bitte mongodb:27017
```

### RabbitMQ Connection Issues

```bash
# Check RabbitMQ credentials
kubectl get secret rabbitmq-credentials -n vulcano-app -o yaml

# Access RabbitMQ management UI
kubectl port-forward svc/rabbitmq 15672:15672 -n vulcano-app
# http://localhost:15672 (user: vulcano, password: vulcano0479)
```

## Security Considerations

1. **Change Default Passwords**: Update MongoDB and RabbitMQ passwords in production
2. **Use TLS/SSL**: Enable HTTPS for ingress
   - **Let's Encrypt**: Automatic certificates via cert-manager
   - **Existing Certificate**: Use pre-generated TLS certificates
3. **Network Policies**: Implement network policies to restrict traffic
4. **RBAC**: Review and restrict RBAC permissions as needed
5. **Secret Management**: Use Kubernetes secrets manager (e.g., Sealed Secrets, HashiCorp Vault)

## Storage

### SMB CSI Driver Installation (Optional)

```bash
# Add the CSI driver Helm repository
helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts

# Install the CSI driver
helm install csi-driver-smb csi-driver-smb/csi-driver-smb \
  --namespace kube-system \
  --set image.smb.tag=v1.14.0
```

## Architecture

The chart deploys the following components:

- **Vulcano** - Main application backend
- **MongoDB** (Optional) - Document database
- **RabbitMQ** (Optional) - Message broker
- **Ingress** - HTTP(S) entry point with TLS support
- **Services** - Internal service discovery
- **Persistent Volumes** - Data storage

All components run in the specified namespace with proper RBAC and security contexts.

## Contributing

For issues or improvements, please submit a pull request or open an issue.

## License

Apache License 2.0
