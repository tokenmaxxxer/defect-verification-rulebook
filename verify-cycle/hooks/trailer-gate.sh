#!/usr/bin/env bash
# PreToolUse hook (Bash matching 'git commit'): enforces contract §13's commit-
# trailer requirement for verify. When a unit is in progress for this role — the
# verify record file's loop_state is non-terminal (verify's terminal state is
# `cleared`) — a landing commit must carry verify's declared trailer identifying
# the subject and kind: a `Subject:` trailer line. A commit lacking it is
# refused.
#
# verify's declared trailer key (per contract §13, which leaves exact keys to
# each rulebook): `Subject:` (and optionally `Kind:`). This gate requires at
# minimum a `Subject:` trailer line in the commit message.
#
# Fires at commit time (needs the message). Peer sibling to state-gate.sh.
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, an in-progress unit
# whose commit message cannot be extracted, or a state file present-but-
# unreadable all DENY (exit 2). A Bash call that is not a git commit, or a
# commit with no in-progress unit (no record / terminal loop_state), passes.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=/dev/null
. "$HERE/_gate-common.sh"

command -v python3 >/dev/null 2>&1 || {
  echo "verify-cycle: refused — trailer-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

root="$(resolve_root "")"

VG_PAYLOAD="$payload" VG_ROOT="$root" python3 <<'PY'
import json, os, posixpath, re, sys

def deny(m):
    sys.stderr.write("verify-cycle: refused — " + m + "\n"); sys.exit(2)

raw = os.environ.get("VG_PAYLOAD", "")
try:
    event = json.loads(raw) if raw else {}
except ValueError:
    deny("the tool-call payload is not valid JSON; the gate cannot judge a commit it cannot parse.")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object.")
if event.get("tool_name") != "Bash":
    sys.exit(0)
ti = event.get("tool_input")
if not isinstance(ti, dict):
    deny("tool_input is missing or not a JSON object; the gate cannot judge a commit it cannot parse.")
command = ti.get("command")
if not isinstance(command, str) or not command.strip():
    sys.exit(0)
if not re.search(r'\bgit\b[^\n]*\bcommit\b', command):
    sys.exit(0)

root = os.environ.get("VG_ROOT", "")
if not root:
    deny("could not determine the project root for this commit; denying rather than guessing.")

# In-progress unit? Read verify's record loop_state. verify's role-record state
# lives at verify-record.md (repo root) in this repo's convention.
state_file = posixpath.join(root, "verify-record.md")
loop_state = None
if os.path.isfile(state_file):
    try:
        with open(state_file, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError:
        deny("verify-record.md exists but cannot be read; a §13 in-progress check cannot be made, so the commit is refused (fail-closed).")
    m = re.search(r'^\s*(?:loop_state|status)\s*:\s*([^\r\n#]+?)\s*$', text, re.M | re.I)
    if m:
        loop_state = m.group(1).strip().lower()

TERMINAL = {"cleared"}
# No record, or a terminal loop_state -> no in-progress unit -> not enforced.
if loop_state is None or loop_state in TERMINAL:
    sys.exit(0)

# There IS an in-progress unit: a §13 trailer is required. Extract the commit
# message from -m/-F. If the message cannot be extracted (e.g. -F file or an
# interactive editor commit), fail closed.
msgs = []
# -m "msg" / -m'msg' / --message=msg  (handle quoted and unquoted)
for m in re.finditer(r'(?:-m|--message)(?:=|\s+)("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|\S+)', command):
    tok = m.group(1)
    if len(tok) >= 2 and tok[0] == tok[-1] and tok[0] in "\"'":
        tok = tok[1:-1]
    msgs.append(tok)

if not msgs:
    deny("this commit lands verify work while verify-record.md loop_state is non-terminal "
         "(%s), but no inline commit message (-m/--message) could be read to check for the "
         "required trailer. Per contract §13, refusing rather than guessing." % loop_state)

joined = "\n".join(msgs)
if not re.search(r'(^|\n)\s*Subject\s*:\s*\S', joined):
    deny("this commit lands verify work while verify-record.md loop_state is non-terminal "
         "(%s) but its message carries no `Subject:` trailer identifying the record. Per "
         "contract §13, every landing commit must carry verify's declared trailer." % loop_state)

sys.exit(0)
PY
