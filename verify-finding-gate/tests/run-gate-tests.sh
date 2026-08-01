#!/usr/bin/env bash
# verify-finding-gate's own gate, exercised as a real subprocess.
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
    | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/finding-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
run_raw() { # want name raw-stdin-json
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$3" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/finding-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
run_raw_precreate() { # want name preexisting-content raw-stdin-json
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$3" > "$td/$REC"
  printf '%s' "$4" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/finding-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

VALID='# attempt 1
outcome: reproduced
finding:
  verdict: Present
  addressed_to: coding
  severity: blocking'

NO_VERDICT='# attempt 1
outcome: reproduced
finding:
  addressed_to: coding
  severity: blocking'

NO_ADDRESSED='# attempt 1
outcome: reproduced
finding:
  verdict: Present
  severity: blocking'

NO_SEVERITY='# attempt 1
outcome: reproduced
finding:
  verdict: Present
  addressed_to: coding'

BAD_SEVERITY='# attempt 1
outcome: reproduced
finding:
  verdict: Present
  addressed_to: coding
  severity: urgent'

NOT_REPRODUCED='# attempt 1
outcome: not-reproduced'

NO_OUTCOME='# attempt 1
notes: still investigating'

run allow reproduced-valid-finding    "$REC" "$VALID"
run deny  reproduced-missing-verdict  "$REC" "$NO_VERDICT"
run deny  reproduced-missing-addressed "$REC" "$NO_ADDRESSED"
run deny  reproduced-missing-severity "$REC" "$NO_SEVERITY"
run deny  reproduced-invalid-severity "$REC" "$BAD_SEVERITY"
run allow not-reproduced-no-finding   "$REC" "$NOT_REPRODUCED"
run allow no-outcome-field            "$REC" "$NO_OUTCOME"
run allow unrelated-path              "docs/issue-7/notes.md" "$VALID"

# Fields-before-outcome and fields-interleaved orderings (issue-20 C3/design
# item 3): the docstring always promised a lookback to the previous heading;
# the prior forward-only window never caught fields placed ahead of the
# trailing outcome: line. These fixtures are exactly the ordering the old
# 8/8-green suite never exercised.
FIELDS_BEFORE_OUTCOME='# attempt 1
finding:
  verdict: Present
  addressed_to: coding
  severity: blocking
outcome: reproduced'

FIELDS_BEFORE_MISSING_ONE='# attempt 1
finding:
  addressed_to: coding
  severity: blocking
outcome: reproduced'

TWO_ATTEMPTS_MIXED_ORDER='# attempt 1
finding:
  verdict: Present
  addressed_to: coding
  severity: blocking
outcome: reproduced

# attempt 2
outcome: reproduced
finding:
  verdict: Absent
  addressed_to: coding
  severity: advisory'

run allow reproduced-fields-before-outcome        "$REC" "$FIELDS_BEFORE_OUTCOME"
run deny  reproduced-fields-before-missing-verdict "$REC" "$FIELDS_BEFORE_MISSING_ONE"
run allow reproduced-two-attempts-mixed-order      "$REC" "$TWO_ATTEMPTS_MIXED_ORDER"

# Mandatory cases (issue-20 design item 5).
run_raw deny finding-malformed-json '{"tool_name":"Write",'
run_raw deny finding-empty-payload  ''

KILL_ON_JSON='{"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/reports/verify.md","content":"# attempt 1\noutcome: reproduced"}}'
td_off="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td_off"; mkdir -p "$td_off/docs/issue-7/reports"
printf '%s' "$KILL_ON_JSON" | env CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_PROJECT_DIR="$td_off" VERIFY_FINDING_GATE_OFF=typo /bin/bash "$HOOKS/finding-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
report deny "$got" finding-kill-switch-unrecognized-value-stays-active
rm -rf "$td_off"

BASH_MISMATCH_JSON='{"tool_name":"Bash","tool_input":{"command":"printf x > docs/issue-7/reports/verify.md"}}'
run_raw deny finding-bash-write-target "$BASH_MISMATCH_JSON"

CURRENT_NOT_REPRODUCED='# attempt 1
outcome: not-reproduced'
EDIT_REPLACE_ALL_JSON='{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-7/reports/verify.md","old_string":"not-reproduced","new_string":"reproduced","replace_all":true}}'
run_raw_precreate deny finding-edit-replace-all-no-finding "$CURRENT_NOT_REPRODUCED" "$EDIT_REPLACE_ALL_JSON"

MULTIEDIT_MIXED_JSON='{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-7/reports/verify.md","edits":[{"old_string":"not-reproduced","new_string":"reproduced","replace_all":false},{"old_string":"# attempt 1","new_string":"# attempt 1\nfinding:\n  verdict: Present\n  addressed_to: coding\n  severity: blocking","replace_all":true}]}}'
run_raw_precreate allow finding-multiedit-mixed-replace-all "$CURRENT_NOT_REPRODUCED" "$MULTIEDIT_MIXED_JSON"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
