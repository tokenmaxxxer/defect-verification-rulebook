#!/usr/bin/env bash
# The surviving review gates, exercised as real subprocesses.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../verify/hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/verify.md
run() { # want name gate file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$4" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$5")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$3" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

CC_OK='closed_checks:
  - check: input-validation
    code_sha: abc1234def
code_under_review: abc1234def'
CC_MISMATCH='closed_checks:
  - check: input-validation
    code_sha: 9999999
code_under_review: abc1234def'
CC_NOFIELD='closed_checks:
  - check: input-validation
    code_sha: abc1234def'
run allow cc-sha-match    closed-checks-gate.sh "$REC" "$CC_OK"
run deny  cc-sha-mismatch closed-checks-gate.sh "$REC" "$CC_MISMATCH"
run deny  cc-no-field     closed-checks-gate.sh "$REC" "$CC_NOFIELD"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
