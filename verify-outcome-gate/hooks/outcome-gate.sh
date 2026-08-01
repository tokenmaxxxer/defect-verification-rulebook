#!/usr/bin/env bash
# Sources core's gate-house standard (issue-72) instead of hand-rolling the
# trap/kill-switch/JSON-parse/path-normalize/reconstruct machinery —
# issue-20 C4 (compliance-check.sh confirms this file independently trips
# the same kill-switch and reconstruction-violation rules as the two gates
# the phase-1 survey named; the survey's claim that this gate carries no
# kill switch was wrong — it has one, with the same pre-issue-72 fail-open
# idiom). Reference only, never copied (docs/handbooks/canon-scripts.md).
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "outcome-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed

gate_kill_switch_active "${VERIFY_OUTCOME_GATE_OFF:-}" || { trap - EXIT; exit 0; }

# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit|Bash): enforces that every
# `outcome:` field written into docs/issue-<n>/reports/verify.md is one of the
# three adopted values (reproduced | not-reproduced | blocked:
# needs-repro-access), and that every outcome occurrence has an accompanying
# `evidence:` field, per verify/skills/finding-record/SKILL.md.
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
    sys.stderr.write("verify-outcome-gate: refused — " + m + "\n"); sys.exit(2)
def allow():
    sys.exit(0)

def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-outcome-gate: refused — fail-closed: internal error: %s\n" % (_v,))
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
                     "effect on file content; an outcome/evidence check cannot be verified for a "
                     "Bash-tool write to this path, so it is refused (fail-closed)." % rel)
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
    deny("could not resolve the project root; refusing to judge this write blind (fail-closed).")

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
    deny("this write targets %s but the gate could not reconstruct the resulting content; an "
         "outcome/evidence check cannot be performed, so it is refused (fail-closed)." % rel)

ALLOWED = ("reproduced", "not-reproduced", "blocked: needs-repro-access")

outcome_re = re.compile(r'^[ \t]*outcome[ \t]*:[ \t]*(.+?)[ \t]*$', re.M)
evidence_re = re.compile(r'^[ \t]*evidence[ \t]*:', re.M)

outcomes = list(outcome_re.finditer(new_text))
if not outcomes:
    deny("record has no outcome: field; contract s20 requires minimum record content — a "
         "write that reaches this record path with no outcome: field is refused, not allowed "
         "through as an empty record.")

# Heuristic for pairing an outcome occurrence with its attempt block's
# evidence: treat the window from immediately after the previous `outcome:`
# occurrence (or start of doc) to the start of the NEXT `outcome:`
# occurrence (or end of file) as that attempt's block, so an evidence field
# written just before or just after outcome in the same block is found,
# without bleeding into a neighboring attempt's evidence.
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
