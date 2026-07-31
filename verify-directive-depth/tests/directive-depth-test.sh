#!/usr/bin/env bash
# Exercises verify-directive-depth/hooks/directive.sh as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIRECTIVE="$HERE/../hooks/directive.sh"
pass=0; fail=0
report() {
  # report <label> <expr-result: 0=true>
  if [ "$2" -eq 0 ]; then pass=$((pass+1)); printf 'ok     %-28s\n' "$1";
  else fail=$((fail+1)); printf 'FAIL   %-28s\n' "$1"; fi
}

OUT="$(bash "$DIRECTIVE" 2>/dev/null)"

echo "$OUT" | grep -q 'reproduced'; report "outcome:reproduced" $?
echo "$OUT" | grep -q 'not-reproduced'; report "outcome:not-reproduced" $?
echo "$OUT" | grep -q 'blocked: needs-repro-access'; report "outcome:blocked" $?
echo "$OUT" | grep -q 'blocking'; report "word:blocking" $?
echo "$OUT" | grep -q 'advisory'; report "word:advisory" $?
echo "$OUT" | grep -q 'code_under_review'; report "word:code_under_review" $?

OFF_OUT="$(VERIFY_DIRECTIVE_DEPTH_OFF=1 bash "$DIRECTIVE" 2>/dev/null)"
[ -z "$OFF_OUT" ]; report "kill-switch:empty-output" $?

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
