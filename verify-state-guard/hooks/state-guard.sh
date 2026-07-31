#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT

case "${VERIFY_STATE_GUARD_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): enforces the fixed
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
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, an unresolvable
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

# Root resolution, mirrored from verify/hooks/_gate-common.sh's
# resolve_root(): prefer a plausible CLAUDE_PROJECT_DIR, else git top-level
# of the target's directory, else git top-level of cwd. Unresolvable -> deny
# (this is the gate; fail-closed).
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
if [ -z "$root" ]; then
  echo "verify-state-guard: refused — could not resolve the project root; denying rather than guessing." >&2
  exit 2
fi

_grc=0
VG_PAYLOAD="$payload" VG_ROOT="$root" python3 <<'PY' || _grc=$?
import json, os, posixpath, re, sys

def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-state-guard: refused — fail-closed: internal error: %s\n" % (_v,))
    os._exit(2)
sys.excepthook = _fail_closed

def deny(m):
    sys.stderr.write("verify-state-guard: refused — " + m + "\n"); sys.exit(2)
def allow():
    sys.exit(0)

RANKS = {"idle": 0, "reproducing": 1, "reproduced": 2, "cleared": 3}
LOOP_STATE_RE = re.compile(r'^\s*loop_state\s*:\s*([A-Za-z]+)\s*$', re.M)
ISSUE_RE = re.compile(r'^docs/issue-([0-9]+)/reports/verify\.md$')

raw = os.environ.get("VG_PAYLOAD", "")
try:
    event = json.loads(raw) if raw else {}
except ValueError:
    deny("the tool-call payload is not valid JSON; the gate cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object.")
tool = event.get("tool_name")
ti = event.get("tool_input")
if not isinstance(ti, dict):
    deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    allow()
path = ti.get("file_path") or ti.get("notebook_path")
if not isinstance(path, str) or not path:
    allow()

root = os.environ.get("VG_ROOT", "")
n = path.replace("\\", "/")
a = posixpath.normpath(n if posixpath.isabs(n) else (posixpath.join(root, n) if root else n))
try:
    resolved = posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
except OSError:
    resolved = a
rel = resolved[len(root):].lstrip("/") if root and (resolved == root or resolved.startswith(root + "/")) else n
m = ISSUE_RE.match(rel)
if not m:
    allow()
issue_n = m.group(1)

# Reconstruct resulting content (same approach as
# verify/hooks/closed-checks-gate.sh's python block).
current = None
if os.path.isfile(resolved):
    try:
        with open(resolved, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        current = None
new_text = None
if tool == "Write":
    c = ti.get("content")
    if isinstance(c, str):
        new_text = c
elif tool == "Edit":
    o, nn = ti.get("old_string"), ti.get("new_string")
    if isinstance(o, str) and isinstance(nn, str) and current is not None and o in current:
        new_text = current.replace(o, nn, 1)
elif tool == "MultiEdit":
    edits = ti.get("edits"); t = current
    if isinstance(edits, list) and t is not None:
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False; break
            o, nn = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(nn, str) or o not in t:
                ok = False; break
            t = t.replace(o, nn, 1)
        if ok:
            new_text = t
elif tool == "NotebookEdit":
    nc = ti.get("new_source")
    if isinstance(nc, str):
        new_text = nc

if new_text is None:
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
