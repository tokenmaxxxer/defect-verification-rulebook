#!/usr/bin/env bash
# The surviving review gates, exercised as real subprocesses.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../verify/hooks"
CORE_FIXTURE="$HERE/fixtures/core"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/verify.md
run() { # want name gate file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$4" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$5")" "$td" \
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$3" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
# run_raw <want> <name> <gate> <raw-stdin-json> — for cases the printf-based
# run() above can't express (malformed JSON, Edit/MultiEdit, Bash writes).
run_raw() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$4" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$3" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
# run_raw_precreate <want> <name> <gate> <preexisting-content> <raw-stdin-json>
# — same as run_raw but seeds the target record file with content first, so
# Edit/MultiEdit's old_string has something real to match against.
run_raw_precreate() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$4" > "$td/$REC"
  printf '%s' "$5" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$3" >/dev/null 2>&1
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

# Mandatory cases (issue-20 design item 5): malformed JSON, absolute + ./
# path variants, and a Bash-tool write reaching the same record path.
run_raw deny cc-malformed-json closed-checks-gate.sh 'not json at all'
run_raw deny cc-empty-payload  closed-checks-gate.sh ''

ABS_TARGET_PREFIX='ABS_PLACEHOLDER'
run_abs_and_dotslash() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  content="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$CC_OK")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s/docs/issue-7/reports/verify.md","content":%s},"cwd":"%s"}' \
    "$td" "$content" "$td" \
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/closed-checks-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report allow "$got" cc-absolute-path
  printf '{"tool_name":"Write","tool_input":{"file_path":"./docs/issue-7/reports/verify.md","content":%s},"cwd":"%s"}' \
    "$content" "$td" \
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/closed-checks-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report allow "$got" cc-dotslash-path
  rm -rf "$td"
}
run_abs_and_dotslash
unset ABS_TARGET_PREFIX

BASH_MISMATCH_JSON='{"tool_name":"Bash","tool_input":{"command":"printf x > docs/issue-7/reports/verify.md"}}'
run_raw deny cc-bash-write-target closed-checks-gate.sh "$BASH_MISMATCH_JSON"

# issue-23 D1: missing-core mandatory case — no CLAUDE_PLUGIN_ROOT_CORE and no
# fallback core/ directory present (this checkout has none at its root), so
# the gate-lib.sh source guard must fail-closed (deny/non-zero), never allow.
run_missing_core() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  errfile="$(mktemp)"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"},"cwd":"%s"}' "$REC" "$td" \
    | env -u CLAUDE_PLUGIN_ROOT_CORE CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/closed-checks-gate.sh" >/dev/null 2>"$errfile"
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report deny "$got" cc-missing-core
  if [ "$got" = deny ] && grep -q 'cannot source gate-lib.sh' "$errfile"; then
    pass=$((pass+1)); printf 'ok     %-34s %s\n' cc-missing-core-msg "has deny message"
  else
    fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' cc-missing-core-msg "deny message" "$(cat "$errfile")"
  fi
  rm -f "$errfile"; rm -rf "$td"
}
run_missing_core

# Edit with replace_all against a multiply-occurring old_string, and a
# MultiEdit mixing replace_all true/false in one call.
CC_TWO_SHAS='closed_checks:
  - check: a
    code_sha: abc1234oldsha
  - check: b
    code_sha: abc1234oldsha
code_under_review: def5678newsha'
CC_EDIT_REPLACE_ALL='{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-7/reports/verify.md","old_string":"abc1234oldsha","new_string":"def5678newsha","replace_all":true}}'
run_raw_precreate allow cc-edit-replace-all closed-checks-gate.sh "$CC_TWO_SHAS" "$CC_EDIT_REPLACE_ALL"

CC_MULTIEDIT_MIXED='{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-7/reports/verify.md","edits":[{"old_string":"code_under_review: def5678newsha","new_string":"code_under_review: def5678newsha\ncode_sha: def5678newsha","replace_all":false},{"old_string":"abc1234oldsha","new_string":"def5678newsha","replace_all":true}]}}'
run_raw_precreate allow cc-multiedit-mixed-replace-all closed-checks-gate.sh "$CC_TWO_SHAS" "$CC_MULTIEDIT_MIXED"

printf '\n== verify: %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || fail_any=1

# Each verify-* plugin (issue-17) is self-contained and self-tested; run its
# own suite as a subprocess rather than re-implementing its cases here.
fail_any="${fail_any:-0}"
for suite in "$HERE/../verify-outcome-gate/tests/run-gate-tests.sh" \
             "$HERE/../verify-finding-gate/tests/run-gate-tests.sh" \
             "$HERE/../verify-state-guard/tests/run-gate-tests.sh" \
             "$HERE/../verify-directive-depth/tests/directive-depth-test.sh"; do
  printf '\n-- %s --\n' "$(basename "$(dirname "$(dirname "$suite")")")"
  bash "$suite" || fail_any=1
done

exit "$fail_any"
