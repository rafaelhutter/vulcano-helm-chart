#!/bin/bash

set -e

export KUBECONFIG="${KUBECONFIG:-/Users/r.hutter/.kube/rancher.surfplanet.yaml}"

NAMESPACE="vulcano-zdf"
RELEASE_NAME="vulcano-zdf"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="$SCRIPT_DIR"
VALUES_DIR="$CHART_DIR/deployments/vulcano-zdf"
VALUES_FILE="$VALUES_DIR/values.yaml"
VALUES_SECRET_FILE="$VALUES_DIR/values.secret.yaml"

BACKUP_DIR="/Users/r.hutter/Downloads/20260317-105900/vulcano-zdf"
MONGO_DB="zdf"
MONGO_POD="mongodb-0"
MONGO_NS="vulcano-common"

# -------------------------------------------------------
# 1. Namespace erstellen
# -------------------------------------------------------
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  echo "Namespace $NAMESPACE does not exist. Creating..."
  kubectl create namespace "$NAMESPACE"
else
  echo "Namespace $NAMESPACE already exists."
fi

# -------------------------------------------------------
# 2. MongoDB Backup einspielen (optional)
# -------------------------------------------------------
echo ""
echo "=== MongoDB Backup Restore ==="
echo "Soll das Backup aus '$BACKUP_DIR' in die Datenbank '$MONGO_DB' eingespielt werden?"
echo "ACHTUNG: Bestehende Daten werden überschrieben (--drop)!"
echo ""
read -r -p "Backup einspielen? [y/N] " CONFIRM_RESTORE

if [[ "$CONFIRM_RESTORE" =~ ^[yY]$ ]]; then
  if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup-Verzeichnis nicht gefunden: $BACKUP_DIR"
    exit 1
  fi

  echo "Kopiere Backup auf MongoDB-Pod $MONGO_POD..."
  kubectl cp "$BACKUP_DIR" "$MONGO_NS/$MONGO_POD:/tmp/vulcano-zdf-backup"

  echo "Starte mongorestore in Datenbank '$MONGO_DB'..."
  MONGO_PASSWORD=$(kubectl get secret -n "$MONGO_NS" mongodb -o jsonpath='{.data.mongodb-root-password}' 2>/dev/null | base64 -d || \
                   grep -A2 'rootPassword' "$VALUES_SECRET_FILE" | grep 'rootPassword' | awk '{print $2}' | tr -d '"')

  kubectl exec -n "$MONGO_NS" "$MONGO_POD" -- \
    mongorestore \
      --host "localhost:27017" \
      --username "admin" \
      --password "$MONGO_PASSWORD" \
      --authenticationDatabase "admin" \
      --db "$MONGO_DB" \
      --gzip \
      --drop \
      /tmp/vulcano-zdf-backup

  echo "Backup erfolgreich in Datenbank '$MONGO_DB' eingespielt."

  # Aufräumen
  kubectl exec -n "$MONGO_NS" "$MONGO_POD" -- rm -rf /tmp/vulcano-zdf-backup
else
  echo "Backup-Restore übersprungen."
fi

# -------------------------------------------------------
# 3. Helm Install / Upgrade
# -------------------------------------------------------
echo ""
echo "=== Helm Deploy ==="

HELM_VALUES=(-f "$VALUES_FILE")
if [ -f "$VALUES_SECRET_FILE" ]; then
  echo "Found values.secret.yaml – including secrets."
  HELM_VALUES+=(-f "$VALUES_SECRET_FILE")
else
  echo "WARNING: values.secret.yaml not found. Passwords/secrets may be missing!"
fi

if helm ls -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
  echo "Upgrading existing release $RELEASE_NAME in namespace $NAMESPACE..."
  helm upgrade "$RELEASE_NAME" "$CHART_DIR" -n "$NAMESPACE" "${HELM_VALUES[@]}"
else
  echo "Installing new release $RELEASE_NAME in namespace $NAMESPACE..."
  helm install "$RELEASE_NAME" "$CHART_DIR" -n "$NAMESPACE" "${HELM_VALUES[@]}"
fi

# -------------------------------------------------------
# 4. Status prüfen
# -------------------------------------------------------
DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "vulcano")
echo "Waiting for deployment '$DEPLOYMENT_NAME' to be ready..."
kubectl rollout status deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout=120s

echo ""
echo "=== Pod Status ==="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "Deployment/Update von $RELEASE_NAME in Namespace $NAMESPACE erfolgreich abgeschlossen."
