{{- define "thanos.image" -}}{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}{{- end -}}
{{- define "thanos.secctx" -}}
allowPrivilegeEscalation: false
capabilities: { drop: [ALL] }
runAsNonRoot: true
seccompProfile: { type: RuntimeDefault }
{{- end -}}
