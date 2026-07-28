{{- define "fluxer.fullname" -}}
{{- .Release.Name | trunc 40 | trimSuffix "-" -}}
{{- end -}}

{{- define "fluxer.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "fluxer.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "fluxer.garageName" -}}
{{- printf "%s-garage" (include "fluxer.fullname" .) -}}
{{- end -}}

{{- define "fluxer.garageS3SecretName" -}}
{{- printf "%s-s3" (include "fluxer.garageName" .) -}}
{{- end -}}

{{- define "fluxer.pgClusterName" -}}
{{- default (printf "%s-pg" (include "fluxer.fullname" .)) .Values.postgres.clusterName -}}
{{- end -}}

{{- define "fluxer.valkeyName" -}}
{{- default (printf "%s-valkey" (include "fluxer.fullname" .)) .Values.valkey.name -}}
{{- end -}}

{{- define "fluxer.valkeyHost" -}}
{{- printf "valkey-%s" (include "fluxer.valkeyName" .) -}}
{{- end -}}

{{- define "fluxer.pgHost" -}}
{{- if .Values.postgres.enabled -}}
{{- printf "%s-rw" (include "fluxer.pgClusterName" .) -}}
{{- else -}}
{{- required "postgres.external.host is required when postgres.enabled=false" .Values.postgres.external.host -}}
{{- end -}}
{{- end -}}

{{- define "fluxer.pgSecretName" -}}
{{- if .Values.postgres.enabled -}}
{{- printf "%s-app" (include "fluxer.pgClusterName" .) -}}
{{- else -}}
{{- required "postgres.external.passwordSecret is required when postgres.enabled=false" .Values.postgres.external.passwordSecret -}}
{{- end -}}
{{- end -}}

{{- define "fluxer.pgSecretKey" -}}
{{- if .Values.postgres.enabled -}}password{{- else -}}{{ .Values.postgres.external.passwordSecretKey }}{{- end -}}
{{- end -}}

{{- define "fluxer.publicOrigin" -}}
{{- $port := int .Values.global.publicPort -}}
{{- if or (and (eq .Values.global.publicScheme "https") (eq $port 443)) (and (eq .Values.global.publicScheme "http") (eq $port 80)) -}}
{{- printf "%s://%s" .Values.global.publicScheme .Values.global.domain -}}
{{- else -}}
{{- printf "%s://%s:%d" .Values.global.publicScheme .Values.global.domain $port -}}
{{- end -}}
{{- end -}}

{{- define "fluxer.labels" -}}
app.kubernetes.io/part-of: fluxer
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "fluxer.selectorLabels" -}}
app.kubernetes.io/name: fluxer
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "fluxer.commonEnv" -}}
{{- $fullname := include "fluxer.fullname" . -}}
{{- $secret := include "fluxer.secretName" . -}}
{{- $origin := include "fluxer.publicOrigin" . -}}
- name: FLUXER_ENV
  value: production
- name: NODE_ENV
  value: production
- name: FLUXER_SELF_HOSTED
  value: "true"
- name: FLUXER_BASE_DOMAIN
  value: {{ .Values.global.domain | quote }}
- name: FLUXER_PUBLIC_SCHEME
  value: {{ .Values.global.publicScheme | quote }}
- name: FLUXER_PUBLIC_PORT
  value: {{ .Values.global.publicPort | quote }}
- name: FLUXER_TRUST_CLIENT_IP_HEADER
  value: "true"
- name: FLUXER_CLIENT_IP_HEADER_NAME
  value: x-forwarded-for

- name: FLUXER_DATABASE_BACKEND
  value: postgres
- name: FLUXER_POSTGRES_HOST
  value: {{ include "fluxer.pgHost" . | quote }}
- name: FLUXER_POSTGRES_PORT
  value: {{ if .Values.postgres.enabled }}"5432"{{ else }}{{ .Values.postgres.external.port | quote }}{{ end }}
- name: FLUXER_POSTGRES_DATABASE
  value: {{ if .Values.postgres.enabled }}{{ .Values.postgres.database | quote }}{{ else }}{{ .Values.postgres.external.database | quote }}{{ end }}
- name: FLUXER_POSTGRES_USERNAME
  value: {{ if .Values.postgres.enabled }}{{ .Values.postgres.owner | quote }}{{ else }}{{ .Values.postgres.external.username | quote }}{{ end }}
- name: FLUXER_POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "fluxer.pgSecretName" . }}
      key: {{ include "fluxer.pgSecretKey" . }}
