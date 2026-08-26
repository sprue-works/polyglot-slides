#!/usr/bin/env bash
# Cut a numbered Apps Script version for a release and point the Marketplace
# deployment at it.
#
#   tools/release.sh v1.2.0
#
# Steps: clasp push -> clasp version "<tag>" -> update the deployment named in
# deployment.json to that version (or create it on the very first release).
#
# Run by .github/workflows/deploy.yml on tag pushes; works locally too with a
# `clasp login` session. Requires clasp 3 (uses --json output).
set -euo pipefail

tag="${1:-}"
if [ -z "$tag" ]; then
  echo "usage: tools/release.sh <tag>" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v clasp >/dev/null 2>&1; then
  echo "error: clasp not found on PATH" >&2
  exit 1
fi

json_field() { # json_field <key> <json>
  node -e 'const v = JSON.parse(process.argv[2])[process.argv[1]]; if (v === undefined || v === null) process.exit(1); process.stdout.write(String(v))' "$1" "$2"
}

deployment_id="$(json_field deploymentId "$(cat deployment.json)" || true)"

echo "==> Pushing src/ to the script project"
clasp push --force

echo "==> Creating version for $tag"
version_json="$(clasp version --json "$tag")"
version="$(json_field versionNumber "$version_json")" || {
  echo "error: could not read versionNumber from clasp output: $version_json" >&2
  exit 1
}
echo "    version $version"

if [ -n "$deployment_id" ]; then
  echo "==> Updating deployment $deployment_id -> version $version"
  clasp redeploy "$deployment_id" --versionNumber "$version" --description "$tag" --json >/dev/null
  created=false
else
  echo "==> No deploymentId in deployment.json; creating the deployment"
  deploy_json="$(clasp deploy --versionNumber "$version" --description "$tag" --json)"
  deployment_id="$(json_field deploymentId "$deploy_json")" || {
    echo "error: could not read deploymentId from clasp output: $deploy_json" >&2
    exit 1
  }
  created=true
  cat >&2 <<MSG

    Created deployment $deployment_id.
    Commit it so future releases update this deployment instead of making new ones:

      deployment.json -> "deploymentId": "$deployment_id"

MSG
fi

echo "==> Released $tag: version $version, deployment $deployment_id"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version=$version"
    echo "deployment_id=$deployment_id"
    echo "deployment_created=$created"
  } >>"$GITHUB_OUTPUT"
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Apps Script release $tag"
    echo
    echo "- version: \`$version\`"
    echo "- deployment: \`$deployment_id\`"
    if [ "$created" = true ]; then
      echo
      echo "**New deployment created.** Commit its ID to \`deployment.json\` so later releases update it in place."
    fi
  } >>"$GITHUB_STEP_SUMMARY"
fi
