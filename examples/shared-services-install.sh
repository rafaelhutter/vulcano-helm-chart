#!/usr/bin/env bash
# ============================================================
#  Vulcano – Shared Services Installation
#  Deploys MongoDB + RabbitMQ to namespace "vulcano-common"
#
#  Prerequisites: helm >= 3.0, kubectl (configured)
# ============================================================
set -euo pipefail

NAMESPACE="vulcano-common"
RELEASE="vulcano-shared"
REPO_NAME="rafaelhutter"
REPO_URL="https://rafaelhutter.github.io/vulcano-helm-chart"
CHART="${REPO_NAME}/vulcano"
VALUES_FILE="$(dirname "$0")/shared-services-values.yaml"

echo "╔══════════════════════════════════════════════════╗"
echo "║    Vulcano Shared Services Installation          ║"
echo "║    (MongoDB + RabbitMQ → vulcano-common)         ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# --- 1. Helm repository ---
echo "▶ Adding Helm repository..."
helm repo add "${REPO_NAME}" "${REPO_URL}" 2>/dev/null || true
helm repo update

# --- 2. Namespace ---
echo "▶ Creating namespace '${NAMESPACE}'..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# --- 3. Install shared services ---
echo "▶ Installing shared services (MongoDB + RabbitMQ)..."
helm upgrade --install "${RELEASE}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 15m

echo ""
echo "✅ Shared services ready in namespace '${NAMESPACE}'!"
echo ""
echo "The following endpoints are available to Vulcano instances:"
echo ""
echo "  MongoDB (ReplicaSet):"
echo "    mongodb-headless.${NAMESPACE}.svc.cluster.local:27017"
echo ""
echo "  RabbitMQ:"
echo "    rabbitmq.${NAMESPACE}.svc.cluster.local:5672"
echo ""
echo "Next step: deploy the Vulcano instance(s) using vulcano-only-values.yaml:"
echo "  bash examples/install.sh --values examples/vulcano-only-values.yaml"
