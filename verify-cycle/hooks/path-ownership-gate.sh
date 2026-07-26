#!/usr/bin/env bash
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

VG_PAYLOAD="$payload" VG_ROOT="$root" python3 <<'PY'
import json, os, posixpath, re, sys

OWN_ROLE_FILE = "verify.md"

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
