# Vulcano Helm Chart Installation Guide

This guide provides step-by-step instructions for deploying Vulcano using the Helm chart.

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
- At least 8GB RAM and 20GB storage available

### Optional but Recommended

- CSI SMB Driver (for SMB mounts)
- cert-manager (for TLS certificates)
- nginx-ingress-controller (for ingress)

## Quick Start

The fastest way to get started:

```bash
# 1. Create namespace
kubectl create namespace vulcano-app

# 2. Install with defaults (includes MongoDB and RabbitMQ)
helm install vulcano ./helm-chart-new -n vulcano-app

# 3. Wait for pods to start
kubectl get pods -n vulcano-app -w

# 4. Access the service
kubectl port-forward svc/vulcano 8889:8889 -n vulcano-app
# Navigate to http://localhost:8889
```

## Installation Methods

### Method 1: Default Installation

```bash
helm install vulcano ./helm-chart-new -n vulcano-app
```

This deploys:
- Vulcano application
- MongoDB (standalone)
- RabbitMQ (single node)
- All required RBAC and network policies

### Method 2: Production Installation

```bash
# Create namespace
kubectl create namespace vulcano-prod

# Install with production values
helm install vulcano ./helm-chart-new \
  -n vulcano-prod \
  -f examples/production-values.yaml
```

Update the following in `production-values.yaml` before installation:

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

### Method 3: Development Installation

```bash
kubectl create namespace vulcano-dev

helm install vulcano ./helm-chart-new \
  -n vulcano-dev \
  -f examples/dev-values.yaml
```

### Method 4: External MongoDB and RabbitMQ

If you have existing MongoDB and RabbitMQ services:

```bash
helm install vulcano ./helm-chart-new \
  -n vulcano-app \
  --set mongodb.enabled=false \
  --set rabbitmq.enabled=false \
  --set mongodb.externalHost="mongodb.your-domain.com" \
  --set rabbitmq.externalHost="rabbitmq.your-domain.com"
```

## Configuration

### Common Configuration Options

#### 1. Change Image Versions

```bash
helm install vulcano ./helm-chart-new -n vulcano-app \
  --set images.vulcano.tag="1.6.0"
```

#### 2. Configure Ingress with Let's Encrypt

```bash
helm install vulcano ./helm-chart-new -n vulcano-app \
  --set vulcano.ingress.host="vulcano.example.com" \
  --set vulcano.ingress.tls.enabled=true \
  --set vulcano.ingress.tls.source="letsencrypt" \
  --set vulcano.ingress.tls.letsencrypt.enabled=true \
  --set vulcano.ingress.tls.letsencrypt.clusterIssuer="letsencrypt-prod" \
  --set vulcano.ingress.tls.letsencrypt.email="admin@example.com"
```

#### 2b. Configure Ingress with Existing Certificate

```bash
helm install vulcano ./helm-chart-new -n vulcano-app \
  --set vulcano.ingress.host="vulcano.example.com" \
  --set vulcano.ingress.tls.enabled=true \
  --set vulcano.ingress.tls.source="existing" \
  --set vulcano.ingress.tls.existing.secretName="tls-vulcano-cert"
```

#### 3. Enable SMB CSI Driver

First, install the CSI driver:

```bash
helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
helm install csi-driver-smb csi-driver-smb/csi-driver-smb \
  --namespace kube-system
```

Then enable in Vulcano chart:

```bash
helm install vulcano ./helm-chart-new -n vulcano-app \
  --set smbCsi.enabled=true \
  --set smbCsi.uri="//storage.example.com/vulcano" \
  --set smbCsi.username="storageuser" \
  --set smbCsi.password="storagepass"
```

#### 4. Scale to Multiple Replicas

```bash
helm install vulcano ./helm-chart-new -n vulcano-app \
  --set vulcano.replicaCount=3 \
  --set mongodb.replicaCount=3 \
  --set rabbitmq.replicaCount=3
```

#### 5. Configure Resource Limits

```bash
helm install vulcano ./helm-chart-new -n vulcano-app \
  --set 'vulcano.resources.requests.cpu=1000m' \
  --set 'vulcano.resources.limits.cpu=2000m' \
  --set 'vulcano.resources.requests.memory=2Gi' \
  --set 'vulcano.resources.limits.memory=4Gi'
```

## Verification

### Check Deployment Status

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

### Verify MongoDB Connection

```bash
# Port-forward to MongoDB
kubectl port-forward svc/mongodb 27017:27017 -n vulcano-app &

# Test connection
mongosh -u root -p bitte localhost:27017

# Inside MongoDB shell
> show dbs
> use vulcano
> db.collections
```

