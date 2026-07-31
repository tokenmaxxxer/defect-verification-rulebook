#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT

case "${VERIFY_FINDING_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): enforces that any write
# to docs/issue-<n>/reports/verify.md which claims `outcome: reproduced`
# also carries a paired `finding` block naming verdict:, addressed_to:
# coding, and severity: (blocking|advisory) — per the finding-record and
# severity-classification skills. Correctness of verdict/severity values is
# out of scope (presence + shape only, per proposal C6).
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, an indeterminate
# project root, or an unreconstructable resulting content all DENY.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "verify-finding-gate: refused — finding-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
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

# Inline root resolution, mirrors verify/hooks/_gate-common.sh's resolve_root.
_plausible_root() {
  [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }
}
resolve_root() {
  local target="$1" root="" dir
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible_root "$CLAUDE_PROJECT_DIR"; then
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

_grc=0
VG_PAYLOAD="$payload" VG_ROOT="$root" python3 <<'PY' || _grc=$?
import json, os, posixpath, re, sys

def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-finding-gate: refused — fail-closed: internal error: %s\n" % (_v,))
    os._exit(2)
sys.excepthook = _fail_closed

def deny(m):
    sys.stderr.write("verify-finding-gate: refused — " + m + "\n"); sys.exit(2)
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
if not root:
    deny("could not resolve a project root for this write; refusing rather than guessing whether "
         "it targets a verify.md record.")

n = path.replace("\\", "/")
a = posixpath.normpath(n if posixpath.isabs(n) else posixpath.join(root, n))
try:
    resolved = posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
except OSError:
    resolved = a
rel = resolved[len(root):].lstrip("/") if root and (resolved == root or resolved.startswith(root + "/")) else n
if not re.match(r'^docs/issue-[0-9]+/reports/verify\.md$', rel):
    allow()

# Reconstruct resulting content (same approach as closed-checks-gate.sh).
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
    deny("this write targets %s but the gate could not reconstruct the resulting content; whether "
         "a reproduced attempt carries its paired finding fields cannot be verified, so it is "
         "refused (fail-closed)." % rel)

# Find every `outcome: reproduced` occurrence. If none, this gate has nothing
# to check yet — allow immediately.
outcome_re = re.compile(r'^\s*outcome\s*:\s*reproduced\s*$', re.M)
outcomes = list(outcome_re.finditer(new_text))
if not outcomes:
    allow()

# Per-occurrence pairing heuristic: for each `outcome: reproduced` match, look
# for the nearest surrounding "attempt" section — bounded by the previous and
# next top-level attempt/heading marker (a line starting with '#' or
# '- attempt' or 'attempt:') — and search that window for the finding
# fields. This keeps multiple reproduced attempts' fields from being
# conflated with each other while not requiring a rigid schema. As a
# reasonable window we search from the outcome match to the next
# `outcome:` or `# ` heading (or end of doc), plus a small lookback to the
# previous heading, since `finding:` blocks in the finding-record skill are
# written adjacent to (immediately after) the `outcome:` line of the same
# attempt.
section_bounds = [m.start() for m in re.finditer(r'^\s*(#{1,6}\s|outcome\s*:)', new_text, re.M)]

def window_for(idx):
    start = outcomes[idx].start()
    # end = next section boundary strictly after start, else end of doc
    end = len(new_text)
    for b in section_bounds:
        if b > start:
            end = b
            break
    # also cap at the next outcome: reproduced occurrence, if any
    if idx + 1 < len(outcomes):
        end = min(end, outcomes[idx + 1].start())
    return new_text[start:end]

problems = []
for i in range(len(outcomes)):
    win = window_for(i)
    missing = []

    mverdict = re.search(r'^\s*verdict\s*:\s*(\S+)\s*$', win, re.M)
    valid_verdicts = {"Present", "Surface", "Absent", "Incorrect", "Unverifiable"}
    if not mverdict or mverdict.group(1) not in valid_verdicts:
        missing.append("finding block for a reproduced attempt is missing verdict: (or has an "
                        "invalid value); required values: Present|Surface|Absent|Incorrect|Unverifiable.")

    maddr = re.search(r'^\s*addressed_to\s*:\s*(\S+)\s*$', win, re.M)
    if not maddr or maddr.group(1) != "coding":
        missing.append("finding block for a reproduced attempt does not declare addressed_to: coding.")

    msev = re.search(r'^\s*severity\s*:\s*(\S+)\s*$', win, re.M)
    if not msev or msev.group(1) not in ("blocking", "advisory"):
        missing.append("finding block for a reproduced attempt is missing severity: blocking|advisory "
                        "(or has an invalid value).")

    if missing:
        problems.extend(missing)

if problems:
    # Collect-all-missing, deny-once: report every distinct problem in one message.
    seen = []
    for p in problems:
        if p not in seen:
            seen.append(p)
    deny(" ".join(seen))

allow()
PY

if [ "$_grc" -ne 0 ] && [ "$_grc" -ne 2 ]; then
  echo "verify-finding-gate: refused — fail-closed: internal error (gate judge exited $_grc)." >&2
  exit 2
fi
exit "$_grc"
