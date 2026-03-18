#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Set kubeconfig if not already set
export KUBECONFIG="${KUBECONFIG:-/Users/r.hutter/.kube/rancher.surfplanet.yaml}"

# Define namespace and release name
NAMESPACE="vulcano-test"
RELEASE_NAME="vulcano-test"

# Define Helm chart directory (relative to script location)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="$SCRIPT_DIR"
VALUES_DIR="$CHART_DIR/deployments/vulcano-test"
VALUES_FILE="$VALUES_DIR/values.yaml"
VALUES_SECRET_FILE="$VALUES_DIR/values.secret.yaml"

# Check if namespace exists, create if not
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  echo "Namespace $NAMESPACE does not exist. Creating..."
  kubectl create namespace "$NAMESPACE"
else
  echo "Namespace $NAMESPACE already exists."
fi

# Build helm value flags as array to handle paths with spaces
HELM_VALUES=(-f "$VALUES_FILE")
if [ -f "$VALUES_SECRET_FILE" ]; then
  echo "Found values.secret.yaml – including secrets."
  HELM_VALUES+=(-f "$VALUES_SECRET_FILE")
else
  echo "WARNING: values.secret.yaml not found. Passwords/secrets may be missing!"
fi

# Deploy or upgrade the Helm release
if helm ls -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
  echo "Upgrading existing release $RELEASE_NAME in namespace $NAMESPACE..."
  helm upgrade "$RELEASE_NAME" "$CHART_DIR" -n "$NAMESPACE" "${HELM_VALUES[@]}"
else
  echo "Installing new release $RELEASE_NAME in namespace $NAMESPACE..."
  helm install "$RELEASE_NAME" "$CHART_DIR" -n "$NAMESPACE" "${HELM_VALUES[@]}"
fi

# Wait for vulcano deployment to be ready (deployment name is 'vulcano', not the release name)
DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "$RELEASE_NAME")
echo "Waiting for deployment '$DEPLOYMENT_NAME' to be ready..."
kubectl rollout status deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout=120s

echo ""
echo "=== Pod Status ==="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "Deployment/Update of $RELEASE_NAME in namespace $NAMESPACE completed successfully."