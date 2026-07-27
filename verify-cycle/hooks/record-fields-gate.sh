#!/usr/bin/env bash
# --- fail-closed trap: FIRST executable statement, before any set/source. Any
# abort with a code that is neither 0 (allow) nor 2 (deny) is forced to 2 (DENY),
# since Claude Code PreToolUse treats non-2 exits as non-blocking (fail-OPEN).
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit): enforces contract §20's per-role
# record minimum content on writes reaching verify's own record file
# docs/reports/records/<subject>/verify.md.
#
# Peer to state-gate.sh: state-gate validates the loop_state TRANSITION; this
# gate validates the §20 CONTENT of the same proposed record. It never edits
# state-gate.sh; it is a sibling PreToolUse entry.
#
# Required always: a "what was done" section, a "why" section, the concrete
# upstream basis (a commit sha or a records/ path), and the record's own
# loop_state. Additionally, when loop_state is non-terminal (verify's terminal
# state is `cleared`), a next-steps section and an open-finding resolution-path
# section.
#
# Fires ONLY on a write whose resolved target is a verify.md under
# docs/reports/records/<subject>/. Anything else passes through untouched.
#
# FAIL-CLOSED on every malformed/missing-input branch: unparseable JSON, non-
# dict event/tool_input, a target that IS the record path but whose resulting
# content cannot be reconstructed, or a missing python3 — all DENY (exit 2),
# never `|| exit 0`.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=/dev/null
. "$HERE/_gate-common.sh"

command -v python3 >/dev/null 2>&1 || {
  echo "verify-cycle: refused — record-fields-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
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

# Only Write-family tools are in scope for a §20 content check.
if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    allow()

path = ti.get("file_path") or ti.get("notebook_path")
if not isinstance(path, str) or not path:
    allow()

root = os.environ.get("VG_ROOT", "")
def resolve(p):
    n = p.replace("\\", "/")
    a = n if posixpath.isabs(n) else (posixpath.join(root, n) if root else n)
    a = posixpath.normpath(a)
    try:
        return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
    except OSError:
        return a

resolved = resolve(path)
rel = None
if root and (resolved == root or resolved.startswith(root + "/")):
    rel = resolved[len(root):].lstrip("/")
else:
    rel = path.replace("\\", "/")

# Both spellings of verify's own record. The v2 board path is
# docs/reports/records/<subject>/verify.md, but this repo's other gates —
# state-gate.sh, trailer-gate.sh — and its SKILL still work against the flat
# verify-record.md at the repo root. Matching only the board path meant this
# gate never fired on the file verify actually writes, so contract section 20's
# content requirements went unenforced entirely (measured 2026-07-27). review
# matches both spellings for exactly this reason.
state_name = os.environ.get("VERIFY_STATE_NAME") or "verify-record.md"
is_own_record = bool(re.match(r'^docs/reports/records/[^/]+/verify\.md$', rel)) \
    or posixpath.basename(rel) == state_name
if not is_own_record:
    # Not verify's own record file -> not this gate's business.
    allow()

# Reconstruct the resulting record text.
abs_path = resolved
current = None
if os.path.isfile(abs_path):
    try:
        with open(abs_path, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        current = None

new_text = None
if tool == "Write":
    c = ti.get("content")
    if isinstance(c, str):
        new_text = c
elif tool == "Edit":
    o, n = ti.get("old_string"), ti.get("new_string")
    if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
        new_text = current.replace(o, n, 1)
elif tool == "MultiEdit":
    edits = ti.get("edits")
    t = current
    if isinstance(edits, list) and t is not None:
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False; break
            o, n = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(n, str) or o not in t:
                ok = False; break
            t = t.replace(o, n, 1)
        if ok:
            new_text = t

if new_text is None:
    deny("this write targets %s but the gate could not reconstruct the resulting record "
         "content from the tool input; §20 content cannot be verified, so it is refused "
         "(fail-closed). Use Write with full content, or an Edit whose old_string is present."
         % rel)

low = new_text.lower()

# loop_state / status field must be present and readable.
sm = re.search(r'^\s*(?:loop_state|status)\s*:\s*([^\r\n#]+?)\s*$', new_text, re.M | re.I)
if not sm:
    deny("record %s has no `loop_state:` (or `status:`) field; §20 requires the record's own "
         "current loop_state be stated. Refused." % rel)
loop_state = sm.group(1).strip().lower()

missing = []
if "what was done" not in low and "## what" not in low:
    missing.append("what was done")
if "## why" not in low and re.search(r'(^|\n)\s*why\b', low) is None:
    missing.append("why")
# Concrete basis: an upstream label, a records/ path, or a >=7-hex sha.
has_basis = ("upstream" in low or "records/" in low
             or re.search(r'\b[0-9a-f]{7,40}\b', low) is not None)
if not has_basis:
    missing.append("concrete upstream basis (commit sha or records/ path)")

TERMINAL = {"cleared"}
if loop_state not in TERMINAL:
    if "next-step" not in low and "next steps" not in low and "next_steps" not in low:
        missing.append("next-steps backlog (required while loop_state is non-terminal)")
    if "resolution path" not in low and "resolution-path" not in low and "resolution_path" not in low:
        missing.append("open-finding resolution path (required while loop_state is non-terminal)")

if missing:
    deny("record %s is missing required §20 section(s): %s. Every role record must state what "
         "was done, why (when a real choice was made), and the concrete upstream basis; open "
         "work additionally requires next-steps and an open-finding resolution path."
         % (rel, ", ".join(missing)))

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
