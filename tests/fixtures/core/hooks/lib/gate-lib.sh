#!/usr/bin/env bash
# TEST FIXTURE — pinned copy of tokenmaxxxer-core's core/hooks/lib/gate-lib.sh
# (issue-72, main@22a7cad), provisioned so this repo's own test suite can
# exercise the gate-lib-sourcing gates deterministically without a live core
# plugin install in CI (issue-20 C4). Production gates never read this path —
# they source ${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh, which
# resolves to the real installed core plugin at runtime. Not a hooks/ file,
# not in tests/stub-check.sh's CANON_GATES list, not sourced by any gate.
#
# Sourceable library: the gate-house standard (issue-72). A rulebook's own
# PreToolUse gate sources this file and calls its gate_* functions instead
# of hand-rolling the trap/kill-switch/path-normalize/reconstruct/deny
# machinery every core/hooks/*.sh gate independently re-derived (issue-72
# survey: same shapes, 2-3 different idioms each, one confirmed live bug).
# Reference only, never copy (docs/handbooks/canon-scripts.md) — added to
# core/hooks/tests/canon-manifest.txt so stub-check.sh catches a vendored
# copy.
#
# Usage, from a gate script. The source line MUST carry an `||` guard
# (issue-75-confirmed defect: an unguarded source that fails when core is
# unreachable runs no code — including no gate_* function definition —
# after which every documented `gate_kill_switch_active ... || { exit 0; }`
# call site reads the resulting "command not found" (127) as the kill
# switch being off, silently allowing everything). Fail closed instead:
#
#   . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
#   gate_trap_fail_closed
#   set -uo pipefail
#   gate_kill_switch_active CORE_OFF || { trap - EXIT; exit 0; }
#   ...
#   gate_deny "some-gate" "reason text"     # writes to stderr, exit 2
#   gate_allow                              # exit 0
#
# GATE_LIB_PY resolves to this file's sibling gate-lib.py so a gate's own
# Python payload can load it:
#
#   import importlib.util, os
#   _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
#   gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

GATE_LIB_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export GATE_LIB_PY="$GATE_LIB_SH_DIR/gate-lib.py"

# gate_trap_fail_closed — install the one canonical fail-closed EXIT trap.
# Claude Code treats any hook exit other than 0/2 as non-blocking
# (fail-open); this remaps every other exit to 2. Call this as the very
# first statement in a gate script, before `set -uo pipefail`, so a syntax
# error or unset-variable abort on the next line is still caught.
gate_trap_fail_closed() {
  trap 'rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
    echo "fail-closed: gate aborted (rc=$rc)" >&2
    exit 2
  fi' EXIT
}

# gate_kill_switch_active <value> — the house kill-switch convention:
# unrecognized value = ACTIVE (the fixed default; issue-72 survey section 2
# found every kill switch in core's own canon did the opposite). The
# original idiom, `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac`,
# treated empty/"0"/"false"/"no"/"off" as "stay active" (correct) but
# treated EVERY other value — including the intended on-spellings
# (1/true/yes/on) AND any unrecognized garbage like a typo — identically as
# "disable." That conflated "the switch was deliberately turned on" with
# "the switch holds an unrecognized value," which is the fail-open bug: a
# stray typo in an env var silently disabled the gate. The fix narrows the
# disabling set to only the recognized on-spellings; every other value,
# recognized-off or unrecognized, stays active.
#
# Returns 0 (true, "stay active") for empty/unset, a recognized
# off-spelling, or anything unrecognized. Returns 1 (false, "disable")
# only for a recognized on-spelling (1/true/yes/on, case-insensitive).
#
#   gate_kill_switch_active "${CORE_OFF:-}" || { trap - EXIT; exit 0; }
gate_kill_switch_active() {
  local v
  v="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "$v" in
    1|true|yes|on) return 1 ;;
    *) return 0 ;;
  esac
}

# gate_deny <role-or-gate-name> <message> — stderr-only deny protocol
# (issue-72 survey section 4: already-uniform in core, codified here).
gate_deny() {
  echo "${1:-gate}: refused — $2" >&2
  exit 2
}

gate_allow() {
  exit 0
}

# gate_bash_write_targets <command> — extract path-shaped tokens from a
# Bash tool_input.command string, the token-scan technique already used by
# approval-gate.sh/board-gate.sh (issue-72 survey section 7), so a gate
# that only matched Write/Edit/MultiEdit/NotebookEdit (like
# record-fields-gate.sh before this migration) can also see a Bash-based
# file write. Prints one candidate token per line; caller applies its own
# path pattern to each.
gate_bash_write_targets() {
  printf '%s\n' "$1" | grep -oE '[[:alnum:]_./~$-]+' || true
}
