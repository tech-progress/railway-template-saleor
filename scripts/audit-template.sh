#!/usr/bin/env bash
set -euo pipefail

template_id="${1:?Usage: ./scripts/audit-template.sh TEMPLATE_ID [EXPECTED_STATUS]}"
expected_status="${2:-}"
template_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template_json="$(railway api 'query Audit($id: String!) { template(id: $id) { name status serializedConfig } }' --var "id=${template_id}" --compact)"
graph_json="$(cd "${template_root}" && ./node_modules/.bin/railway-iac-ts .railway/railway.ts)"

[[ "$(jq -r '.data.template.name' <<<"${template_json}")" == "Saleor commerce" ]]
[[ -z "${expected_status}" || "$(jq -r '.data.template.status' <<<"${template_json}")" == "${expected_status}" ]]
[[ "$(jq -r '.data.template.serializedConfig.services | [.[] | .name] | sort | join("\n")' <<<"${template_json}")" == $'Saleor API\nSaleor Dashboard\nSaleor PostgreSQL\nSaleor Valkey\nSaleor Worker' ]]

failures=0
for service_name in "Saleor API" "Saleor Dashboard" "Saleor PostgreSQL" "Saleor Valkey" "Saleor Worker"; do
  desired="$(jq -c --arg service "${service_name}" '.graph.resources[] | select(.type == "service" and .name == $service)' <<<"${graph_json}")"
  actual="$(jq -c --arg service "${service_name}" '[.data.template.serializedConfig.services[] | select(.name == $service)][0]' <<<"${template_json}")"
  if [[ "$(jq -r '.source.type' <<<"${desired}")" == "image" ]]; then
    [[ "$(jq -r '.source.image' <<<"${actual}")" == "$(jq -r '.source.image' <<<"${desired}")" ]] || failures=$((failures + 1))
    [[ "$(jq -r '.source.repo // ""' <<<"${actual}")" == "" ]] || failures=$((failures + 1))
  else
    [[ "$(jq -r '.source.image // ""' <<<"${actual}")" == "" ]] || failures=$((failures + 1))
    [[ "$(jq -r '.source.repo | sub("^https://github.com/"; "") | sub("\\.git$"; "")' <<<"${actual}")" == "$(jq -r '.source.repo' <<<"${desired}")" ]] || failures=$((failures + 1))
    for field in branch rootDirectory; do
      [[ "$(jq -r --arg f "${field}" '.source[$f]' <<<"${actual}")" == "$(jq -r --arg f "${field}" '.source[$f]' <<<"${desired}")" ]] || failures=$((failures + 1))
    done
    [[ "$(jq -r '.build.dockerfilePath' <<<"${actual}")" == "Dockerfile" ]] || failures=$((failures + 1))
  fi
  for field in startCommand healthcheckPath healthcheckTimeout; do
    [[ "$(jq -r --arg f "${field}" '.deploy[$f] // ""' <<<"${actual}")" == "$(jq -r --arg f "${field}" '.deploy[$f] // ""' <<<"${desired}")" ]] || failures=$((failures + 1))
  done
  while IFS= read -r variable; do
    key="$(jq -r '.key' <<<"${variable}")"; expected="$(jq -r '.value' <<<"${variable}")"
    [[ "$(jq -r --arg key "${key}" '.variables[$key].defaultValue // "__MISSING__"' <<<"${actual}")" == "${expected:-__MISSING__}" || ( -z "${expected}" && "$(jq -r --arg key "${key}" '.variables[$key].defaultValue // ""' <<<"${actual}")" == "" ) ]] || failures=$((failures + 1))
    optional="$(jq -r --arg key "${key}" '.variables[$key].isOptional // false' <<<"${actual}")"
    [[ ( "${key}" == "EMAIL_URL" && "${optional}" == "true" ) || ( "${key}" != "EMAIL_URL" && "${optional}" == "false" ) ]] || failures=$((failures + 1))
  done < <(jq -c --arg service "${service_name}" '.[$service] | to_entries[]' "${template_root}/template-defaults.json")
done

while IFS= read -r service_name; do
  expected="$(jq -c --arg service "${service_name}" '.[$service]' "${template_root}/template-volumes.json")"
  actual="$(jq -c --arg service "${service_name}" '[.data.template.serializedConfig.services[] | select(.name == $service) | .volumeMounts[] | {mountPath,sizeMB}][0]' <<<"${template_json}")"
  [[ "${actual}" == "${expected}" ]] || failures=$((failures + 1))
done < <(jq -r 'keys[]' "${template_root}/template-volumes.json")

for service_name in "Saleor API" "Saleor Dashboard"; do
  expected="$(jq -r --arg service "${service_name}" '.[$service].publicPort' "${template_root}/template-networking.json")"
  actual="$(jq -r --arg service "${service_name}" '[.data.template.serializedConfig.services[] | select(.name == $service) | .networking.serviceDomains["<hasDomain>"].port][0] // 0' <<<"${template_json}")"
  [[ "${actual}" == "${expected}" ]] || failures=$((failures + 1))
done
(( failures == 0 )) || { echo "Saleor template audit failed with ${failures} mismatch(es)." >&2; exit 1; }
echo "Template ${template_id} matches Saleor sources, commands, defaults, volumes, and networking."

