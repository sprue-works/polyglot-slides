#!/usr/bin/env bash
# Self-test for tools/release.sh against a stubbed clasp (no network, no auth).
# Asserts the exact clasp command sequence for both the first release
# (deployment.json empty -> create) and a steady-state release (redeploy).
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Minimal copy of the repo: the script, a src/, and a deployment.json we control.
mkdir -p "$work/repo/tools" "$work/repo/src" "$work/bin"
cp "$repo_root/tools/release.sh" "$work/repo/tools/"
echo 'function f() {}' >"$work/repo/src/Code.js"

# Stub clasp: logs every invocation, answers --json calls with canned output.
cat >"$work/bin/clasp" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$CLASP_LOG"
case "$1" in
  version) echo '{"versionNumber": 7}' ;;
  deploy) echo '{"deploymentId": "AKfycb-new", "versionNumber": 7, "description": "v1.0.0"}' ;;
  redeploy) echo '{"deploymentId": "AKfycb-existing", "versionNumber": 7, "description": "v1.1.0"}' ;;
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

# --- Case 1: first release, no deployment yet -> clasp deploy creates one.
export CLASP_LOG="$work/log1"; : >"$CLASP_LOG"
echo '{"deploymentId": ""}' >"$work/repo/deployment.json"
export GITHUB_OUTPUT="$work/out1"; : >"$GITHUB_OUTPUT"
unset GITHUB_STEP_SUMMARY
(cd "$work/repo" && tools/release.sh v1.0.0 >"$work/stdout1" 2>"$work/stderr1")
cat >"$work/expect1" <<'EXP'
push --force
version --json v1.0.0
deploy --versionNumber 7 --description v1.0.0 --json
EXP
assert_log "$work/expect1"
grep -q '^version=7$' "$GITHUB_OUTPUT" || fail "case 1: version output missing"
grep -q '^deployment_id=AKfycb-new$' "$GITHUB_OUTPUT" || fail "case 1: deployment_id output missing"
grep -q '^deployment_created=true$' "$GITHUB_OUTPUT" || fail "case 1: deployment_created should be true"
grep -q 'AKfycb-new' "$work/stderr1" || fail "case 1: should tell the operator to commit the new deployment ID"
echo "ok   first release creates the deployment"

# --- Case 2: deployment.json set -> redeploy that deployment, never create.
export CLASP_LOG="$work/log2"; : >"$CLASP_LOG"
echo '{"deploymentId": "AKfycb-existing"}' >"$work/repo/deployment.json"
export GITHUB_OUTPUT="$work/out2"; : >"$GITHUB_OUTPUT"
(cd "$work/repo" && tools/release.sh v1.1.0 >"$work/stdout2" 2>"$work/stderr2")
cat >"$work/expect2" <<'EXP'
push --force
version --json v1.1.0
redeploy AKfycb-existing --versionNumber 7 --description v1.1.0 --json
EXP
assert_log "$work/expect2"
grep -q '^deployment_id=AKfycb-existing$' "$GITHUB_OUTPUT" || fail "case 2: deployment_id output wrong"
grep -q '^deployment_created=false$' "$GITHUB_OUTPUT" || fail "case 2: deployment_created should be false"
echo "ok   later release updates the existing deployment"

# --- Case 3: no tag argument -> usage error, no clasp calls.
export CLASP_LOG="$work/log3"; : >"$CLASP_LOG"
if (cd "$work/repo" && tools/release.sh >/dev/null 2>&1); then
  fail "case 3: missing tag should fail"
fi
[ ! -s "$CLASP_LOG" ] || fail "case 3: clasp must not be called without a tag"
echo "ok   missing tag is rejected before touching clasp"

# --- Case 4: clasp version returns garbage -> fail before deploying.
export CLASP_LOG="$work/log4"; : >"$CLASP_LOG"
cat >"$work/bin/clasp" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$CLASP_LOG"
case "$1" in version) echo '{}' ;; esac
STUB
if (cd "$work/repo" && tools/release.sh v1.2.0 >/dev/null 2>&1); then
  fail "case 4: unparseable version output should fail"
fi
grep -q '^deploy\|^redeploy' "$CLASP_LOG" && fail "case 4: must not deploy without a version number"
echo "ok   bad clasp version output aborts before deploying"

echo "all release.sh tests passed"
