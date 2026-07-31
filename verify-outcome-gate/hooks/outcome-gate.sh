#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
case "${VERIFY_OUTCOME_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): enforces that every
# `outcome:` field written into docs/issue-<n>/reports/verify.md is one of the
# three adopted values (reproduced | not-reproduced | blocked:
# needs-repro-access), and that every outcome occurrence has an accompanying
# `evidence:` field, per verify/skills/finding-record/SKILL.md.
#
# Self-contained sibling to verify's closed-checks-gate.sh: root resolution
# and content reconstruction are reimplemented inline here rather than
# sourced, so this plugin has no cross-plugin dependency.
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, an unresolvable
# project root, or a record write whose resulting content cannot be
# reconstructed all DENY.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "verify-outcome-gate: refused — outcome-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
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

# --- inline root resolution, mirroring verify/hooks/_gate-common.sh's resolve_root ---
_plausible_root() {
  [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }
}
_resolve_root() {
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
root="$(_resolve_root "$_target")"

_grc=0
VG_PAYLOAD="$payload" VG_ROOT="$root" python3 <<'PY' || _grc=$?
import json, os, posixpath, re, sys

def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-outcome-gate: refused — fail-closed: internal error: %s\n" % (_v,))
    os._exit(2)
sys.excepthook = _fail_closed

def deny(m):
    sys.stderr.write("verify-outcome-gate: refused — " + m + "\n"); sys.exit(2)
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
    deny("could not resolve the project root; refusing to judge this write blind (fail-closed).")

n = path.replace("\\", "/")
a = posixpath.normpath(n if posixpath.isabs(n) else posixpath.join(root, n))
try:
    resolved = posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
except OSError:
    resolved = a
rel = resolved[len(root):].lstrip("/") if resolved == root or resolved.startswith(root + "/") else n
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
    deny("this write targets %s but the gate could not reconstruct the resulting content; an "
         "outcome/evidence check cannot be performed, so it is refused (fail-closed)." % rel)

ALLOWED = ("reproduced", "not-reproduced", "blocked: needs-repro-access")

outcome_re = re.compile(r'^[ \t]*outcome[ \t]*:[ \t]*(.+?)[ \t]*$', re.M)
evidence_re = re.compile(r'^[ \t]*evidence[ \t]*:', re.M)

outcomes = list(outcome_re.finditer(new_text))
if not outcomes:
    allow()

# Heuristic for pairing an outcome occurrence with its attempt block's
# evidence: since we cannot reliably segment attempt blocks structurally
# (records may use `---` delimiters or plain headings), treat the window
# from immediately after this outcome match to the start of the NEXT
# `outcome:` occurrence (or end of file if none) as that attempt's
# remainder, and additionally allow evidence appearing anywhere earlier in
# the same paragraph-ish block (up to the previous blank-line-preceded
# field boundary). In practice: search both directions within a bounded
# span so an evidence field written just before or just after outcome in
# the same block is found, without bleeding into a neighboring attempt's
# evidence.
for idx, m in enumerate(outcomes):
    val = m.group(1).rstrip()
    if val not in ALLOWED:
        deny("attempt block declares outcome: '%s', which is not one of the three adopted "
             "values (reproduced | not-reproduced | blocked: needs-repro-access)." % val)

    block_start = outcomes[idx - 1].end() if idx > 0 else 0
    block_end = outcomes[idx + 1].start() if idx + 1 < len(outcomes) else len(new_text)
    block_text = new_text[block_start:block_end]
    if not evidence_re.search(block_text):
        deny("attempt with outcome: '%s' has no evidence: field; every outcome requires an "
             "evidence pointer." % val)

allow()
PY

if [ "$_grc" -ne 0 ] && [ "$_grc" -ne 2 ]; then
  echo "verify-outcome-gate: refused — fail-closed: internal error (gate judge exited $_grc)." >&2
  exit 2
fi
exit "$_grc"
