#!/usr/bin/env bash
# Cut a numbered Apps Script version for a release.
#
#   tools/release.sh v1.2.0
#
# Steps: clasp push -> clasp version "<tag>". That version NUMBER is what the
# Marketplace SDK App Configuration form for an Editor add-on pins ("Slides
# add-on script version"); there is no deployment on this path, so nothing is
# deployed here. Installed users stay on marketplace/listing.json's
# extension.publishedVersion until a human bumps the console field to the new
# number and commits the same number to publishedVersion (RUNBOOK section 4).
# This script prints that instruction and, in CI, hands the numbers to
# deploy.yml, which opens a tracking issue for the bump.
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

# The version currently pinned in App Configuration (what IS live). Read it
# before touching clasp so a broken listing fails fast and leaves no stray
# version behind.
listing_file="marketplace/listing.json"
if ! published="$(node -e 'const v = JSON.parse(process.argv[1]).extension?.publishedVersion; if (!Number.isInteger(v) || v < 1) process.exit(1); process.stdout.write(String(v))' "$(cat "$listing_file")" 2>/dev/null)"; then
  echo "error: $listing_file must be valid JSON with a positive-integer extension.publishedVersion" >&2
  exit 1
fi

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
Installed users stay on version $published until a human pins version $version:

1. Marketplace SDK -> App Configuration -> **Slides add-on script version**: enter \`$version\`, Save (RUNBOOK section 4; no re-review for a version bump alone).
2. Then record it in the repo: set \`extension.publishedVersion\` to \`$version\` in \`$listing_file\` and commit.
MSG
}

echo "==> Released $tag as script version $version (App Configuration currently pins $published)"
echo
paste_instructions | sed 's/^/    /'

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version=$version"
    echo "published_version=$published"
  } >>"$GITHUB_OUTPUT"
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Apps Script release $tag"
    echo
    echo "- script version created: \`$version\`"
    echo "- version pinned in App Configuration (\`$listing_file\` publishedVersion): \`$published\`"
    echo
    paste_instructions
  } >>"$GITHUB_STEP_SUMMARY"
fi
