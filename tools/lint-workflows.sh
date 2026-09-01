#!/usr/bin/env bash
# Validate GitHub Actions workflow syntax, expressions, and context placement.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly actionlint_image="rhysd/actionlint:1.7.12"

cd "$repo_root"

if command -v actionlint >/dev/null 2>&1; then
  exec actionlint -color "$@"
fi

if command -v docker >/dev/null 2>&1; then
  exec docker run --rm \
    --volume "$repo_root:/repo" \
    --workdir /repo \
    "$actionlint_image" -color "$@"
fi

echo "FAIL: actionlint or Docker is required to validate GitHub Actions workflows" >&2
exit 1
