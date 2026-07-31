#!/usr/bin/env bash
# Self-runnable test harness for verify-state-guard, exercised as real
# subprocesses. Mirrors the run() helper shape of the repo's top-level
# tests/run-gate-tests.sh, adapted for state-file-dependent behavior.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
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
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# run_guard_unrelated: write to a path outside the gate's target scope.
run_guard_unrelated() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/other"
  printf '{"tool_name":"Write","tool_input":{"file_path":"docs/other/notes.md","content":"loop_state: cleared"},"cwd":"%s"}' "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/state-guard.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report allow "$got" "unrelated-path-allowed"
}

REPRODUCED_CONTENT='loop_state: reproduced'
CLEARED_UNRESOLVED='severity: blocking
loop_state: cleared'
CLEARED_RESOLVED='severity: blocking
resolved: yes
loop_state: cleared'

run_guard deny  reproduced-no-state-file   "$REPRODUCED_CONTENT" ""
run_guard deny  reproduced-state-idle      "$REPRODUCED_CONTENT" "idle"
run_guard allow reproduced-state-reproducing "$REPRODUCED_CONTENT" "reproducing"
run_guard deny  cleared-unresolved-blocking "$CLEARED_UNRESOLVED" "reproduced"
run_guard allow cleared-resolved-blocking   "$CLEARED_RESOLVED" "reproduced"
run_guard allow no-loop-state-field         "no relevant field here" "idle"
run_guard_unrelated

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
