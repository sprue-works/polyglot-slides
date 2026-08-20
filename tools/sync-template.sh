#!/usr/bin/env bash
# Push src/ to the template deck's container-bound script.
#
# The template deck (INSTALL.md, Path A) carries its own copy of the source,
# bound to the presentation. That copy drifts whenever src/ changes, so run
# this after any change that should reach new recipients.
#
# Existing recipient copies are NOT updated — they are frozen at the version
# they were copied from. That is by design; see INSTALL.md.
#
# Requires: clasp, already authenticated (clasp login).
set -euo pipefail

# Bound script of "Polyglot Slides — Template (make a copy)".
# Override for a different template, e.g. when testing:
#   POLYGLOT_TEMPLATE_SCRIPT_ID=... tools/sync-template.sh
TEMPLATE_SCRIPT_ID="${POLYGLOT_TEMPLATE_SCRIPT_ID:-1hQJ6n7ButKEZbpFdLbyM0TGj555-5q-Q2diiEWSac5bGWZwo8ocBw_YP}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v clasp >/dev/null 2>&1; then
  echo "error: clasp not found on PATH" >&2
  exit 1
fi

# Push from a scratch dir so the repo's own .clasp.json (which points at the
# dev script project) is never touched or shadowed.
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

mkdir -p "$staging/src"
cp "$repo_root"/src/* "$staging/src/"

cat >"$staging/.clasp.json" <<JSON
{
  "scriptId": "$TEMPLATE_SCRIPT_ID",
  "rootDir": "src",
  "scriptExtensions": [".js", ".gs"],
  "htmlExtensions": [".html"],
  "jsonExtensions": [".json"],
  "filePushOrder": [],
  "skipSubdirectories": false
}
JSON

echo "Pushing $repo_root/src -> template script $TEMPLATE_SCRIPT_ID"
cd "$staging"
clasp push --force
echo "Done. New copies of the template deck will carry this version."
