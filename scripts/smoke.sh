#!/usr/bin/env bash
set -euo pipefail

api_url="${1:-http://localhost:8000}"
dashboard_url="${2:-http://localhost:9000}"
admin_email="${ADMIN_EMAIL:?Set ADMIN_EMAIL}"
admin_password="${ADMIN_PASSWORD:?Set ADMIN_PASSWORD}"

curl --fail --silent --show-error "${api_url}/health/" >/dev/null
curl --fail --silent --show-error "${dashboard_url}/" | grep -q '<div id="dashboard-app">'

shop_payload='{"query":"query { shop { name } }"}'
curl --fail --silent --show-error "${api_url}/graphql/" \
  --header 'Content-Type: application/json' --data-binary "${shop_payload}" \
  | jq -e '.data.shop.name | type == "string"' >/dev/null

login_payload="$({ jq -nc --arg email "${admin_email}" --arg password "${admin_password}" '{query:"mutation($email:String!,$password:String!){tokenCreate(email:$email,password:$password){token errors{field message}}}",variables:{email:$email,password:$password}}'; })"
curl --fail --silent --show-error "${api_url}/graphql/" \
  --header 'Content-Type: application/json' --data-binary "${login_payload}" \
  | jq -e '.data.tokenCreate.token | type == "string" and length > 20' >/dev/null

echo "Saleor API, dashboard, GraphQL, and administrator authentication checks passed."
