#!/usr/bin/env bash
set -euo pipefail

template_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required=(.dockerignore .env.example .gitignore .railway/railway.ts CHANGELOG.md Dockerfile LICENSE_REVIEW.md MARKETPLACE.md PUBLISHING.md README.md SUPPORT.md UPGRADE.md VERSION bun.lock compose.yaml package.json template-buckets.json template-defaults.json template-descriptions.json template-networking.json template-volumes.json scripts/audit-template.sh scripts/bootstrap.py scripts/load-jwt-key.py scripts/restore-template-draft.sh scripts/smoke.sh scripts/start-api.sh scripts/start-worker.sh scripts/storage-smoke.py scripts/verify.sh scripts/with-jwt-key.sh)
for file in "${required[@]}"; do test -f "${template_root}/${file}" || { echo "Missing ${file}" >&2; exit 1; }; done

version="$(<"${template_root}/VERSION")"; [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
grep -Fq "## [${version}] - 2026-07-31" "${template_root}/CHANGELOG.md"
for file in README.md PUBLISHING.md; do grep -Fq "current template release is \`v${version}\`" "${template_root}/${file}"; done
publish_description="$(grep -E '^  --description "' "${template_root}/PUBLISHING.md" | cut -d '"' -f 2)"
[[ -n "${publish_description}" && ${#publish_description} -le 75 ]]

POSTGRES_PASSWORD=verify-postgres SECRET_KEY=verify-secret-key-with-more-than-fifty-random-characters ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=verify-admin-password MINIO_ROOT_PASSWORD=verify-minio-password docker compose -f "${template_root}/compose.yaml" config --quiet
for file in template-buckets.json template-defaults.json template-descriptions.json template-networking.json template-volumes.json; do jq empty "${template_root}/${file}"; done
for file in scripts/audit-template.sh scripts/restore-template-draft.sh scripts/smoke.sh scripts/start-api.sh scripts/start-worker.sh scripts/verify.sh scripts/with-jwt-key.sh; do bash -n "${template_root}/${file}"; done
python3 -c 'import pathlib,sys; [compile(pathlib.Path(p).read_text(),p,"exec") for p in sys.argv[1:]]' "${template_root}/scripts/bootstrap.py" "${template_root}/scripts/load-jwt-key.py" "${template_root}/scripts/storage-smoke.py"

graph="$(cd "${template_root}" && ./node_modules/.bin/railway-iac-ts .railway/railway.ts)"
jq -e '
  .graph.resources |
  ([.[] | select(.type=="service") | .name] | sort) == ["Saleor API","Saleor Dashboard","Saleor PostgreSQL","Saleor Valkey","Saleor Worker"] and
  ([.[] | select(.type=="volume")] | length) == 2 and
  ([.[] | select(.type=="bucket" and .name=="Saleor Media" and .config.region=="iad")] | length) == 1 and
  ([.[] | select(.name=="Saleor API")][0].source.repo == "tech-progress/railway-template-saleor") and
  ([.[] | select(.name=="Saleor API")][0].source.branch == "release-v1") and
  ([.[] | select(.name=="Saleor API")][0].deploy.healthcheckPath == "/health/") and
  ([.[] | select(.name=="Saleor Worker")][0].deploy.startCommand == "/template/start-worker.sh") and
  ([.[] | select(.name=="Saleor Dashboard")][0].deploy.healthcheckPath == "/")
' <<<"${graph}" >/dev/null

pins=(3fc21b69182fd0d94731e12c2121faeef022ddf6bbf1398e12e19cb12add2049 c1ce2f625316bf1e02dd8070335bf3bdbaeaa388e14b094d35dd5db2f9b60cf3 3d0f7584ed7d04e27fa050d6683a74746608faf21f202be78460d679cc56461f a038175878d66b9d274fbf8be73c0305e93798b83917647f167e18cef3c71eec)
for pin in "${pins[@]}"; do grep -Rqs "${pin}" "${template_root}/Dockerfile" "${template_root}/compose.yaml" "${template_root}/.railway/railway.ts"; done
jq -e '."Saleor API".SECRET_KEY=="${{secret(64)}}" and ."Saleor API".ADMIN_PASSWORD=="${{secret(32)}}" and ."Saleor API".DEBUG=="False" and ."Saleor API".SEND_USAGE_TELEMETRY=="False" and ."Saleor Worker".SECRET_KEY=="${{Saleor API.SECRET_KEY}}"' "${template_root}/template-defaults.json" >/dev/null
if find "${template_root}" -type f \( -name .env -o -name '*.local' \) -print -quit | grep -q .; then echo "Local secret file found." >&2; exit 1; fi
echo "Saleor template structure, pins, variables, bucket, volumes, and networking are valid."
