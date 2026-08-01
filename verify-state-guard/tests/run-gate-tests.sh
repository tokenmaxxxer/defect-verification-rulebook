#!/usr/bin/env bash
# Self-runnable test harness for verify-state-guard, exercised as real
# subprocesses. Mirrors the run() helper shape of the repo's top-level
# tests/run-gate-tests.sh, adapted for state-file-dependent behavior.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
CORE_FIXTURE="$HERE/../../tests/fixtures/core"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/verify.md

# run WANT NAME content SEED_HIGHEST(or "" for none)
run_guard() {
  local want="$1" name="$2" content="$3" seed="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports" "$td/.claude"
  if [ -n "$seed" ]; then
    printf '{"highest_state":"%s"}' "$seed" > "$td/.claude/verify-state-issue-7.json"
  fi
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# run_guard_unrelated: write to a path outside the gate's target scope.
run_guard_unrelated() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/other"
  printf '{"tool_name":"Write","tool_input":{"file_path":"docs/other/notes.md","content":"loop_state: cleared"},"cwd":"%s"}' "$td" \
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report allow "$got" "unrelated-path-allowed"
}

REPRODUCED_CONTENT='loop_state: reproduced'
CLEARED_UNRESOLVED='severity: blocking
loop_state: cleared'
CLEARED_RESOLVED='severity: blocking
resolved: yes
loop_state: cleared'
REPRODUCING_CONTENT='loop_state: reproducing'

run_guard deny  reproduced-no-state-file   "$REPRODUCED_CONTENT" ""
run_guard deny  reproduced-state-idle      "$REPRODUCED_CONTENT" "idle"
run_guard allow reproduced-state-reproducing "$REPRODUCED_CONTENT" "reproducing"
run_guard deny  cleared-unresolved-blocking "$CLEARED_UNRESOLVED" "reproduced"
run_guard allow cleared-resolved-blocking   "$CLEARED_RESOLVED" "reproduced"
run_guard allow no-loop-state-field         "no relevant field here" "idle"
run_guard_unrelated

# issue-23 D3: general regression check — a record already at
# highest_state: cleared re-declaring loop_state: reproducing must be
# denied. Before D3 this was an unclamped false-allow (only
# reproduced/cleared were checked against highest_rank).
run_guard deny  regression-cleared-then-reproducing "$REPRODUCING_CONTENT" "cleared"
run_guard allow same-state-repeat-reproducing "$REPRODUCING_CONTENT" "reproducing"

# issue-23 D2 (gate-lib migration): mandatory cases established as this
# repo's own precedent (issue-20 design item 5), mirrored here now that
# state-guard.sh sources gate-lib.sh like the other three gates.
run_raw() { # want name raw-stdin-json
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$3" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
run_raw_precreate() { # want name preexisting-content raw-stdin-json seed
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports" "$td/.claude"
  printf '%s' "$3" > "$td/$REC"
  if [ -n "${5:-}" ]; then
    printf '{"highest_state":"%s"}' "$5" > "$td/.claude/verify-state-issue-7.json"
  fi
  printf '%s' "$4" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

run_raw deny state-malformed-json '{"tool_name":"Write",'
run_raw deny state-empty-payload  ''

td_off="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td_off"; mkdir -p "$td_off/docs/issue-7/reports"
KILL_ON_JSON="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/reports/verify.md","content":"loop_state: cleared"}}))')"
printf '%s' "$KILL_ON_JSON" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td_off" VERIFY_STATE_GUARD_OFF=typo /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
report deny "$got" state-kill-switch-unrecognized-value-stays-active
rm -rf "$td_off"

BASH_MISMATCH_JSON='{"tool_name":"Bash","tool_input":{"command":"printf x > docs/issue-7/reports/verify.md"}}'
run_raw deny state-bash-write-target "$BASH_MISMATCH_JSON"

# Absolute vs ./-prefixed path equivalence.
run_abs_and_dotslash() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports" "$td/.claude"
  printf '{"highest_state":"reproducing"}' > "$td/.claude/verify-state-issue-7.json"
  content="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$REPRODUCED_CONTENT")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s/docs/issue-7/reports/verify.md","content":%s},"cwd":"%s"}' \
    "$td" "$content" "$td" \
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report allow "$got" state-absolute-path
  printf '{"tool_name":"Write","tool_input":{"file_path":"./docs/issue-7/reports/verify.md","content":%s},"cwd":"%s"}' \
    "$content" "$td" \
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report allow "$got" state-dotslash-path
  rm -rf "$td"
}
run_abs_and_dotslash

# Edit with replace_all against a multiply-occurring old_string, and a
# MultiEdit mixing replace_all true/false in one call.
CURRENT_REPRODUCING='loop_state: reproducing
loop_state: reproducing'
EDIT_REPLACE_ALL_JSON='{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-7/reports/verify.md","old_string":"loop_state: reproducing","new_string":"loop_state: reproduced","replace_all":true}}'
run_raw_precreate allow state-edit-replace-all "$CURRENT_REPRODUCING" "$EDIT_REPLACE_ALL_JSON" reproducing

MULTIEDIT_MIXED_JSON='{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-7/reports/verify.md","edits":[{"old_string":"loop_state: reproducing\nloop_state: reproducing","new_string":"loop_state: reproducing\nloop_state: reproducing\nnote: x","replace_all":false},{"old_string":"loop_state: reproducing","new_string":"loop_state: reproduced","replace_all":true}]}}'
run_raw_precreate allow state-multiedit-mixed-replace-all "$CURRENT_REPRODUCING" "$MULTIEDIT_MIXED_JSON" reproducing

# NotebookEdit reconstruction (gate_reconstruct_write honors new_source).
NOTEBOOK_JSON='{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"docs/issue-7/reports/verify.md","new_source":"loop_state: reproduced"}}'
run_raw_precreate allow state-notebook-edit "" "$NOTEBOOK_JSON" reproducing

# issue-23 D1: missing-core mandatory case.
td_mc="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td_mc"; mkdir -p "$td_mc/docs/issue-7/reports"
printf '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/reports/verify.md","content":"x"},"cwd":"%s"}' "$td_mc" \
  | env -u CLAUDE_PLUGIN_ROOT_CORE CLAUDE_PROJECT_DIR="$td_mc" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; *) got=fail-closed ;; esac
report fail-closed "$got" state-missing-core
rm -rf "$td_mc"

# --- verify-state.sh rank-tracking behavior --------------------------------

run_state_bump() {
  local name="$1" first_content="$2" second_content="$3" want_final="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$first_content" > "$td/docs/issue-7/reports/verify.md"
  printf '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$REC" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/verify-state.sh" >/dev/null 2>&1

  printf '%s' "$second_content" > "$td/docs/issue-7/reports/verify.md"
  printf '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$REC" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/verify-state.sh" >/dev/null 2>&1

  got="$(python3 -c '
import json,sys
try:
    print(json.load(open(sys.argv[1])).get("highest_state",""))
except Exception:
    print("")
' "$td/.claude/verify-state-issue-7.json" 2>/dev/null)"
  rm -rf "$td"
  report "$want_final" "$got" "$name"
}

run_state_bump "state-tracks-reproducing" "loop_state: reproducing" "loop_state: reproducing" "reproducing"
run_state_bump "state-never-lowered" "loop_state: reproducing" "loop_state: idle" "reproducing"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