### Verify RabbitMQ Connection

```bash
# Access RabbitMQ Management UI
kubectl port-forward svc/rabbitmq 15672:15672 -n vulcano-app &

# Open browser to http://localhost:15672
# Default credentials: vulcano / vulcano0479
```

### Verify Vulcano Application

```bash
# Port-forward to Vulcano
kubectl port-forward svc/vulcano 8889:8889 -n vulcano-app &

# Test the application
curl http://localhost:8889/actuator/health
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n vulcano-app

# Get detailed pod information
kubectl describe pod -n vulcano-app <pod-name>

# Check pod events
kubectl get events -n vulcano-app --sort-by='.lastTimestamp'
```

### Memory/CPU Issues

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n vulcano-app

# Increase resources in chart
helm upgrade vulcano ./helm-chart-new -n vulcano-app \
  --set 'vulcano.resources.limits.memory=8Gi'
```

### MongoDB Connection Issues

```bash
# Check MongoDB pod logs
kubectl logs -n vulcano-app mongodb-0

# Verify credentials
kubectl get secret mongodb-credentials -n vulcano-app -o yaml

# Test connection with mongodb client pod
kubectl run -it --rm mongodb-test --image=mongo:latest --restart=Never -- \
  mongosh -u root -p $(kubectl get secret mongodb-credentials -n vulcano-app -o jsonpath='{.data.password}' | base64 -d) mongodb:27017
```

### RabbitMQ Connection Issues

```bash
# Check RabbitMQ pod logs
kubectl logs -n vulcano-app rabbitmq-0

# Verify credentials
kubectl get secret rabbitmq-credentials -n vulcano-app -o yaml

# Check RabbitMQ status
kubectl exec -it rabbitmq-0 -n vulcano-app -- rabbitmqctl status
```

### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n vulcano-app
kubectl describe ingress vulcano -n vulcano-app

# Verify ingress controller
kubectl get ingressclass
kubectl get pods -n ingress-nginx

# Check DNS resolution
nslookup vulcano.example.com
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n vulcano-app
kubectl describe pvc -n vulcano-app smb-vulcano-data

# Check available storage classes
kubectl get storageclass

# Check PV status
kubectl get pv
```

## Upgrading

```bash
# Check current values
helm get values vulcano -n vulcano-app

# Upgrade with new values
helm upgrade vulcano ./helm-chart-new -n vulcano-app \
  -f updated-values.yaml

# Verify upgrade
kubectl rollout status deployment/vulcano -n vulcano-app
```

## Uninstalling

```bash
# Delete the Helm release
helm uninstall vulcano -n vulcano-app

# Keep namespace and PVCs for later use
# To remove everything:
kubectl delete namespace vulcano-app
```

## Support

For issues, questions, or contributions, please:

1. Check the troubleshooting section above
2. Review Kubernetes events: `kubectl get events -n vulcano-app`
3. Check pod logs: `kubectl logs deployment/vulcano -n vulcano-app`
4. Contact support with pod logs and cluster information

## Security Best Practices

1. **Change Default Passwords**
   - MongoDB root password
   - RabbitMQ credentials
   - SMB credentials

2. **Use TLS/SSL**
   - **Option 1: Let's Encrypt** - Enable automatic certificate generation via cert-manager
     ```bash
     --set vulcano.ingress.tls.enabled=true \
     --set vulcano.ingress.tls.source="letsencrypt" \
     --set vulcano.ingress.tls.letsencrypt.enabled=true \
     --set vulcano.ingress.tls.letsencrypt.clusterIssuer="letsencrypt-prod"
     ```
   - **Option 2: Existing Certificate** - Use pre-generated TLS certificate
     ```bash
     # First create the TLS secret
     kubectl create secret tls tls-vulcano-cert \
       --cert=path/to/tls.crt \
       --key=path/to/tls.key \
       -n vulcano-app
     
     # Then enable in Helm
     --set vulcano.ingress.tls.enabled=true \
     --set vulcano.ingress.tls.source="existing" \
     --set vulcano.ingress.tls.existing.secretName="tls-vulcano-cert"
     ```

3. **Implement Network Policies**
   - Restrict inter-pod communication
   - Limit ingress/egress traffic

4. **Use Secrets Manager**
   - Integrate with Vault, Sealed Secrets, etc.
   - Avoid storing secrets in Git

5. **Regular Backups**
   - Backup MongoDB data
   - Backup RabbitMQ configuration

6. **Monitor and Audit**
   - Enable logging
   - Monitor resource usage
   - Audit cluster access