- name: FLUXER_POSTGRES_SSL
  value: {{ if .Values.postgres.enabled }}"false"{{ else }}{{ .Values.postgres.external.ssl | quote }}{{ end }}

{{- if .Values.valkey.external.url }}
- name: FLUXER_KV_URL
  value: {{ .Values.valkey.external.url | quote }}
{{- else }}
- name: VALKEY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "fluxer.secretName" . }}
      key: VALKEY_PASSWORD
- name: FLUXER_KV_URL
  value: "redis://{{ .Values.valkey.username }}:$(VALKEY_PASSWORD)@{{ include "fluxer.valkeyHost" . }}:6379/0"
{{- end }}

- name: FLUXER_NATS_URL
  value: "nats://{{ $fullname }}-nats:4222"
- name: FLUXER_NATS_JETSTREAM_URL
  value: "nats://{{ $fullname }}-nats:4222"
- name: FLUXER_SVC_NATS_URL
  value: "nats://{{ $fullname }}-nats:4222"
- name: FLUXER_SVC_SHARD_COUNT
  value: {{ .Values.svcShardCount | quote }}

- name: FLUXER_SEARCH_ENGINE
  value: meilisearch
- name: FLUXER_SEARCH_URL
  value: "http://{{ $fullname }}-meilisearch:7700"
- name: FLUXER_SEARCH_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: MEILI_MASTER_KEY

- name: FLUXER_S3_ENDPOINT
  value: "http://{{ include "fluxer.garageName" . }}:3900"
- name: FLUXER_S3_PUBLIC_ENDPOINT
  value: "http://{{ include "fluxer.garageName" . }}:3900"
- name: FLUXER_S3_REGION
  value: {{ .Values.garage.region | quote }}
- name: FLUXER_S3_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "fluxer.garageS3SecretName" . }}
      key: FLUXER_S3_ACCESS_KEY
- name: FLUXER_S3_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "fluxer.garageS3SecretName" . }}
      key: FLUXER_S3_SECRET_KEY
- name: FLUXER_S3_FORCE_PATH_STYLE
  value: "true"
- name: FLUXER_S3_BUCKET_CDN
  value: fluxer
- name: FLUXER_S3_BUCKET_UPLOADS
  value: fluxer-uploads
- name: FLUXER_S3_BUCKET_DOWNLOADS
  value: fluxer-downloads
- name: FLUXER_S3_BUCKET_REPORTS
  value: fluxer-reports
- name: FLUXER_S3_BUCKET_HARVESTS
  value: fluxer-harvests
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "fluxer.garageS3SecretName" . }}
      key: FLUXER_S3_ACCESS_KEY
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "fluxer.garageS3SecretName" . }}
      key: FLUXER_S3_SECRET_KEY
- name: AWS_DEFAULT_REGION
  value: {{ .Values.garage.region | quote }}
- name: AWS_EC2_METADATA_DISABLED
  value: "true"

- name: FLUXER_LIVEKIT_ENABLED
  value: {{ .Values.livekit.enabled | quote }}
- name: FLUXER_LIVEKIT_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: LIVEKIT_API_KEY
- name: FLUXER_LIVEKIT_API_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: LIVEKIT_API_SECRET
- name: FLUXER_LIVEKIT_WEBHOOK_URL
  value: "http://{{ $fullname }}-api:8080/webhooks/livekit"
- name: FLUXER_LIVEKIT_DEFAULT_REGION
  value: {{ `{"id":"default","name":"Default","emoji":"🌍","latitude":0,"longitude":0}` | quote }}

- name: FLUXER_KLIPY_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: FLUXER_KLIPY_API_KEY
      optional: true
- name: FLUXER_EMAIL_ENABLED
  value: {{ .Values.email.enabled | quote }}
- name: FLUXER_EMAIL_PROVIDER
  value: {{ .Values.email.provider | quote }}
- name: FLUXER_EMAIL_FROM_EMAIL
  value: {{ .Values.email.fromEmail | quote }}
- name: FLUXER_EMAIL_FROM_NAME
  value: {{ .Values.email.fromName | quote }}
- name: FLUXER_EMAIL_SMTP_HOST
  value: {{ .Values.email.smtp.host | quote }}
- name: FLUXER_EMAIL_SMTP_PORT
  value: {{ .Values.email.smtp.port | quote }}
- name: FLUXER_EMAIL_SMTP_USERNAME
  value: {{ .Values.email.smtp.username | quote }}
- name: FLUXER_EMAIL_SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: FLUXER_EMAIL_SMTP_PASSWORD
      optional: true
- name: FLUXER_EMAIL_SMTP_SECURE
  value: {{ .Values.email.smtp.secure | quote }}
