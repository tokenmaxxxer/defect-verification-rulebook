# shellcheck shell=bash
# Shared root-resolution helper for verify-cycle's procedure gates. Sourced,
# never executed. Mirrors state-gate.sh's fail-closed shape: an indeterminate
# project root is refused by callers, never silently allowed.
#
# resolve_root <target-path-or-empty> -> echoes an absolute project root or
# empty. Candidate order: validated CLAUDE_PROJECT_DIR (dir exists and looks
# like a project root), then git top-level of the target path's dir, then git
# top-level of cwd.
_gate_plausible_root() {
  [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }
}

resolve_root() {
  local target="$1" root="" dir
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _gate_plausible_root "$CLAUDE_PROJECT_DIR"; then
    root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
  fi
  if [ -z "$root" ] && [ -n "$target" ]; then
    dir="$target"
    [ -d "$dir" ] || dir="$(dirname "$dir")"
    root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  if [ -z "$root" ]; then
    root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  printf '%s' "$root"
}
