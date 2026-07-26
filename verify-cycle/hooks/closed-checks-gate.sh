#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit): enforces contract §16's cite-and-skip
# sha-equality rule on writes reaching verify's own record file
# docs/reports/records/<subject>/verify.md.
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

# Current code sha under review. Computed here (not in python) so a git failure
# is visible as empty and the python layer fails closed on it.
current_sha=""
if [ -n "$root" ]; then
  current_sha="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
fi

VG_PAYLOAD="$payload" VG_ROOT="$root" VG_SHA="$current_sha" python3 <<'PY'
import json, os, posixpath, re, sys

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
if not re.match(r'^docs/reports/records/([^/]+)/verify\.md$', rel):
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

current_sha = os.environ.get("VG_SHA", "").strip()
if not current_sha:
    deny("record %s declares closed_checks with cited code_sha value(s), but the code sha "
         "currently under review could not be determined (git rev-parse HEAD failed at the "
         "project root). §16 cannot be verified, so the write is refused (fail-closed)." % rel)

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
