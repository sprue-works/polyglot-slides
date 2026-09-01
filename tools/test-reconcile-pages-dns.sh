#!/usr/bin/env bash
# Self-test for tools/reconcile-pages-dns.sh against a stubbed Cloudflare API.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"

fail() { echo "FAIL: $*" >&2; exit 1; }

cat >"$work/bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
method=GET
url=""
payload=""
while (($#)); do
  case "$1" in
    -X|--request) method="$2"; shift 2 ;;
    --data|--data-raw) payload="$2"; shift 2 ;;
    -H|--header) shift 2 ;;
    --*) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf '%s\t%s\t%s\n' "$method" "$url" "$payload" >>"$CURL_LOG"

case "$MOCK_CASE:$method" in
  correct:GET)
    printf '%s\n' '{"success":true,"result":[{"id":"record-1","type":"CNAME","name":"polyglot.sprue.works","content":"sprue-works.github.io","proxied":false,"ttl":1}]}'
    ;;
  missing:GET)
    printf '%s\n' '{"success":true,"result":[]}'
    ;;
  missing:POST)
    printf '%s\n' '{"success":true,"result":{"id":"record-2"}}'
    ;;
  drifted:GET)
    printf '%s\n' '{"success":true,"result":[{"id":"record-1","type":"CNAME","name":"polyglot.sprue.works","content":"old.example.com","proxied":true,"ttl":300}]}'
    ;;
  drifted:PATCH)
    printf '%s\n' '{"success":true,"result":{"id":"record-1"}}'
    ;;
  conflict:GET)
    printf '%s\n' '{"success":true,"result":[{"id":"record-a","type":"A","name":"polyglot.sprue.works","content":"192.0.2.1","proxied":false,"ttl":1}]}'
    ;;
  multiple:GET)
    printf '%s\n' '{"success":true,"result":[{"id":"record-a","type":"A","name":"polyglot.sprue.works","content":"192.0.2.1","proxied":false,"ttl":1},{"id":"record-b","type":"AAAA","name":"polyglot.sprue.works","content":"2001:db8::1","proxied":false,"ttl":1}]}'
    ;;
  *)
    printf '%s\n' '{"success":false,"errors":[{"message":"unexpected test request"}]}'
    ;;
esac
STUB
chmod +x "$work/bin/curl"
export PATH="$work/bin:$PATH"
export CLOUDFLARE_API_TOKEN="test-token-never-print"
export CLOUDFLARE_ZONE_ID="test-zone-never-print"
export CURL_LOG="$work/curl.log"

run_case() { # run_case <case> <mode>
  export MOCK_CASE="$1"
  : >"$CURL_LOG"
  "$repo_root/tools/reconcile-pages-dns.sh" "$2" >"$work/stdout" 2>"$work/stderr"
}

run_case correct --check
[[ $(wc -l <"$CURL_LOG") -eq 1 ]] || fail "correct record should only be read"
grep -q 'already correct' "$work/stdout" || fail "correct record should report a no-op"

export MOCK_CASE=missing
: >"$CURL_LOG"
if "$repo_root/tools/reconcile-pages-dns.sh" --check >"$work/stdout" 2>"$work/stderr"; then
  fail "check mode should fail when the record is missing"
fi
[[ $(wc -l <"$CURL_LOG") -eq 1 ]] || fail "check mode must not create a missing record"

run_case missing --apply
grep -q $'^POST\t' "$CURL_LOG" || fail "apply mode should create a missing record"
grep -q '"type":"CNAME"' "$CURL_LOG" || fail "create payload should use CNAME"
grep -q '"content":"sprue-works.github.io"' "$CURL_LOG" || fail "create payload should use the Pages target"
grep -q '"proxied":false' "$CURL_LOG" || fail "create payload should remain DNS-only"

run_case drifted --apply
grep -q $'^PATCH\t' "$CURL_LOG" || fail "apply mode should reconcile a drifted CNAME"
grep -q '"ttl":1' "$CURL_LOG" || fail "reconcile payload should use automatic TTL"

for conflict_case in conflict multiple; do
  export MOCK_CASE="$conflict_case"
  : >"$CURL_LOG"
  if "$repo_root/tools/reconcile-pages-dns.sh" --apply >"$work/stdout" 2>"$work/stderr"; then
    fail "$conflict_case records should stop reconciliation"
  fi
  [[ $(wc -l <"$CURL_LOG") -eq 1 ]] || fail "$conflict_case records must not be mutated"
done
grep -q 'multiple conflicting records' "$work/stderr" || fail "multiple-record error should explain the conflict"

if grep -R -q 'test-token-never-print\|test-zone-never-print' "$work/stdout" "$work/stderr"; then
  fail "credentials must never be printed"
fi

unset CLOUDFLARE_API_TOKEN
if "$repo_root/tools/reconcile-pages-dns.sh" --check >"$work/stdout" 2>"$work/stderr"; then
  fail "missing credentials should fail before calling Cloudflare"
fi
grep -q 'CLOUDFLARE_API_TOKEN' "$work/stderr" || fail "missing-token error should name the required variable"

echo "all reconcile-pages-dns.sh tests passed"
