#!/usr/bin/env bash
# Self-runnable tests for verify-outcome-gate's outcome-gate.sh, exercised as
# a real subprocess. Mirrors the shape of the repo's top-level
# tests/run-gate-tests.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/verify.md
run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/outcome-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

REPRODUCED='attempt: qa-defect-12
outcome: reproduced
evidence: repro steps at commit abc1234'

NOT_REPRODUCED='attempt: qa-defect-13
outcome: not-reproduced
evidence: ran steps 1-5 against build xyz, no failure observed'

BLOCKED='attempt: qa-defect-14
outcome: blocked: needs-repro-access
evidence: missing staging DB access to trigger the race condition'

BAD_VALUE='attempt: qa-defect-15
outcome: pass
evidence: some evidence'

NO_EVIDENCE='attempt: qa-defect-16
outcome: reproduced'

NO_OUTCOME='attempt: qa-defect-17
steps: looked at the code, did not attempt reproduction yet'

run allow reproduced-with-evidence   "$REC" "$REPRODUCED"
run allow not-reproduced-with-evidence "$REC" "$NOT_REPRODUCED"
run allow blocked-with-evidence      "$REC" "$BLOCKED"
run deny  invalid-outcome-value      "$REC" "$BAD_VALUE"
run deny  reproduced-no-evidence     "$REC" "$NO_EVIDENCE"
run allow no-outcome-field           "$REC" "$NO_OUTCOME"
run allow unrelated-path             "docs/issue-7/notes.md" "$BAD_VALUE"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
