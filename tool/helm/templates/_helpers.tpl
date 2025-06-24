{{
/*

Expand the name of the chart.
*/}}
{{- define "incerto-tool.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{
/*

Create a default fully qualified app name.
*/}}
{{- define "incerto-tool.fullname" -}}
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

{{
/*

Create chart name and version as used by the chart label.
*/}}
{{- define "incerto-tool.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{
/*

Common labels
*/}}
{{- define "incerto-tool.labels" -}}
helm.sh/chart: {{ include "incerto-tool.chart" . }}
{{ include "incerto-tool.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{
/*

Selector labels
*/}}
{{- define "incerto-tool.selectorLabels" -}}
app.kubernetes.io/name: {{ include "incerto-tool.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{
/*

Get image tag based on environment
*/}}
{{- define "incerto-tool.imageTag" -}}
{{- if eq .Values.global.environment "dev" -}}
dev
{{- else -}}
prod
{{- end -}}
{{- end }}