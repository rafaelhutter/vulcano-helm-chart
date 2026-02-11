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
{{ .Values.mongodb.externalHost | default "mongodb" }}
{{- end }}
{{- end }}

{{/*
RabbitMQ connection string
*/}}
{{- define "vulcano.rabbitmq.host" -}}
{{- if .Values.rabbitmq.enabled }}
{{- .Values.rabbitmq.fullnameOverride | default "rabbitmq" }}.{{ include "vulcano.namespace" . }}.svc.cluster.local
{{- else }}
{{ .Values.rabbitmq.externalHost | default "rabbitmq" }}
{{- end }}
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
