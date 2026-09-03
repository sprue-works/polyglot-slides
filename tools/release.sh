#!/usr/bin/env bash
# Cut a numbered Apps Script version for a release.
#
#   tools/release.sh v1.2.0
#
# Steps: clasp push -> clasp version "<tag>". That version NUMBER is what the
# Marketplace SDK App Configuration form for an Editor add-on pins ("Slides
# add-on script version"); there is no deployment on this path, so nothing is
# deployed here, and installed users stay on the currently pinned version until
# a human enters the new number in the console (RUNBOOK section 4). This
# script prints that instruction and, in CI, hands the number to deploy.yml,
# which opens a tracking issue for the bump. The repo keeps no copy of the
# pinned number -- it cannot verify one -- so that issue is the record.
#
# Run by .github/workflows/deploy.yml on tag pushes; works locally too with a
# `clasp login` session. Requires clasp 3 (uses --json output) and node.
set -euo pipefail

tag="${1:-}"
if [ -z "$tag" ]; then
  echo "usage: tools/release.sh <tag>" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for tool in clasp node; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool not found on PATH" >&2
    exit 1
  fi
done

json_field() { # json_field <key> <json>
  node -e 'const v = JSON.parse(process.argv[2])[process.argv[1]]; if (v === undefined || v === null) process.exit(1); process.stdout.write(String(v))' "$1" "$2"
}

echo "==> Pushing src/ to the script project"
clasp push --force

echo "==> Creating version for $tag"
version_json="$(clasp version --json "$tag")"
version="$(json_field versionNumber "$version_json")" || {
  echo "error: could not read versionNumber from clasp output: $version_json" >&2
  exit 1
}
echo "    version $version"

paste_instructions() { # markdown; the same text goes to the terminal and the step summary
  cat <<MSG
Installed users stay on the currently pinned version until a human pins version $version:
Marketplace SDK -> App Configuration -> **Slides add-on script version**: enter \`$version\`, Save (RUNBOOK section 4; no re-review for a version bump alone).
MSG
}

echo "==> Released $tag as script version $version"
echo
paste_instructions | sed 's/^/    /'

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=$version" >>"$GITHUB_OUTPUT"
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Apps Script release $tag"
    echo
    echo "- script version created: \`$version\`"
    echo
    paste_instructions
  } >>"$GITHUB_STEP_SUMMARY"
fi
