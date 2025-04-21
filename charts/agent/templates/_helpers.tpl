{{/*
Expand the name of the chart.
*/}}
{{- define "juice-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "juice-agent.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "juice-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "juice-agent.labels" -}}
helm.sh/chart: {{ include "juice-agent.chart" . }}
{{ include "juice-agent.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | trunc 63 | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "juice-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "juice-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "juice-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- define "juice-agent.nodeSelector" -}}
{{- if .Values.nodeSelector }}
{{ toYaml .Values.nodeSelector }}
{{- else }}
{{ .Values.nodeSelectorPreset }}: "true"
{{- end }}
{{- end }}

{{- define "juice-agent.tolerations" -}}
{{- if not .Values.nodeSelector }}
- key: nvidia.com/gpu
  operator: Exists
  effect: NoSchedule
{{- end }}
{{- end }}