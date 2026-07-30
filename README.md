# fluxer-helm
opiniated helm chart for deploying fluxer chat.

This is a community project and not affiliated with Fluxer Platform AB.

## Dependencies

### Operators
This chart requires the following operators to be installed in the cluster:
  - https://github.com/valkey-io/valkey-helm
  - https://github.com/rajsinghtech/garage-operator
  - https://github.com/cloudnative-pg/cloudnative-pg

### Secret
This Chart requires a secret to be present in the namespace.  
I used this command to generate the secret:
```bash
#!/usr/bin/env bash
set -euo pipefail

PEM=${PEM:-vapid_private.pem}
[ -f "$PEM" ] || openssl ecparam -name prime256v1 -genkey -noout -out "$PEM"

b64url() { base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='; }
rnd()    { openssl rand -base64 "${1:-36}"; }

args=(
  --from-literal=FLUXER_VAPID_PUBLIC_KEY="$(openssl ec -in "$PEM" -pubout -outform DER 2>/dev/null | tail -c 65 | b64url)"
  --from-literal=FLUXER_VAPID_PRIVATE_KEY="$(openssl ec -in "$PEM" -outform DER 2>/dev/null | tail -c +8 | head -c 32 | b64url)"
  --from-literal=MEILI_MASTER_KEY="$(rnd)"
  --from-literal=FLUXER_S3_ACCESS_KEY=fluxer
  --from-literal=FLUXER_S3_SECRET_KEY="$(rnd)"
  --from-literal=FLUXER_SUDO_MODE_SECRET="$(rnd)"
  --from-literal=FLUXER_CONNECTION_INITIATION_SECRET="$(rnd)"
  --from-literal=FLUXER_GATEWAY_RPC_AUTH_TOKEN="$(rnd)"
  --from-literal=FLUXER_MEDIA_PROXY_SECRET_KEY="$(rnd)"
  --from-literal=FLUXER_MEDIA_PROXY_UPLOAD_RELAY_SECRET_BASE64="$(rnd 32)"
  --from-literal=FLUXER_ADMIN_SECRET_KEY_BASE="$(rnd 48)"
  --from-literal=FLUXER_ADMIN_OAUTH_CLIENT_SECRET="$(rnd)"
  --from-literal=LIVEKIT_API_KEY=fluxer
  --from-literal=LIVEKIT_API_SECRET="$(rnd)"
  --from-literal=VALKEY_PASSWORD="$(rnd)"
  --from-literal=GARAGE_ADMIN_TOKEN="$(rnd)"
  --from-literal=FLUXER_KLIPY_API_KEY="CHANGEME"
)

kubectl create secret generic fluxer-secrets -n fluxer "${args[@]}" --dry-run=client -o yaml \
  | kubectl apply -f -
```