- name: FLUXER_SMS_ENABLED
  value: "false"
- name: FLUXER_CAPTCHA_ENABLED
  value: {{ .Values.captcha.enabled | quote }}
- name: FLUXER_CAPTCHA_PROVIDER
  value: {{ .Values.captcha.provider | quote }}
- name: FLUXER_STRIPE_ENABLED
  value: "false"
- name: FLUXER_NCMEC_ENABLED
  value: "false"
- name: FLUXER_CLAMAV_ENABLED
  value: "false"
- name: FLUXER_DISCOVERY_ENABLED
  value: {{ .Values.discovery.enabled | quote }}

{{- range $env := list
  "FLUXER_SUDO_MODE_SECRET"
  "FLUXER_CONNECTION_INITIATION_SECRET"
  "FLUXER_VAPID_PUBLIC_KEY"
  "FLUXER_VAPID_PRIVATE_KEY"
  "FLUXER_GATEWAY_RPC_AUTH_TOKEN"
  "FLUXER_MEDIA_PROXY_SECRET_KEY"
  "FLUXER_MEDIA_PROXY_UPLOAD_RELAY_SECRET_BASE64"
  "FLUXER_ADMIN_SECRET_KEY_BASE"
  "FLUXER_ADMIN_OAUTH_CLIENT_SECRET" }}
- name: {{ $env }}
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: {{ $env }}
{{- end }}
- name: FLUXER_VAPID_EMAIL
  value: {{ .Values.secrets.vapid.email | quote }}

- name: FLUXER_INTERNAL_API_ENDPOINT
  value: "http://{{ $fullname }}-api:8080"
- name: FLUXER_INTERNAL_GATEWAY_ENDPOINT
  value: "http://{{ $fullname }}-gateway:8080"
- name: FLUXER_INTERNAL_MEDIA_PROXY_ENDPOINT
  value: "http://{{ $fullname }}-media-proxy:8080"
- name: FLUXER_MARKETING_ENDPOINT
  value: {{ $origin | quote }}
- name: FLUXER_MEDIA_PROXY_ENDPOINT
  value: "http://{{ $fullname }}-media-proxy:8080"
- name: FLUXER_MEDIA_ENDPOINT
  value: {{ printf "%s/media" $origin | quote }}
- name: FLUXER_MEDIA_PROXY_UPLOAD_RELAY_ENDPOINT
  value: {{ printf "%s/media" $origin | quote }}
{{- end -}}

{{- define "fluxer.deployment" -}}
{{- $root := .root -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "fluxer.fullname" $root }}-{{ .name }}
  labels:
    {{- include "fluxer.labels" $root | nindent 4 }}
    app.kubernetes.io/component: {{ .name }}
spec:
  replicas: {{ .replicas }}
  selector:
    matchLabels:
      {{- include "fluxer.selectorLabels" (dict "root" $root "component" .name) | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "fluxer.selectorLabels" (dict "root" $root "component" .name) | nindent 8 }}
      annotations:
        checksum/secrets: {{ pick $root.Values "secrets" "email" | toYaml | sha256sum | trunc 32 }}
        {{- with .svc.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with $root.Values.image.pullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml $root.Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .name }}
          image: "{{ $root.Values.image.registry }}/{{ .image }}:{{ $root.Values.image.tag }}"
          imagePullPolicy: {{ $root.Values.image.pullPolicy }}
          {{- with .workingDir }}
          workingDir: {{ . }}
          {{- end }}
          {{- with .command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          env:
            {{- if .commonEnv }}
            {{- include "fluxer.commonEnv" $root | nindent 12 }}
            {{- end }}
            {{- with .env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- with .svc.extraEnv }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- if .port }}
          ports:
            - name: http
              containerPort: {{ .port }}
              protocol: TCP
          {{- end }}
          {{- if .probePath }}
          readinessProbe:
            httpGet:
              path: {{ .probePath }}
              port: {{ .port }}
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 30
          livenessProbe:
            httpGet:
              path: {{ .probePath }}
              port: {{ .port }}
            initialDelaySeconds: 90
            periodSeconds: 15
            failureThreshold: 6
          {{- end }}
          {{- with .svc.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .svc.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .svc.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .svc.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}

{{- define "fluxer.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "fluxer.fullname" .root }}-{{ .name }}
  labels:
    {{- include "fluxer.labels" .root | nindent 4 }}
    app.kubernetes.io/component: {{ .name }}
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      protocol: TCP
  selector:
    {{- include "fluxer.selectorLabels" (dict "root" .root "component" .name) | nindent 4 }}
{{- end -}}

