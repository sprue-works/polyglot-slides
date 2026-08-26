#!/usr/bin/env bash
# Self-test for tools/check-listing.sh: the real repo passes, and each kind of
# drift it exists to catch makes it fail.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Fresh copy of just what the check reads.
fresh() {
  rm -rf "$work/repo"
  mkdir -p "$work/repo/tools" "$work/repo/src"
  cp -R "$repo_root/marketplace" "$repo_root/docs" "$work/repo/"
  cp "$repo_root/tools/check-listing.sh" "$work/repo/tools/"
  cp "$repo_root/src/appsscript.json" "$work/repo/src/"
  cp "$repo_root/deployment.json" "$work/repo/"
}

expect_pass() { # expect_pass <label>
  (cd "$work/repo" && tools/check-listing.sh >"$work/out" 2>&1) || { cat "$work/out"; fail "$1: expected pass"; }
  echo "ok   $1 passes"
}
expect_fail() { # expect_fail <label> <grep-pattern>
  if (cd "$work/repo" && tools/check-listing.sh >"$work/out" 2>&1); then cat "$work/out"; fail "$1: expected failure"; fi
  grep -q "$2" "$work/out" || { cat "$work/out"; fail "$1: failure message should mention '$2'"; }
  echo "ok   $1 is rejected"
}

fresh; expect_pass "repo as committed"

fresh
(cd "$work/repo" && node -e 'const fs=require("fs"),f="src/appsscript.json",j=JSON.parse(fs.readFileSync(f));j.oauthScopes.push("https://www.googleapis.com/auth/drive");fs.writeFileSync(f,JSON.stringify(j))')
expect_fail "manifest scope not in listing" "scopes differ"

fresh
(cd "$work/repo" && node -e 'const fs=require("fs"),f="marketplace/listing.json",j=JSON.parse(fs.readFileSync(f));j.extension.deployment.source="somewhere-else.json";fs.writeFileSync(f,JSON.stringify(j))')
expect_fail "deployment reference not deployment.json" "deployment.json#deploymentId"

fresh
rm "$work/repo/marketplace/assets/icon-32.png"
expect_fail "missing icon" "icon-32.png does not exist"

fresh
cp "$work/repo/marketplace/assets/icon-48.png" "$work/repo/marketplace/assets/icon-32.png"
expect_fail "wrong icon size" "expected 32x32"

fresh
(cd "$work/repo" && node -e 'const fs=require("fs"),f="marketplace/screenshots.json",j=JSON.parse(fs.readFileSync(f));j.screenshots=["marketplace/assets/icon-128.png"];fs.writeFileSync(f,JSON.stringify(j))')
expect_fail "screenshot with wrong size" "expected 1280x800"

fresh
rm "$work/repo/docs/privacy.html"
expect_fail "privacy page missing" "privacy.html does not exist"

fresh
(cd "$work/repo" && node -e 'const fs=require("fs"),f="marketplace/listing.json",j=JSON.parse(fs.readFileSync(f));j.distribution.visibility="private";fs.writeFileSync(f,JSON.stringify(j))')
expect_fail "private without domain" "privateDomain"

echo "all check-listing.sh tests passed"
