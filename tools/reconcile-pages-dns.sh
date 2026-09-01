#!/usr/bin/env bash
# Check or reconcile the DNS-only GitHub Pages CNAME in Cloudflare.
set -euo pipefail

readonly record_name="polyglot.sprue.works"
readonly record_target="sprue-works.github.io"
readonly api_base="https://api.cloudflare.com/client/v4"

usage() {
  echo "usage: $0 --check|--apply" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
case "$1" in
  --check|--apply) mode="$1" ;;
  *) usage ;;
esac

if [[ -z ${CLOUDFLARE_API_TOKEN:-} ]]; then
  echo "CLOUDFLARE_API_TOKEN is required" >&2
  exit 2
fi
if [[ -z ${CLOUDFLARE_ZONE_ID:-} ]]; then
  echo "CLOUDFLARE_ZONE_ID is required" >&2
  exit 2
fi
for command_name in curl jq; do
  command -v "$command_name" >/dev/null || {
    echo "$command_name is required" >&2
    exit 2
  }
done

cloudflare_request() { # cloudflare_request <method> <path> [json-payload]
  local method="$1"
  local path="$2"
  local payload="${3:-}"
  local args=(
    --silent
    --show-error
    --fail-with-body
    --request "$method"
    --header "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
    --header "Content-Type: application/json"
  )
  if [[ -n "$payload" ]]; then
    args+=(--data "$payload")
  fi
  curl "${args[@]}" "${api_base}${path}"
}

require_success() { # require_success <response>
  local response="$1"
  local details
  if ! jq -e '.success == true' >/dev/null <<<"$response"; then
    # Surface Cloudflare's own error text so an invalid token, a missing
    # permission, or a bad zone is diagnosable. The API echoes no credentials.
    details="$(jq -r '[.errors[]? | "\(.code // "?"): \(.message // "unknown error")"] | join("; ")' <<<"$response" 2>/dev/null || true)"
    if [[ -n "$details" ]]; then
      echo "Cloudflare API request failed: $details" >&2
    else
      echo "Cloudflare API request failed" >&2
    fi
    exit 1
  fi
}

readonly records_path="/zones/${CLOUDFLARE_ZONE_ID}/dns_records"
response="$(cloudflare_request GET "${records_path}?name=${record_name}")"
require_success "$response"

record_count="$(jq '.result | length' <<<"$response")"
if ((record_count > 1)); then
  echo "multiple conflicting records exist for ${record_name}; refusing to mutate them" >&2
  exit 1
fi

payload="$(jq -cn \
  --arg type CNAME \
  --arg name "$record_name" \
  --arg content "$record_target" \
  '{type:$type,name:$name,content:$content,ttl:1,proxied:false}')"

if ((record_count == 0)); then
  if [[ "$mode" == --check ]]; then
    echo "${record_name} is missing" >&2
    exit 1
  fi
  response="$(cloudflare_request POST "$records_path" "$payload")"
  require_success "$response"
  echo "created DNS-only CNAME ${record_name} -> ${record_target}"
  exit 0
fi

record_type="$(jq -r '.result[0].type' <<<"$response")"
if [[ "$record_type" != CNAME ]]; then
  echo "conflicting ${record_type} record exists for ${record_name}; refusing to mutate it" >&2
  exit 1
fi

if jq -e --arg name "$record_name" --arg target "$record_target" \
  '.result[0] | .type == "CNAME" and .name == $name and .content == $target and .proxied == false and .ttl == 1' \
  >/dev/null <<<"$response"; then
  echo "DNS-only CNAME ${record_name} -> ${record_target} is already correct"
  exit 0
fi

if [[ "$mode" == --check ]]; then
  echo "CNAME ${record_name} does not match the required DNS-only Pages target" >&2
  exit 1
fi

record_id="$(jq -r '.result[0].id' <<<"$response")"
if [[ -z "$record_id" || "$record_id" == null ]]; then
  echo "Cloudflare response did not include a record ID" >&2
  exit 1
fi
response="$(cloudflare_request PATCH "${records_path}/${record_id}" "$payload")"
require_success "$response"
echo "reconciled DNS-only CNAME ${record_name} -> ${record_target}"
