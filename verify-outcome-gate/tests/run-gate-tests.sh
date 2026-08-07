#!/usr/bin/env bash
# Self-runnable tests for verify-outcome-gate's outcome-gate.sh, exercised as
# a real subprocess. Mirrors the shape of the repo's top-level
# tests/run-gate-tests.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
CORE_FIXTURE="$HERE/../../tests/fixtures/core"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/verify.md
run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/outcome-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
run_raw() { # want name raw-stdin-json
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$3" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/outcome-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
run_raw_precreate() { # want name preexisting-content raw-stdin-json
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$3" > "$td/$REC"
  printf '%s' "$4" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/outcome-gate.sh" >/dev/null 2>&1
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
run deny  no-outcome-field            "$REC" "$NO_OUTCOME"
run allow unrelated-path             "docs/issue-7/notes.md" "$BAD_VALUE"

# Mandatory cases (issue-20 design item 5).
run_raw deny outcome-malformed-json '{"tool_name":"Write",'
run_raw deny outcome-empty-payload  ''

td_off="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td_off"; mkdir -p "$td_off/docs/issue-7/reports"
KILL_ON_JSON="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/reports/verify.md","content":sys.argv[1]}}))' "$BAD_VALUE")"
printf '%s' "$KILL_ON_JSON" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td_off" VERIFY_OUTCOME_GATE_OFF=typo /bin/bash "$HOOKS/outcome-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
report deny "$got" outcome-kill-switch-unrecognized-value-stays-active
rm -rf "$td_off"

BASH_MISMATCH_JSON='{"tool_name":"Bash","tool_input":{"command":"printf x > docs/issue-7/reports/verify.md"}}'
run_raw deny outcome-bash-write-target "$BASH_MISMATCH_JSON"

EDIT_REPLACE_ALL_JSON='{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-7/reports/verify.md","old_string":"outcome: reproduced","new_string":"outcome: reproduced","replace_all":true}}'
run_raw_precreate deny outcome-edit-replace-all-no-evidence "$NO_EVIDENCE" "$EDIT_REPLACE_ALL_JSON"

MULTIEDIT_MIXED_JSON='{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-7/reports/verify.md","edits":[{"old_string":"outcome: pass","new_string":"outcome: reproduced","replace_all":false},{"old_string":"evidence: some evidence","new_string":"evidence: some evidence","replace_all":true}]}}'
run_raw_precreate allow outcome-multiedit-mixed-replace-all "$BAD_VALUE" "$MULTIEDIT_MIXED_JSON"

# issue-23 D1: missing-core mandatory case.
td_mc="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td_mc"; mkdir -p "$td_mc/docs/issue-7/reports"
errfile_mc="$(mktemp)"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"},"cwd":"%s"}' "$REC" "$td_mc" \
  | env -u CLAUDE_PLUGIN_ROOT_CORE CLAUDE_PROJECT_DIR="$td_mc" /bin/bash "$HOOKS/outcome-gate.sh" >/dev/null 2>"$errfile_mc"
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
report deny "$got" outcome-missing-core
if [ "$got" = deny ] && grep -q 'cannot source gate-lib.sh' "$errfile_mc"; then
  pass=$((pass+1)); printf 'ok     %-34s %s\n' outcome-missing-core-msg "has deny message"
else
  fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' outcome-missing-core-msg "deny message" "$(cat "$errfile_mc")"
fi
rm -f "$errfile_mc"; rm -rf "$td_mc"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
