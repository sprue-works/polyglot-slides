#!/usr/bin/env bash
# Cheap, dependency-free sanity checks for the add-on sources.
# Used by .github/workflows/ci.yml; run locally before pushing.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0

for f in src/*.js; do
  if node --check "$f"; then
    echo "ok   $f"
  else
    status=1
  fi
done

for f in src/appsscript.json .clasp.json deployment.json; do
  if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$f"; then
    echo "ok   $f"
  else
    echo "FAIL $f: invalid JSON" >&2
    status=1
  fi
done

for f in tools/*.sh; do
  if bash -n "$f"; then
    echo "ok   $f"
  else
    status=1
  fi
done

exit $status
