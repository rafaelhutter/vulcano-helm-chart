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
echo "▶ Helm Repository hinzufügen..."
helm repo add "${REPO_NAME}" "${REPO_URL}" 2>/dev/null || true
helm repo update

# --- 2. Namespace ---
echo "▶ Namespace '${NAMESPACE}' anlegen..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# --- 3. Install shared services ---
echo "▶ Shared Services (MongoDB + RabbitMQ) installieren..."
helm upgrade --install "${RELEASE}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 15m

echo ""
echo "✅ Shared Services bereit in Namespace '${NAMESPACE}'!"
echo ""
echo "Folgende Endpoints stehen den Vulcano-Instanzen zur Verfügung:"
echo ""
echo "  MongoDB (ReplicaSet):"
echo "    mongodb-headless.${NAMESPACE}.svc.cluster.local:27017"
echo ""
echo "  RabbitMQ:"
echo "    rabbitmq.${NAMESPACE}.svc.cluster.local:5672"
echo ""
echo "Nächster Schritt: Vulcano-Instanz(en) mit vulcano-only-values.yaml deployen:"
echo "  bash examples/install.sh --values examples/vulcano-only-values.yaml"
