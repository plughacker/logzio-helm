{{- define "opentelemetry-collector.pod" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "opentelemetry-collector.serviceAccountName" . }}
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
containers:
  - name: {{ .Chart.Name }}
    command:
      - /{{ .Values.command.name }}
      - --config=/conf/relay.yaml
      {{- range .Values.command.extraArgs }}
      - {{ . }}
      {{- end }}
    securityContext:
      {{- toYaml .Values.securityContext | nindent 6 }}
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
    imagePullPolicy: {{ .Values.image.pullPolicy }}
{{- if .Values.traces.enabled }}
    ports:
      {{- range $key, $port := .Values.ports }}
      {{- if $port.enabled }}
      - name: {{ $key }}
        containerPort: {{ $port.containerPort }}
        protocol: {{ $port.protocol }}
        {{- if and $.isAgent $port.hostPort }}
        hostPort: {{ $port.hostPort }}
        {{- end }}
      {{- end }}
      {{- end }}
{{- end }}
    env:
      - name: MY_POD_IP
        valueFrom:
          fieldRef:
            apiVersion: v1
            fieldPath: status.podIP
      - name: K8S_360_METRICS
        value: kube_pod_container_status_terminated_reason|kube_node_labels|kube_pod_container_status_waiting_reason|node_memory_Buffers_bytes|node_memory_Cached_bytes|kube_deployment_labels|container_cpu_usage_seconds_total|container_memory_working_set_bytes|container_network_receive_bytes_total|container_network_transmit_bytes_total|i:|kube_deployment_status_replicas|kube_deployment_status_replicas_available|kube_deployment_status_replicas_unavailable|kube_deployment_status_replicas_updated|kube_node_info|kube_node_spec_unschedulable|kube_node_status_allocatable|kube_node_status_capacity|kube_node_status_condition|kube_pod_container_info|kube_pod_container_resource_requests|kube_pod_container_resource_requests_cpu_cores|kube_pod_container_resource_requests_memory_bytes|kube_pod_container_status_ready|kube_pod_container_status_restarts_total|kube_pod_container_status_running|kube_pod_container_status_terminated|kube_pod_container_status_waiting|kube_pod_info|kube_pod_status_phase|machine_cpu_cores|namespace|node_boot_time_seconds|node_cpu_seconds_total|node_disk_io_time_seconds_total|node_filesystem_avail_bytes|node_filesystem_free_bytes|node_filesystem_size_bytes|node_memory_MemFree_bytes|node_memory_MemTotal_bytes|node_network_receive_bytes_total|node_network_transmit_bytes_total|node_time_seconds|p8s_logzio_name|windows_container_cpu_usage_seconds_total|windows_container_memory_usage_commit_bytes|windows_container_network_receive_bytes_total|windows_container_network_transmit_bytes_total|windows_cpu_time_total|windows_cs_hostname|windows_cs_physical_memory_bytes|windows_logical_disk_free_bytes|windows_logical_disk_read_seconds_total|windows_logical_disk_size_bytes|windows_logical_disk_write_seconds_total|windows_net_bytes_received_total|windows_net_bytes_sent_total|windows_os_physical_memory_free_bytes|windows_system_system_up_time|kube_pod_status_ready|kube_pod_container_resource_limits|container_memory_usage_bytes|container_network_transmit_packets_total|container_network_receive_packets_total|container_network_transmit_packets_dropped_total|container_network_receive_packets_dropped_total|kube_pod_created|kube_pod_owner|kube_pod_status_reason|node_memory_MemAvailable_bytes|kube_node_role|kube_node_created|node_load1|node_load5|node_load15|node_disk_reads_completed_total|node_disk_writes_completed_total|node_disk_read_bytes_total|node_disk_written_bytes_total|node_disk_read_time_seconds_total|node_disk_write_time_seconds_total|node_network_transmit_packets_total|node_network_receive_packets_total|node_network_transmit_drop_total|node_network_receive_drop_total|kube_replicaset_owner|kube_deployment_created|kube_deployment_status_condition|kube_deployment_spec_replicas|kube_namespace_status_phase 
      - name: LOGZIO_AGENT_VERSION
        value: {{.Chart.Version}}
      - name: REALESE_NAME
        value: {{.Release.Name}}
      - name: REALESE_NS
        value: {{.Release.Namespace}}
{{- if .Values.metrics.enabled }}
      - name: METRICS_TOKEN
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: logzio-metrics-shipping-token
{{- end }}
{{- if or (eq .Values.metrics.enabled true) (eq .Values.spm.enabled true) }}
      - name: LISTENER_URL
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: logzio-metrics-listener
      - name: P8S_LOGZIO_NAME
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: p8s-logzio-name
{{- end }}
{{- if .Values.traces.enabled }}
      - name: TRACES_TOKEN
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: logzio-traces-shipping-token
      - name: LOGZIO_LISTENER_REGION
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: logzio-listener-region
      - name: SAMPLING_PROBABILITY
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: sampling-probability
      - name: SAMPLING_LATENCY
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: sampling-latency
{{ if .Values.spm.enabled }}
      - name: SPM_TOKEN
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: logzio-spm-shipping-token
{{ end }}
{{- end }}
      - name: ENV_ID
        valueFrom:
          secretKeyRef:
            name: logzio-secret
            key: env_id
      {{- with .Values.extraEnvs }}
      {{- . | toYaml | nindent 6 }}
      {{- end }}
    livenessProbe:
      httpGet:
        path: /
        port: 13133
    readinessProbe:
      httpGet:
        path: /
        port: 13133
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
    volumeMounts:
      - mountPath: /conf
        name: {{ .Chart.Name }}-configmap
      {{- range .Values.extraConfigMapMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
        {{- if .subPath }}
        subPath: {{ .subPath }}
        {{- end }}
      {{- end }}
      {{- range .Values.extraHostPathMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
        {{- if .mountPropagation }}
        mountPropagation: {{ .mountPropagation }}
        {{- end }}
      {{- end }}
      {{- range .Values.secretMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
        {{- if .subPath }}
        subPath: {{ .subPath }}
        {{- end }}
      {{- end }}
{{- if .Values.priorityClassName }}
priorityClassName: {{ .Values.priorityClassName | quote }}
{{- end }}
volumes:
  - name: {{ .Chart.Name }}-configmap
    configMap:
      name: {{ include "opentelemetry-collector.fullname" . }}{{ .configmapSuffix }}
      items:
        - key: relay
          path: relay.yaml
  {{- range .Values.extraConfigMapMounts }}
  - name: {{ .name }}
    configMap:
      name: {{ .configMap }}
  {{- end }}
  {{- range .Values.extraHostPathMounts }}
  - name: {{ .name }}
    hostPath:
      path: {{ .hostPath }}
  {{- end }}
  {{- range .Values.secretMounts }}
  - name: {{ .name }}
    secret:
      secretName: {{ .secretName }}
  {{- end }}
{{- with .Values.linuxNodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}