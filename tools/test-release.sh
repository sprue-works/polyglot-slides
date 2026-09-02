#!/usr/bin/env bash
# Self-test for tools/release.sh against a stubbed clasp (no network, no auth).
# Asserts the exact clasp command sequence (push, then version -- nothing is
# deployed: the Marketplace pins a version number) and that the release tells
# the operator which number to paste into App Configuration.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Minimal copy of the repo: the script, a src/, and a listing.json we control.
mkdir -p "$work/repo/tools" "$work/repo/src" "$work/repo/marketplace" "$work/bin"
cp "$repo_root/tools/release.sh" "$work/repo/tools/"
echo 'function f() {}' >"$work/repo/src/Code.js"

# Stub clasp: logs every invocation, answers --json calls with canned output.
cat >"$work/bin/clasp" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$CLASP_LOG"
case "$1" in
  version) echo '{"versionNumber": 7}' ;;
esac
STUB
chmod +x "$work/bin/clasp"
export PATH="$work/bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }

assert_log() { # assert_log <expected-lines-file>
  if ! diff -u "$1" "$CLASP_LOG"; then
    fail "clasp call sequence differs (expected vs actual above)"
  fi
}

set_published() { # set_published <json-value>
  printf '{"extension": {"publishedVersion": %s}}' "$1" >"$work/repo/marketplace/listing.json"
}

# --- Case 1: a release pushes, cuts a version, and tells the operator what to paste.
export CLASP_LOG="$work/log1"; : >"$CLASP_LOG"
set_published 3
export GITHUB_OUTPUT="$work/out1"; : >"$GITHUB_OUTPUT"
export GITHUB_STEP_SUMMARY="$work/summary1"; : >"$GITHUB_STEP_SUMMARY"
(cd "$work/repo" && tools/release.sh v1.1.0 >"$work/stdout1" 2>"$work/stderr1")
cat >"$work/expect1" <<'EXP'
push --force
version --json v1.1.0
EXP
assert_log "$work/expect1"
grep -q '^version=7$' "$GITHUB_OUTPUT" || fail "case 1: version output missing"
grep -q '^published_version=3$' "$GITHUB_OUTPUT" || fail "case 1: published_version output missing"
grep -q 'deployment' "$GITHUB_OUTPUT" && fail "case 1: no deployment outputs should remain"
grep -q 'Slides add-on script version' "$GITHUB_STEP_SUMMARY" || fail "case 1: summary must name the console field to bump"
grep -q 'enter `7`' "$GITHUB_STEP_SUMMARY" || fail "case 1: summary must say which number to paste"
grep -q 'publishedVersion` to `7`' "$GITHUB_STEP_SUMMARY" || fail "case 1: summary must say to commit publishedVersion"
grep -q 'stay on version 3' "$GITHUB_STEP_SUMMARY" || fail "case 1: summary must show the currently pinned version"
grep -q 'Slides add-on script version' "$work/stdout1" || fail "case 1: terminal output must carry the same instruction"
echo "ok   release pushes, versions, and surfaces the manual bump"

# --- Case 2: no tag argument -> usage error, no clasp calls.
export CLASP_LOG="$work/log2"; : >"$CLASP_LOG"
unset GITHUB_OUTPUT GITHUB_STEP_SUMMARY
if (cd "$work/repo" && tools/release.sh >/dev/null 2>&1); then
  fail "case 2: missing tag should fail"
fi
[ ! -s "$CLASP_LOG" ] || fail "case 2: clasp must not be called without a tag"
echo "ok   missing tag is rejected before touching clasp"

# --- Case 3: malformed listing.json -> fail before touching clasp.
export CLASP_LOG="$work/log3"; : >"$CLASP_LOG"
echo '{"extension":' >"$work/repo/marketplace/listing.json"
if (cd "$work/repo" && tools/release.sh v1.2.0 >/dev/null 2>&1); then
  fail "case 3: malformed listing.json should fail"
fi
[ ! -s "$CLASP_LOG" ] || fail "case 3: clasp must not be called with malformed listing.json"
echo "ok   malformed listing.json is rejected before touching clasp"

# --- Case 4: publishedVersion missing or not a positive integer -> fail before clasp.
for bad in '"1"' 0 -2 1.5 null; do
  export CLASP_LOG="$work/log4"; : >"$CLASP_LOG"
  set_published "$bad"
  if (cd "$work/repo" && tools/release.sh v1.2.0 >/dev/null 2>&1); then
    fail "case 4: publishedVersion $bad should fail"
  fi
  [ ! -s "$CLASP_LOG" ] || fail "case 4: clasp must not be called with publishedVersion $bad"
done
echo "ok   bad publishedVersion is rejected before touching clasp"

# --- Case 5: clasp version returns garbage -> fail, and no summary is written.
export CLASP_LOG="$work/log5"; : >"$CLASP_LOG"
set_published 3
export GITHUB_STEP_SUMMARY="$work/summary5"; : >"$GITHUB_STEP_SUMMARY"
cat >"$work/bin/clasp" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$CLASP_LOG"
case "$1" in version) echo '{}' ;; esac
STUB
if (cd "$work/repo" && tools/release.sh v1.2.0 >/dev/null 2>&1); then
  fail "case 5: unparseable version output should fail"
fi
[ ! -s "$GITHUB_STEP_SUMMARY" ] || fail "case 5: must not write a summary without a version number"
echo "ok   bad clasp version output aborts before reporting"

echo "all release.sh tests passed"
