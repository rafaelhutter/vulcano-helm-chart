{{/*
Expand the name of the chart.
*/}}
{{- define "vulcano.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "vulcano.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "vulcano.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "vulcano.labels" -}}
helm.sh/chart: {{ include "vulcano.chart" . }}
{{ include "vulcano.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "vulcano.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vulcano.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "vulcano.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "vulcano.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the namespace
*/}}
{{- define "vulcano.namespace" -}}
{{- .Values.global.namespace | default "default" }}
{{- end }}

{{/*
MongoDB connection string
*/}}
{{- define "vulcano.mongodb.host" -}}
{{- if .Values.mongodb.enabled }}
{{- if .Values.mongodb.replicaSet.enabled }}
{{- .Values.mongodb.fullnameOverride | default "mongodb" }}-headless.{{ include "vulcano.namespace" . }}.svc.cluster.local
{{- else }}
{{- .Values.mongodb.fullnameOverride | default "mongodb" }}.{{ include "vulcano.namespace" . }}.svc.cluster.local
{{- end }}
{{- else }}
{{- .Values.mongodb.externalHost | default "mongodb" }}
{{- end }}
{{- end }}

{{/*
RabbitMQ connection string
*/}}
{{- define "vulcano.rabbitmq.host" -}}
{{- if .Values.rabbitmq.enabled }}
{{- .Values.rabbitmq.fullnameOverride | default "rabbitmq" }}.{{ include "vulcano.namespace" . }}.svc.cluster.local
{{- else }}
{{- .Values.rabbitmq.externalHost | default "rabbitmq" }}
{{- end }}
{{- end }}

{{/*
Service admin password.
Single source of truth so the Vulcano configmap and the vulcano-credentials
secret (consumed by dflconnector/filetransfer) never diverge — otherwise
service auth fails with 403 and the connectors crash-loop.
*/}}
{{- define "vulcano.serviceAdminPassword" -}}
{{- .Values.auth.serviceAdminPassword | default "6qmY$JCaJ@6^#4V" -}}
{{- end }}

{{/*
MongoDB Spring Boot env vars.
Emits each property under both the legacy `spring.data.mongodb.*` keys and the
new `spring.mongodb.*` keys required since the Spring Boot upgrade, so the
chart works against apps using either binding.
*/}}
{{- define "vulcano.mongodb.env" -}}
{{- $prefixes := list "spring.data.mongodb" "spring.mongodb" -}}
{{- range $prefix := $prefixes }}
- name: {{ $prefix }}.host
  value: {{ include "vulcano.mongodb.host" $ | quote }}
- name: {{ $prefix }}.port
  value: "27017"
- name: {{ $prefix }}.database
  value: {{ $.Values.mongodb.database | default "vulcano" | quote }}
- name: {{ $prefix }}.authentication-database
  value: "admin"
{{- if $.Values.mongodb.replicaSet.enabled }}
- name: {{ $prefix }}.replica-set-name
  value: {{ $.Values.mongodb.replicaSet.name | quote }}
{{- end }}
{{- if or $.Values.mongodb.enabled $.Values.mongodb.externalHost }}
- name: {{ $prefix }}.username
  value: {{ $.Values.mongodb.auth.rootUsername | default "root" | quote }}
- name: {{ $prefix }}.password
  valueFrom:
    secretKeyRef:
      {{- if $.Values.mongodb.auth.existingSecret }}
      name: {{ $.Values.mongodb.auth.existingSecret }}
      key: {{ $.Values.mongodb.auth.existingSecretPasswordKey | default "mongodb-root-password" }}
      {{- else if $.Values.mongodb.enabled }}
      name: {{ $.Values.mongodb.fullnameOverride | default "mongodb" }}
      key: mongodb-root-password
      {{- else }}
      name: mongodb-credentials
      key: mongodb-root-password
      {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Deployment update strategy.

Auto-derives based on the data PVCs:
  - All volumes RWX  -> RollingUpdate (true zero-downtime upgrades)
  - Any volume RWO   -> Recreate      (avoids Multi-Attach errors)

A RollingUpdate against a ReadWriteOnce PVC fails when the new pod is
scheduled on a different node than the old one — the volume can't be
attached to two nodes simultaneously, the rollout gets stuck, and the
new pod hangs in ContainerCreating until something manually intervenes.
Recreate sidesteps the entire class of problem by terminating the old
pod first.

The user can force a value with `.Values.vulcano.strategy`.
*/}}
{{- define "vulcano.deploymentStrategy" -}}
{{- if .Values.vulcano.strategy -}}
{{ .Values.vulcano.strategy }}
{{- else -}}
{{- $allRWX := eq (.Values.vulcano.storage.accessModes | default "ReadWriteOnce") "ReadWriteMany" -}}
{{- range .Values.vulcano.storage.extraMounts -}}
  {{- if and (not .existingClaim) (ne (.accessModes | default "ReadWriteOnce") "ReadWriteMany") -}}
    {{- $allRWX = false -}}
  {{- end -}}
{{- end -}}
{{- if $allRWX -}}RollingUpdate{{- else -}}Recreate{{- end -}}
{{- end -}}
{{- end }}

{{/*
Docker config JSON for image pull secrets
*/}}
{{- define "vulcano.dockerconfigjson" -}}
{
  "auths": {
    "{{ .Values.imagePullSecrets.dockerServer }}": {
      "username": "{{ .Values.imagePullSecrets.dockerUsername }}",
      "password": "{{ .Values.imagePullSecrets.dockerPassword }}",
      "email": "{{ .Values.imagePullSecrets.dockerEmail }}",
      "auth": "{{ printf "%s:%s" .Values.imagePullSecrets.dockerUsername .Values.imagePullSecrets.dockerPassword | b64enc }}"
    }
  }
}
{{- end }}
