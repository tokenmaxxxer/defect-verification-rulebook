#!/usr/bin/env bash
# Sources core's gate-house standard (issue-72) instead of hand-rolling the
# trap/kill-switch/JSON-parse/path-normalize/reconstruct machinery —
# issue-23 D2. Inlined directly (not via verify/hooks/_gate-common.sh) per
# issue-23 C3: verify-state-guard installs independently of verify/, so it
# must not source across the plugin boundary. Reference only, never copied
# (docs/handbooks/canon-scripts.md).
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "state-guard.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed

gate_kill_switch_active "${VERIFY_STATE_GUARD_OFF:-}" || { trap - EXIT; exit 0; }

# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit|Bash): enforces the fixed
# idle < reproducing < reproduced < cleared order on writes reaching
# docs/issue-<n>/reports/verify.md's loop_state: field, and refuses a
# `cleared` write that still shows an unresolved `severity: blocking`
# finding.
#
# Trust boundary: this gate reads ONLY the on-disk state file
# .claude/verify-state-issue-<n>.json (written by verify-state.sh's
# PostToolUse hook). It never reads the current on-disk record content as a
# substitute for the state file — that would couple this gate's correctness
# to verify-state.sh's freshness and defeat the point of keeping the two
# failure-independent.
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, an indeterminate
# project root, or a record write whose resulting content cannot be
# reconstructed all DENY.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "verify-state-guard: refused — state-guard.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try:
    e=json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    p=ti.get("file_path") or ti.get("notebook_path")
    if isinstance(p,str) and p: print(p)
' 2>/dev/null || true)"

# Root resolution, inlined (C3 — no cross-plugin source):
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

root="$(resolve_root "$_target")"
# gate_normalize_path is deliberately non-symlink-resolving (its own
# docstring); this gate's original behavior resolved symlinks in the
# checkout root, so realpath the root once here to preserve that.
if [ -n "$root" ]; then
  root="$(cd "$root" 2>/dev/null && pwd -P || printf '%s' "$root")"
fi

_grc=0
VG_PAYLOAD="$payload" VG_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY' || _grc=$?
import importlib.util, json, os, re, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

def deny(m):
    sys.stderr.write("verify-state-guard: refused — " + m + "\n"); sys.exit(2)
def allow():
    sys.exit(0)

def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-state-guard: refused — fail-closed: internal error: %s\n" % (_v,))
    os._exit(2)
sys.excepthook = _fail_closed

RANKS = {"idle": 0, "reproducing": 1, "reproduced": 2, "cleared": 3}
LOOP_STATE_RE = re.compile(r'^\s*loop_state\s*:\s*([A-Za-z]+)\s*$', re.M)
ISSUE_RE = re.compile(r'^docs/issue-([0-9]+)/reports/verify\.md$')

raw = os.environ.get("VG_PAYLOAD", "")
event = gate_lib.gate_parse_json_or_deny(raw, deny)
tool = event.get("tool_name")
root = os.environ.get("VG_ROOT", "")

if tool == "Bash":
    ti = event.get("tool_input")
    command = ti.get("command") if isinstance(ti, dict) else None
    if isinstance(command, str) and root:
        for tok in gate_lib.gate_bash_write_targets(command):
            rel = gate_lib.gate_normalize_path(root, tok)
            if rel is not None and ISSUE_RE.match(rel):
                deny("a Bash command reaches %s, but this gate cannot inspect a shell command's "
                     "effect on file content; the loop_state order cannot be verified for a "
                     "Bash-tool write to this path, so it is refused (fail-closed)." % rel)
    allow()

ti = event.get("tool_input")
if not isinstance(ti, dict):
    deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    allow()
path = ti.get("file_path") or ti.get("notebook_path")
if not isinstance(path, str) or not path:
    allow()

if not root:
    deny("could not resolve a project root for this write; refusing rather than guessing whether "
         "it targets a verify.md record.")

rel = gate_lib.gate_normalize_path(root, path)
if rel is None or not ISSUE_RE.match(rel):
    allow()
issue_n = ISSUE_RE.match(rel).group(1)

resolved = os.path.join(root, rel) if rel else root
current = None
if os.path.isfile(resolved):
    try:
        with open(resolved, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        current = None

new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
if not ok:
    deny("this write targets docs/issue-%s/reports/verify.md but the gate could not reconstruct "
         "the resulting content; the loop_state order cannot be verified, so it is refused "
         "(fail-closed)." % issue_n)

matches = LOOP_STATE_RE.findall(new_text)
new_state = matches[-1].lower() if matches else None
if new_state is None or new_state not in RANKS:
    allow()

# Trust boundary: read ONLY the state file, never the current on-disk record.
state_file = os.path.join(root, ".claude", "verify-state-issue-%s.json" % issue_n)
highest = None
try:
    with open(state_file, encoding="utf-8-sig") as fh:
        data = json.load(fh)
    v = data.get("highest_state") if isinstance(data, dict) else None
    if v in RANKS:
        highest = v
except (OSError, ValueError):
    highest = None
highest_rank = RANKS[highest] if highest is not None else -1

# issue-23 D3: general forward-only/monotonic regression check applied to
# EVERY recognized new_state, not just reproduced/cleared (the prior
# window/clamp only checked those two target states, leaving a `reproducing`
# re-write from a `cleared` record an unclamped false-allow).
if RANKS[new_state] < highest_rank:
    deny("record for issue-%s is declaring loop_state: %s but a higher loop_state (%s) was "
         "already recorded; loop_state may not regress from a previously recorded state." %
         (issue_n, new_state, highest))

if new_state in ("reproduced", "cleared") and highest_rank < RANKS["reproducing"]:
    deny("record for issue-%s is declaring loop_state: %s but this issue has no recorded prior "
         "loop_state: reproducing write — a defect can't be reproduced without first being "
         "attempted; skip-ahead refused." % (issue_n, new_state))

if new_state == "cleared":
    # Heuristic: a `severity: blocking` occurrence counts as resolved only if
    # one of `resolved:`, `resolution:`, or `status: resolved` appears
    # somewhere AFTER it in the text. This is a simple ordering heuristic, not
    # a structured parse of the findings list — it can be fooled by a
    # resolution marker that belongs to an unrelated finding earlier in the
    # document, but it fails closed in the common case (no marker at all
    # after a blocking severity line denies).
    blocking_positions = [mm.start() for mm in re.finditer(r'severity\s*:\s*blocking', new_text)]
    resolution_positions = [mm.start() for mm in re.finditer(r'(resolved\s*:|resolution\s*:|status\s*:\s*resolved)', new_text)]
    unresolved = False
    for bp in blocking_positions:
        if not any(rp > bp for rp in resolution_positions):
            unresolved = True
            break
    if unresolved:
        deny("record for issue-%s is declaring loop_state: cleared but still shows an unresolved "
             "severity: blocking finding; cleared requires no unresolved blocking finding, or the "
             "human's explicit waiver." % issue_n)

allow()
PY

if [ "$_grc" -ne 0 ] && [ "$_grc" -ne 2 ]; then
  echo "verify-state-guard: refused — fail-closed: internal error (gate judge exited $_grc)." >&2
  exit 2
fi
exit "$_grc"
