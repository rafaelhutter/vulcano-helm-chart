# Vulcano Helm Chart Installation Guide

This guide provides step-by-step instructions for deploying Vulcano with the Helm chart.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Installation Methods](#installation-methods)
4. [Configuration](#configuration)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

Before installing, ensure you have:

- Kubernetes cluster (v1.19+)
- Helm 3.0+
- kubectl configured to access your cluster
- At least 8 GB RAM and 20 GB storage available

### Optional but Recommended

- CSI SMB Driver (for SMB mounts)
- cert-manager (for TLS certificates)
- An ingress controller (for ingress). **Note:** ingress-nginx is retired (EOL March 2026,
  no further security patches — https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/).
  For new clusters prefer the Gateway API (set `vulcano.gateway.enabled=true`; requires the
  Gateway API CRDs + a Gateway controller) or a maintained alternative Ingress controller.

## Quick Start

The fastest way to get started — assumes you are inside the chart directory:

```bash
# 1. Create namespace
kubectl create namespace vulcano-app

# 2. Install with defaults (includes MongoDB and RabbitMQ)
helm install vulcano . -n vulcano-app

# 3. Wait for the pods to start
kubectl get pods -n vulcano-app -w

# 4. Access the service
kubectl port-forward svc/vulcano 8889:8889 -n vulcano-app
# Open http://localhost:8889
```

## Installation Methods

### Method 1: Default installation (local chart)

```bash
helm install vulcano . -n vulcano-app
```

This deploys:
- Vulcano application
- MongoDB (3 replicas by default)
- RabbitMQ (3 replicas by default)
- All required RBAC and service accounts

### Method 2: Production installation

```bash
# Create namespace
kubectl create namespace vulcano-prod

# Install with the customer values template
helm install vulcano . \
  -n vulcano-prod \
  -f examples/values.yaml
```

Update at least the following in `examples/values.yaml` (or in your own copy) before installing:

```yaml
auth:
  microsoft:
    authority: "https://login.microsoftonline.com/YOUR_TENANT_ID"
    clientId: "YOUR_CLIENT_ID"

mongodb:
  auth:
    rootPassword: "YOUR_SECURE_PASSWORD"

rabbitmq:
  auth:
    password: "YOUR_SECURE_PASSWORD"
    erlangCookie: "YOUR_SECURE_COOKIE"

smbCsi:
  username: "YOUR_SMB_USER"
  password: "YOUR_SMB_PASSWORD"
  uri: "//your-nas.example.com/vulcano"
```

### Method 3: Shared services (multi-instance)

If you want to deploy MongoDB and RabbitMQ **once** and point multiple Vulcano releases at them, see the *Shared Services / Multi-Instance Deployment* section in [README.md](README.md) and use the templates in `examples/`:

- `examples/shared-services-values.yaml` — deploys MongoDB + RabbitMQ only (e.g. namespace `vulcano-common`)
- `examples/vulcano-only-values.yaml` — deploys a Vulcano instance pointing at the shared services

### Method 4: Install from the GitHub Pages Helm repository (recommended)

The simplest installation method — install the chart straight from the published Helm repository:

```bash
# Add the repository
helm repo add rafaelhutter https://rafaelhutter.github.io/vulcano-helm-chart
helm repo update

# Create the namespace
kubectl create namespace vulcano-app

# Install the chart
helm install vulcano rafaelhutter/vulcano \
  --version 1.3.0 \
  -n vulcano-app \
  -f custom-values.yaml
```

The repository is rebuilt automatically on every push to `main`.

### Method 5: External MongoDB and RabbitMQ

If you already have MongoDB and RabbitMQ services available:

```bash
helm install vulcano . \
  -n vulcano-app \
  --set mongodb.enabled=false \
  --set rabbitmq.enabled=false \
  --set mongodb.externalHost="mongodb.your-domain.com" \
  --set rabbitmq.externalHost="rabbitmq.your-domain.com"
```

## Configuration

### Common Configuration Options

#### 1. Change image versions

```bash
helm install vulcano . -n vulcano-app \
  --set images.vulcano.tag="1.9.31"
```

#### 2. Configure ingress with Let's Encrypt

```bash
helm install vulcano . -n vulcano-app \
  --set vulcano.ingress.hosts[0]="vulcano.example.com" \
  --set vulcano.ingress.tls.enabled=true \
  --set vulcano.ingress.tls.source="letsencrypt" \
  --set vulcano.ingress.tls.letsencrypt.enabled=true \
  --set vulcano.ingress.tls.letsencrypt.clusterIssuer="letsencrypt-prod" \
  --set vulcano.ingress.tls.letsencrypt.email="admin@example.com"
```

#### 2b. Configure ingress with an existing certificate

```bash
helm install vulcano . -n vulcano-app \
  --set vulcano.ingress.hosts[0]="vulcano.example.com" \
  --set vulcano.ingress.tls.enabled=true \
  --set vulcano.ingress.tls.source="existing" \
  --set vulcano.ingress.tls.existing.secretName="tls-vulcano-cert"
```

#### 3. Enable the SMB CSI driver

First, install the CSI driver:

```bash
helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
helm install csi-driver-smb csi-driver-smb/csi-driver-smb \
  --namespace kube-system
```

Then enable it in the Vulcano chart:

```bash
helm install vulcano . -n vulcano-app \
  --set smbCsi.enabled=true \
  --set smbCsi.uri="//storage.example.com/vulcano" \
  --set smbCsi.username="storageuser" \
  --set smbCsi.password="storagepass"
```

#### 4. Scale to multiple replicas

```bash
helm install vulcano . -n vulcano-app \
  --set vulcano.replicaCount=3 \
  --set mongodb.replicaCount=3 \
  --set rabbitmq.replicaCount=3
```

#### 5. Configure resource limits

```bash
helm install vulcano . -n vulcano-app \
  --set 'vulcano.resources.requests.cpu=1000m' \
  --set 'vulcano.resources.limits.cpu=2000m' \
  --set 'vulcano.resources.requests.memory=2Gi' \
  --set 'vulcano.resources.limits.memory=4Gi'
```

## Verification

### Check deployment status

```bash
# Check pods
kubectl get pods -n vulcano-app
kubectl describe pod -n vulcano-app <pod-name>

# Check services
kubectl get svc -n vulcano-app

# Check ingress
kubectl get ingress -n vulcano-app

# View logs
kubectl logs deployment/vulcano -n vulcano-app
```

### Verify MongoDB connection

```bash
# Port-forward to MongoDB
kubectl port-forward svc/mongodb 27017:27017 -n vulcano-app &

# Test the connection
mongosh -u root -p bitte localhost:27017

# Inside the MongoDB shell
> show dbs
> use vulcano
> db.getCollectionNames()
```

### Verify RabbitMQ connection

```bash
# Access the RabbitMQ management UI
kubectl port-forward svc/rabbitmq 15672:15672 -n vulcano-app &

# Open http://localhost:15672 in your browser
# Default credentials: vulcano / vulcano0479
```

### Verify the Vulcano application

```bash
# Port-forward to Vulcano
kubectl port-forward svc/vulcano 8889:8889 -n vulcano-app &

# Test the application
curl http://localhost:8889/actuator/health
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n vulcano-app

# Get detailed pod information
kubectl describe pod -n vulcano-app <pod-name>

# Check namespace events
kubectl get events -n vulcano-app --sort-by='.lastTimestamp'
```

### Memory/CPU issues

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n vulcano-app

# Increase resources in the chart
helm upgrade vulcano . -n vulcano-app \
  --set 'vulcano.resources.limits.memory=8Gi'
```

### MongoDB connection issues

```bash
# Check MongoDB pod logs
kubectl logs -n vulcano-app mongodb-0

# Inspect credentials
kubectl get secret mongodb-credentials -n vulcano-app -o yaml

# Test the connection from an ephemeral MongoDB client pod
kubectl run -it --rm mongodb-test --image=mongo:latest --restart=Never -- \
  mongosh -u root -p $(kubectl get secret mongodb-credentials -n vulcano-app -o jsonpath='{.data.password}' | base64 -d) mongodb:27017
```

### RabbitMQ connection issues

```bash
# Check RabbitMQ pod logs
kubectl logs -n vulcano-app rabbitmq-0

# Inspect credentials
kubectl get secret rabbitmq-credentials -n vulcano-app -o yaml

# Check RabbitMQ status
kubectl exec -it rabbitmq-0 -n vulcano-app -- rabbitmqctl status
```

### Ingress not working

```bash
# Check ingress status
kubectl get ingress -n vulcano-app
kubectl describe ingress vulcano -n vulcano-app

# Verify the ingress controller
kubectl get ingressclass
kubectl get pods -n ingress-nginx

# Check DNS resolution
nslookup vulcano.example.com
```

### PVC not binding

```bash
# Check PVC status
kubectl get pvc -n vulcano-app
kubectl describe pvc -n vulcano-app smb-vulcano-data

# List available storage classes
kubectl get storageclass

# Check PV status
kubectl get pv
```

## Upgrading

```bash
# Inspect current values
helm get values vulcano -n vulcano-app

# Upgrade with new values
helm upgrade vulcano . -n vulcano-app \
  -f updated-values.yaml

# Watch the rollout
kubectl rollout status deployment/vulcano -n vulcano-app
```

## Uninstalling

```bash
# Delete the Helm release
helm uninstall vulcano -n vulcano-app

# Keeping the namespace and PVCs is fine for later reuse.
# To remove everything:
kubectl delete namespace vulcano-app
```

## Support

For issues, questions, or contributions:

1. Check the troubleshooting section above
2. Review Kubernetes events: `kubectl get events -n vulcano-app`
3. Check pod logs: `kubectl logs deployment/vulcano -n vulcano-app`
4. Contact support with pod logs and cluster information

## Security Best Practices

1. **Change default passwords**
   - MongoDB root password
   - RabbitMQ credentials
   - SMB credentials

2. **Use TLS/SSL**
   - **Option 1: Let's Encrypt** — enable automatic certificate generation via cert-manager
     ```bash
     --set vulcano.ingress.tls.enabled=true \
     --set vulcano.ingress.tls.source="letsencrypt" \
     --set vulcano.ingress.tls.letsencrypt.enabled=true \
     --set vulcano.ingress.tls.letsencrypt.clusterIssuer="letsencrypt-prod"
     ```
   - **Option 2: Existing certificate** — use a pre-generated TLS secret
     ```bash
     # First, create the TLS secret
     kubectl create secret tls tls-vulcano-cert \
       --cert=path/to/tls.crt \
       --key=path/to/tls.key \
       -n vulcano-app

     # Then enable it in Helm
     --set vulcano.ingress.tls.enabled=true \
     --set vulcano.ingress.tls.source="existing" \
     --set vulcano.ingress.tls.existing.secretName="tls-vulcano-cert"
     ```

3. **Implement network policies**
   - Restrict inter-pod traffic
   - Limit ingress/egress traffic

4. **Use a secrets manager**
   - Integrate with Vault, External Secrets Operator, Sealed Secrets, etc.
   - Do not store secrets in Git

5. **Regular backups**
   - Back up MongoDB data
   - Back up RabbitMQ configuration

6. **Monitor and audit**
   - Enable logging
   - Monitor resource usage
   - Audit cluster access
