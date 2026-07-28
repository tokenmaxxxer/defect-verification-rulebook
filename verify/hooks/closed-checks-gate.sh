#!/usr/bin/env bash
# --- fail-closed trap: FIRST executable statement, before any set/source. Any
# abort with a code that is neither 0 (allow) nor 2 (deny) is forced to 2 (DENY),
# since Claude Code PreToolUse treats non-2 exits as non-blocking (fail-OPEN).
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit): enforces contract §16's cite-and-skip
# sha-equality rule on writes reaching verify's own record file
# docs/issue-<n>/reports/verify.md.
#
# §16: a `closed_checks:` entry may be cited (cite-and-skip) instead of
# re-derived ONLY when its `code_sha` equals the code sha currently under
# review. A check closed on a different sha does not count as closed. This gate
# reads the proposed record content, extracts every closed_checks code_sha, and
# refuses the write if any cited sha differs from the current code sha
# (`git rev-parse HEAD` at the project root).
#
# Peer sibling to state-gate.sh; never edits it. Reads the same proposed
# content state-gate.sh already reads (a second field check).
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, a record write
# whose resulting content cannot be reconstructed, a closed_checks list present
# but the current HEAD sha unobtainable, or a missing python3/git all DENY.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=/dev/null
. "$HERE/_gate-common.sh"

command -v python3 >/dev/null 2>&1 || {
  echo "verify-cycle: refused — closed-checks-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
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

# v3: the working checkout is the role's docs branch, so HEAD is never the
# code under review. The record itself must name it (code_under_review:).
current_sha=""

_grc=0
VG_PAYLOAD="$payload" VG_ROOT="$root" VG_SHA="$current_sha" python3 <<'PY' || _grc=$?
import json, os, posixpath, re, sys

# FAIL-CLOSED (python layer): any uncaught internal error (e.g. a ValueError
# from os.path.realpath on a null-byte or undecodable path) must become a DENY
# (exit 2), never an uncaught exit 1 (which Claude Code treats as non-blocking =
# fail-open). SystemExit is not routed here, so the deliberate allow(0)/deny(2)
# verdict paths below are preserved exactly.
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
a = posixpath.normpath(n if posixpath.isabs(n) else (posixpath.join(root, n) if root else n))
try:
    resolved = posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
except OSError:
    resolved = a
rel = resolved[len(root):].lstrip("/") if root and (resolved == root or resolved.startswith(root + "/")) else n
if not re.match(r'^docs/issue-[0-9]+/reports/verify\.md$', rel):
    allow()

# Reconstruct resulting content.
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

if new_text is None:
    deny("this write targets %s but the gate could not reconstruct the resulting content; a "
         "§16 closed_checks check cannot be verified, so it is refused (fail-closed)." % rel)

# Extract every code_sha appearing under closed_checks. Heuristic: any
# `code_sha: <value>` line. If none, there is nothing to cite-and-skip.
cited = re.findall(r'^\s*-?\s*code_sha\s*:\s*([0-9A-Za-z]+)\s*$', new_text, re.M)
if not cited:
    allow()

mcur = re.findall(r"^\s*(?:code_under_review|upstream_code_sha)\s*:\s*([0-9A-Za-z]+)\s*$", new_text, re.M)
current_sha = mcur[0].strip() if mcur else ""
if not current_sha:
    deny("record %s declares closed_checks with cited code_sha value(s), but names no "
         "code_under_review: field. Under per-role issue branches the working HEAD is a docs "
         "commit, never the code under review, so the record must name the sha explicitly. "
         "s16 cannot be verified; refused (fail-closed)." % rel)

def eq(a, b):
    a, b = a.lower(), b.lower()
    m = min(len(a), len(b))
    return m >= 7 and a[:m] == b[:m]

bad = [s for s in cited if not eq(s, current_sha)]
if bad:
    deny("closed_checks entry cites code_sha %s, but the code currently under review is at %s. "
         "A check closed on a different sha does not count as closed per contract §16 — "
         "re-derive it instead of citing." % (bad[0], current_sha))

allow()
PY

# FAIL-CLOSED (shell layer): the judge above is the allow/deny authority. Map
# ANY terminal code that is neither 0 (allow) nor 2 (deny) to a deny — a crash
# that aborted python (or 'set -e' propagating a bare non-2 code) must never
# leave the guarded tool call non-blocking.
if [ "$_grc" -ne 0 ] && [ "$_grc" -ne 2 ]; then
  echo "verify-cycle: refused — fail-closed: internal error (gate judge exited $_grc)." >&2
  exit 2
fi
exit "$_grc"
