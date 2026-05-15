#!/usr/bin/env bash
# ============================================================
#  Vulcano – Installation script
#  Prerequisites: helm >= 3.0, kubectl (configured)
# ============================================================
set -euo pipefail

NAMESPACE="vulcano-app"
RELEASE="vulcano"
REPO_NAME="rafaelhutter"
REPO_URL="https://rafaelhutter.github.io/vulcano-helm-chart"
CHART="${REPO_NAME}/vulcano"
VALUES_FILE="$(dirname "$0")/values.yaml"

echo "╔══════════════════════════════════════════╗"
echo "║       Vulcano Helm Installation          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# --- 1. Add Helm repository ---
echo "▶ Adding Helm repository..."
helm repo add "${REPO_NAME}" "${REPO_URL}" 2>/dev/null || true
helm repo update

# --- 2. Create namespace ---
echo "▶ Creating namespace '${NAMESPACE}'..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# --- 3. Helm install / upgrade ---
echo "▶ Installing / upgrading Vulcano..."
helm upgrade --install "${RELEASE}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 10m

echo ""
echo "✅ Installation complete!"
echo ""
echo "Check status:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "Tail logs:"
echo "  kubectl logs deployment/vulcano -n ${NAMESPACE} -f"
echo ""
echo "Upgrade (when a new chart version is published):"
echo "  helm repo update && bash $0"
