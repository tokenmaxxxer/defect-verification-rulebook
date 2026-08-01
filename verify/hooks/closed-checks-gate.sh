#!/usr/bin/env bash
# Sources core's gate-house standard (issue-72) instead of hand-rolling the
# trap/JSON-parse/path-normalize/reconstruct/deny machinery — issue-20 C4.
# Reference only, never copied (docs/handbooks/canon-scripts.md).
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "closed-checks-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit|Bash): enforces contract
# §16's cite-and-skip sha-equality rule on writes reaching verify's own
# record file docs/issue-<n>/reports/verify.md.
#
# §16: a `closed_checks:` entry may be cited (cite-and-skip) instead of
# re-derived ONLY when its `code_sha` equals the code sha currently under
# review. A check closed on a different sha does not count as closed. This
# gate reads the proposed record content, extracts every closed_checks
# code_sha, and refuses the write if any cited sha differs from the current
# code sha (named by the record's own code_under_review: field — see below).
#
# No kill switch: this gate carries none today and issue-20 does not add
# new surface where none exists (proposal C5).
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, a record write
# whose resulting content cannot be reconstructed (including a Bash-tool
# write reaching the record path, which this gate cannot inspect), or a
# closed_checks list present but naming no code_under_review: all DENY.
set -euo pipefail

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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=/dev/null
. "$HERE/_gate-common.sh"
root="$(resolve_root "$_target")"
# C6: gate_normalize_path is deliberately non-symlink-resolving (its own
# docstring); this gate's original behavior resolved symlinks in the
# checkout root, so realpath the root once here to preserve that.
if [ -n "$root" ]; then
  root="$(cd "$root" 2>/dev/null && pwd -P || printf '%s' "$root")"
fi

_grc=0
VG_PAYLOAD="$payload" VG_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY' || _grc=$?
import importlib.util, json, os, re, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

def deny(m):
    sys.stderr.write("verify-cycle: refused — " + m + "\n"); sys.exit(2)
def allow():
    sys.exit(0)

def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-cycle: refused — fail-closed: internal error: %s\n" % (_v,))
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
                     "effect on file content; a §16 closed_checks check cannot be verified for a "
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

rel = gate_lib.gate_normalize_path(root, path) if root else None
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
    deny("this write targets %s but the gate could not reconstruct the resulting content; a "
         "§16 closed_checks check cannot be verified, so it is refused (fail-closed)." % rel)

# Extract every code_sha appearing inside a closed_checks: block only — the
# block's own extent, from its `closed_checks:` line to the next top-level
# field or heading, not the whole document (issue-20 design item 4: a
# code_sha:-shaped string elsewhere, e.g. a quoted prior attempt, must not
# be mistaken for a live citation).
block_re = re.compile(r'^closed_checks\s*:\s*$', re.M)
boundary_re = re.compile(r'^(?:[A-Za-z_][A-Za-z0-9_]*\s*:|#{1,6}\s)', re.M)

cited = []
for bm in block_re.finditer(new_text):
    start = bm.end()
    end = len(new_text)
    bd = boundary_re.search(new_text, start)
    if bd:
        end = bd.start()
    block = new_text[start:end]
    cited.extend(re.findall(r'^\s*-?\s*code_sha\s*:\s*([0-9A-Za-z]+)\s*$', block, re.M))

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

if [ "$_grc" -ne 0 ] && [ "$_grc" -ne 2 ]; then
  echo "verify-cycle: refused — fail-closed: internal error (gate judge exited $_grc)." >&2
  exit 2
fi
exit "$_grc"
