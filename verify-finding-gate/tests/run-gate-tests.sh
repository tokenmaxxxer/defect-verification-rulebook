#!/usr/bin/env bash
# verify-finding-gate's own gate, exercised as a real subprocess.
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
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/finding-gate.sh" >/dev/null 2>&1
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

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
