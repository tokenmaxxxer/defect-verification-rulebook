#!/usr/bin/env bash
# Exercises verify-directive-depth/hooks/directive.sh as a real subprocess.
#
# directive.sh sources ${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/role-directive.sh
# (core's own documented usage pattern, issue-20 C1) — at runtime that
# resolves to the real installed core plugin, but no core checkout exists in
# this repo or in CI, so this test pins CLAUDE_PLUGIN_ROOT_CORE at a
# provisioned fixture core/ (tests/fixtures/core/) carrying a pinned copy of
# role-directive.sh, letting the script run deterministically. CLAUDE_ROLE
# must also be set — core_role_directive() is a no-op with no role, and the
# kill switch it enforces is per-role (<ROLE>_CYCLE_OFF), not
# VERIFY_DIRECTIVE_DEPTH_OFF (issue-20 C2: the local kill-switch case
# statement was removed from directive.sh as regrown boilerplate on top of
# core_role_directive's own switch).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIRECTIVE="$HERE/../hooks/directive.sh"
CORE_FIXTURE="$HERE/../../tests/fixtures/core"
pass=0; fail=0
report() {
  # report <label> <expr-result: 0=true>
  if [ "$2" -eq 0 ]; then pass=$((pass+1)); printf 'ok     %-28s\n' "$1";
  else fail=$((fail+1)); printf 'FAIL   %-28s\n' "$1"; fi
}

OUT="$(CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_ROLE=defect-verification bash "$DIRECTIVE" 2>/dev/null)"

echo "$OUT" | grep -q 'reproduced'; report "outcome:reproduced" $?
echo "$OUT" | grep -q 'not-reproduced'; report "outcome:not-reproduced" $?
echo "$OUT" | grep -q 'blocked: needs-repro-access'; report "outcome:blocked" $?
echo "$OUT" | grep -q 'blocking'; report "word:blocking" $?
echo "$OUT" | grep -q 'advisory'; report "word:advisory" $?
echo "$OUT" | grep -q 'code_under_review'; report "word:code_under_review" $?

OFF_OUT="$(CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE" CLAUDE_ROLE=defect-verification DEFECT_VERIFICATION_CYCLE_OFF=1 bash "$DIRECTIVE" 2>/dev/null)"
[ -z "$OFF_OUT" ]; report "kill-switch:empty-output" $?

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
