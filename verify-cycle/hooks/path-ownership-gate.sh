#!/usr/bin/env bash
# --- fail-closed trap: FIRST executable statement, before any set/source. Any
# abort with a code that is neither 0 (allow) nor 2 (deny) is forced to 2 (DENY),
# since Claude Code PreToolUse treats non-2 exits as non-blocking (fail-OPEN).
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit): enforces contract §11 per-role path
# ownership for verify. Generalizes scope-gate.sh's write-set shape to §11's
# static, role-permanent owned-path table: verify owns exactly its own
# docs/reports/records/<subject>/verify.md slot. A write reaching another
# role's docs/reports/records/<subject>/<role>.md slot is refused, citing §11,
# rather than overwriting or merging into another role's record.
#
# Peer sibling to state-gate.sh; never edits it.
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, missing python3 all
# DENY. A write whose target is not inside the records tree is not this gate's
# business and passes through.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=/dev/null
. "$HERE/_gate-common.sh"

command -v python3 >/dev/null 2>&1 || {
  echo "verify-cycle: refused — path-ownership-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
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

root="$(resolve_root "$_target")"

_grc=0
VG_PAYLOAD="$payload" VG_ROOT="$root" python3 <<'PY' || _grc=$?
import json, os, posixpath, re, sys

OWN_ROLE_FILE = "verify.md"

# FAIL-CLOSED (python layer): any uncaught internal error (e.g. a ValueError
# from os.path.realpath on a null-byte or undecodable path) becomes a DENY
# (exit 2), never an uncaught exit 1 (which Claude Code treats as fail-open).
# SystemExit is not routed here, so the allow(0)/deny(2) verdict paths below are
# preserved exactly.
def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-cycle: refused — fail-closed: internal error: %s\n" % (_v,))
    os._exit(2)
sys.excepthook = _fail_closed

def deny(m):
    sys.stderr.write("verify-cycle: refused — " + m + "\n"); sys.exit(2)
def allow():
    sys.exit(0)

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
a = n if posixpath.isabs(n) else (posixpath.join(root, n) if root else n)
a = posixpath.normpath(a)
try:
    resolved = posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
except OSError:
    resolved = a

if root and (resolved == root or resolved.startswith(root + "/")):
    rel = resolved[len(root):].lstrip("/")
else:
    rel = n

m = re.match(r'^docs/reports/records/([^/]+)/([^/]+\.md)$', rel)
if not m:
    # Not a single-role record file under the records tree; §11's record-slot
    # rule does not apply here.
    allow()

subject, role_file = m.group(1), m.group(2)
if role_file != OWN_ROLE_FILE:
    deny("'%s' is owned by role '%s' per contract §11, not verify (verify owns only "
         "docs/reports/records/<subject>/%s). Report the conflict; do not overwrite or merge "
         "into another role's record." % (rel, role_file[:-3], OWN_ROLE_FILE))

allow()
PY

# FAIL-CLOSED (shell layer): map ANY terminal code that is neither 0 (allow)
# nor 2 (deny) to a deny, so a crash or 'set -e' propagating a bare non-2 code
# never leaves the guarded tool call non-blocking.
if [ "$_grc" -ne 0 ] && [ "$_grc" -ne 2 ]; then
  echo "verify-cycle: refused — fail-closed: internal error (gate judge exited $_grc)." >&2
  exit 2
fi
exit "$_grc"
