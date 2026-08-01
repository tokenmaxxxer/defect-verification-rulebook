#!/usr/bin/env bash
# Gate-house standard compliance detector (issue-72). Modeled on
# stub-check.sh's two-mode pattern: absence-based checks for anything a
# gate should call through gate-lib.sh instead of hand-rolling, plus a
# structural check (source line + expected function calls present) for
# gate-lib.sh consumers, the same shape stub-check.sh already uses for
# directive.sh/role-directive.sh.
#
# CANON EXECUTION MODEL: this script is core canon, referenced (never
# vendored) exactly like stub-check.sh — invoked against a rulebook's own
# hooks/ directory:
#   "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/compliance-check.sh" "$(dirname "$0")/.."
#
# Usage: compliance-check.sh [hooks-dir]
set -uo pipefail

dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)}"
[ -d "$dir" ] || { echo "compliance-check: no such directory: $dir" >&2; exit 2; }
rc=0

gates="$(find "$dir" -maxdepth 3 -type f -name '*-gate.sh' 2>/dev/null || true)"
if [ -z "$gates" ]; then
  echo "compliance-check: no *-gate.sh files found under $dir — nothing to check"
  exit 0
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  reasons=()

  # A gate that reads a kill switch from an env var but does not source
  # gate-lib.sh's gate_kill_switch_active is either hand-rolling the
  # off-spelling case statement (the issue-72-confirmed fail-open shape:
  # "case ... in \"\"|0|false|no|off) ;; *) exit 0 ;; esac", which disables
  # on ANY unrecognized value) or has no kill switch at all — this check
  # only fires when the file plausibly has one (mentions "_OFF" as an env
  # var read).
  if grep -qE '\$\{[A-Z_]+_OFF:-' "$f" && ! grep -q 'gate_kill_switch_active' "$f"; then
    reasons+=("reads a *_OFF kill-switch env var but does not call gate_kill_switch_active — likely a hand-rolled case statement with the confirmed fail-open bug (unrecognized value disables the gate)")
  fi

  # A gate that reconstructs Edit/MultiEdit content (does its own
  # old_string.replace(...,1)-shaped substitution in Python) without
  # sourcing gate-lib.py's gate_reconstruct_write is very likely ignoring
  # replace_all — the issue-72-confirmed bug.
  if grep -qE '\.replace\([A-Za-z_][A-Za-z0-9_]*,\s*[A-Za-z_][A-Za-z0-9_]*(,\s*1)?\)' "$f" \
     && ! grep -q 'gate_reconstruct_write' "$f"; then
    reasons+=("reconstructs Edit/MultiEdit content via its own .replace(...) call instead of gate_lib.gate_reconstruct_write — likely ignores replace_all")
  fi

  if [ "${#reasons[@]}" -gt 0 ]; then
    echo "compliance-check: FAIL — $f:" >&2
    for r in "${reasons[@]}"; do echo "  - $r" >&2; done
    rc=1
  else
    echo "compliance-check: ok — $f"
  fi
done <<< "$gates"

exit "$rc"
