#!/usr/bin/env bash
# Sources core's gate-house standard (issue-72) instead of hand-rolling the
# trap/kill-switch/JSON-parse/path-normalize/reconstruct machinery —
# issue-20 C4. Reference only, never copied (docs/handbooks/canon-scripts.md).
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed

gate_kill_switch_active "${VERIFY_FINDING_GATE_OFF:-}" || { trap - EXIT; exit 0; }

# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit|Bash): enforces that any
# write to docs/issue-<n>/reports/verify.md which claims `outcome: reproduced`
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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=/dev/null
. "$HERE/../../verify/hooks/_gate-common.sh"
root="$(resolve_root "$_target")"
# C6: gate_normalize_path is deliberately non-symlink-resolving (its own
# docstring); this gate's original behavior resolved symlinks in the
# checkout root, so realpath the root once here to preserve that.
if [ -n "$root" ]; then
  root="$(cd "$root" 2>/dev/null && pwd -P || printf '%s' "$root")"
fi

_grc=0
VG_PAYLOAD="$payload" VG_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY' || _grc=$?
import importlib.util, os, re, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

def deny(m):
    sys.stderr.write("verify-finding-gate: refused — " + m + "\n"); sys.exit(2)
def allow():
    sys.exit(0)

def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-finding-gate: refused — fail-closed: internal error: %s\n" % (_v,))
    os._exit(2)
sys.excepthook = _fail_closed

raw = os.environ.get("VG_PAYLOAD", "")
event = gate_lib.gate_parse_json_or_deny(raw, deny)
tool = event.get("tool_name")
root = os.environ.get("VG_ROOT", "")

REC_PATTERN = re.compile(r'^docs/issue-[0-9]+/reports/verify\.md$')

if tool == "Bash":
    ti = event.get("tool_input")
    command = ti.get("command") if isinstance(ti, dict) else None
    if isinstance(command, str) and root:
        for tok in gate_lib.gate_bash_write_targets(command):
            rel = gate_lib.gate_normalize_path(root, tok)
            if rel is not None and REC_PATTERN.match(rel):
                deny("a Bash command reaches %s, but this gate cannot inspect a shell command's "
                     "effect on file content; whether a reproduced attempt carries its paired "
                     "finding fields cannot be verified for a Bash-tool write, so it is refused "
                     "(fail-closed)." % rel)
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
if rel is None or not REC_PATTERN.match(rel):
    allow()

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
    deny("this write targets %s but the gate could not reconstruct the resulting content; whether "
         "a reproduced attempt carries its paired finding fields cannot be verified, so it is "
         "refused (fail-closed)." % rel)

# Find every `outcome: reproduced` occurrence. If none, this gate has nothing
# to check yet — allow immediately.
outcome_re = re.compile(r'^\s*outcome\s*:\s*reproduced\s*$', re.M)
outcomes = list(outcome_re.finditer(new_text))
if not outcomes:
    allow()

# Per-occurrence pairing: each `outcome: reproduced` is bound on BOTH sides
# by the nearest section boundary (a heading line, or another `outcome:`
# line) — issue-20 C3/design item 3. The docstring this window implements
# already promised "a small lookback to the previous heading" for fields
# written before the outcome line (verdict:/addressed_to:/severity: placed
# ahead of a trailing outcome note, or interleaved via MultiEdit); the prior
# implementation only computed the forward half. section_bounds now records
# every heading/outcome boundary so both the start and end of each attempt's
# window can be resolved from the same list.
section_bounds = [m.start() for m in re.finditer(r'^\s*(#{1,6}\s|outcome\s*:)', new_text, re.M)]

def window_for(idx):
    at = outcomes[idx].start()
    # start: nearest boundary at-or-before this outcome that is not this
    # outcome's own line itself (i.e. the previous heading/outcome, or the
    # previous outcome: reproduced's own end so consecutive attempts do not
    # bleed into each other), else start of doc.
    start = 0
    for b in section_bounds:
        if b < at:
            start = b
        else:
            break
    if idx > 0:
        start = max(start, outcomes[idx - 1].end())
    # end: next section boundary strictly after this outcome, else end of doc.
    end = len(new_text)
    for b in section_bounds:
        if b > at:
            end = b
            break
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
