#!/usr/bin/env bash
# ============================================================
#  Vulcano – Installationsscript
#  Voraussetzungen: helm >= 3.0, kubectl (konfiguriert)
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

# --- 1. Helm-Repository hinzufügen ---
echo "▶ Helm Repository hinzufügen..."
helm repo add "${REPO_NAME}" "${REPO_URL}" 2>/dev/null || true
helm repo update

# --- 2. Namespace anlegen ---
echo "▶ Namespace '${NAMESPACE}' anlegen..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# --- 3. Helm install / upgrade ---
echo "▶ Vulcano installieren / upgraden..."
helm upgrade --install "${RELEASE}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 10m

echo ""
echo "✅ Installation abgeschlossen!"
echo ""
echo "Status prüfen:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "Logs anzeigen:"
echo "  kubectl logs deployment/vulcano -n ${NAMESPACE} -f"
echo ""
echo "Upgrade (bei neuer Chart-Version):"
echo "  helm repo update && bash $0"
