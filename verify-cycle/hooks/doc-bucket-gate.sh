#!/usr/bin/env bash
# --- fail-closed trap: FIRST executable statement, before any set/source. Any
# abort with a code that is neither 0 (allow) nor 2 (deny) is forced to 2 (DENY),
# since Claude Code PreToolUse treats non-2 exits as non-blocking (fail-OPEN).
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit): enforces contract §21's bucket-
# membership half — refuses any write landing under docs/ outside the six
# doctrine buckets. Replicates coding's doctrine/placement-gate.sh in shape,
# as verify's own sibling gate. Never edits state-gate.sh.
#
# Buckets: decisions/ handbooks/ reports/ specs/ proposals/ _assets/. Only
# docs/README.md may sit at the top of docs/. Outside docs/ the gate is silent.
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, a missing path, or
# a missing python3 all DENY (exit 2), never `|| exit 0`.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "verify-cycle: refused — doc-bucket-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

_grc=0
VG_PAYLOAD="$payload" python3 <<'PY' || _grc=$?
import json, os, posixpath, sys

BUCKETS = ("decisions", "handbooks", "reports", "specs", "proposals", "_assets")

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
    deny("no usable file_path/notebook_path in tool_input; the gate cannot judge a write it cannot identify.")

root = (os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).replace("\\", "/")
root = posixpath.normpath(root)
n = path.replace("\\", "/")
absu = posixpath.normpath(n if posixpath.isabs(n) else posixpath.join(root, n))

# Outside the project entirely -> not this gate's business.
if absu != root and not absu.startswith(root + "/"):
    allow()
# Resolve symlinks: where the bytes land is what §21 governs.
try:
    resolved = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
    real_root = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
except OSError:
    deny("the target path could not be resolved; refusing rather than guessing.")
if absu != resolved:
    if resolved != real_root and not resolved.startswith(real_root + "/"):
        allow()
    absu, root = resolved, real_root

rel = absu[len(root) + 1:] if absu != root else ""
segments = [s for s in rel.split("/") if s not in ("", ".")]
if not segments:
    allow()
directories, name = segments[:-1], segments[-1]

if "docs" not in directories:
    allow()
if directories[-1] == "docs" and name == "README.md":
    allow()

# First directory after the docs/ segment must be a recognized bucket.
try:
    di = directories.index("docs")
except ValueError:
    allow()
if di + 1 > len(directories) - 1 and False:
    pass
sub = directories[di + 1] if di + 1 < len(directories) else None
if sub is None:
    # file directly under docs/ that isn't README.md
    deny("'%s' is under docs/ but not in one of the six buckets. The buckets are: %s. Only "
         "docs/README.md may sit at the top of docs/." % (rel, ", ".join(b + "/" for b in BUCKETS)))
if sub in BUCKETS:
    allow()
deny("'%s' is under docs/ but not in one of the six buckets (it starts docs/%s/...). The "
     "buckets are: %s." % (rel, sub, ", ".join(b + "/" for b in BUCKETS)))
PY

# FAIL-CLOSED (shell layer): map ANY terminal code that is neither 0 (allow)
# nor 2 (deny) to a deny, so a crash or 'set -e' propagating a bare non-2 code
# never leaves the guarded tool call non-blocking.
if [ "$_grc" -ne 0 ] && [ "$_grc" -ne 2 ]; then
  echo "verify-cycle: refused — fail-closed: internal error (gate judge exited $_grc)." >&2
  exit 2
fi
exit "$_grc"
