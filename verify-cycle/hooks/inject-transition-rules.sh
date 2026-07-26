#!/usr/bin/env bash
# UserPromptSubmit hook for the `verify` role.
#
# Reads transition-rules.md (the single source of truth for legal
# verify-record.md status transitions, also read by state-gate.sh) and the
# current state out of verify-record.md, and emits a compact block naming
# the current state and the legal transitions out of it.
#
# THE CRITICAL RULE: this hook must NEVER exit with no output. If the rules
# file or the state file cannot be loaded/parsed, it still emits a block —
# one that says plainly the rules could not be loaded, why, and that no
# transition may be made until that is fixed. A silent exit here is exactly
# the class of defect docs/reports/2026-07-26-hunt-conversational-state-machine.md
# (in review-agent-rulebook) reproduces and this hook exists to prevent.
#
# Never blocks the prompt: always exits 0, whatever happens above.
#
# Kill switch: export VERIFY_CYCLE_DISABLE=1
set -uo pipefail

case "${VERIFY_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

STATE_FILE_NAME="${VERIFY_RECORD_NAME:-verify-record.md}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
RULES_FILE="${VERIFY_TRANSITION_RULES:-$HOOK_DIR/transition-rules.md}"

payload="$(cat 2>/dev/null || true)"

fail_block() {
  # $1: reason line(s)
  cat <<EOF
<verify-transition-rules status="error">
Transition rules could not be loaded — no transition may be made until this
is fixed.

Reason: $1
</verify-transition-rules>
EOF
  exit 0
}

command -v python3 >/dev/null 2>&1 || fail_block "python3 is not available, so transition-rules.md and $STATE_FILE_NAME cannot be parsed."

# Root is discovered by walking UP from the hook's own on-disk location to
# the nearest enclosing `.git`, never from the process cwd or
# CLAUDE_PROJECT_DIR — this must resolve to the same state file that
# state-gate.sh guards, regardless of invoking cwd.
root=""
dir="$HOOK_DIR"
while :; do
  if [ -e "$dir/.git" ]; then
    root="$dir"
    break
  fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done
[ -n "$root" ] || fail_block "no enclosing .git found by walking up from this hook's own directory ($HOOK_DIR)."

[ -f "$RULES_FILE" ] || fail_block "transition-rules.md not found at $RULES_FILE."
[ -r "$RULES_FILE" ] || fail_block "transition-rules.md at $RULES_FILE is not readable."

state_path="$root/$STATE_FILE_NAME"

out="$(VERIFY_RULES_FILE="$RULES_FILE" VERIFY_STATE_PATH="$state_path" VERIFY_STATE_NAME="$STATE_FILE_NAME" python3 <<'PY'
import os
import re
import sys

rules_file = os.environ["VERIFY_RULES_FILE"]
state_path = os.environ["VERIFY_STATE_PATH"]
state_name = os.environ["VERIFY_STATE_NAME"]

def fail(reason):
    print("FAIL\t" + reason)
    sys.exit(0)

try:
    with open(rules_file, encoding="utf-8-sig") as fh:
        rules_text = fh.read(1 << 20)
except OSError as e:
    fail("transition-rules.md at %s could not be read (%s)." % (rules_file, e))

if not rules_text.strip():
    fail("transition-rules.md at %s is empty." % rules_file)

rows = []
for line in rules_text.splitlines():
    line = line.strip()
    if not line.startswith("|") and "|" not in line:
        continue
    if not line or line.startswith("#"):
        continue
    # accept both "a | b | c | d" and pipe-table "| a | b | c | d |" styles
    parts = [p.strip() for p in line.strip("|").split("|")]
    if len(parts) != 4:
        continue
    if parts[0].lower() == "from" and parts[1].lower() == "to":
        continue  # header row
    if set(parts[0]) <= {"-"} or set(parts[1]) <= {"-"}:
        continue  # markdown header separator row
    rows.append(tuple(parts))

if not rows:
    fail("transition-rules.md at %s has no parseable rows." % rules_file)

NONE_STATE = "(none)"

known_states = set()
for r in rows:
    if r[0] != NONE_STATE:
        known_states.add(r[0])
    if r[1] != NONE_STATE:
        known_states.add(r[1])

if not os.path.exists(state_path):
    # Missing state file is a normal state, not an error: per the
    # bootstrap convention the current state is the synthetic literal
    # "(none)". Do not emit the "could not be loaded" failure block for
    # this case.
    status = NONE_STATE
else:
    try:
        with open(state_path, encoding="utf-8-sig") as fh:
            state_text = fh.read(1 << 20)
    except OSError as e:
        fail("state file %s could not be read (%s)." % (state_path, e))

    m = re.findall(r"^status:\s*(.*?)\s*(?:#.*)?$", state_text, re.M)
    if not m:
        fail("state file %s has no `status:` field." % state_path)
    if len(m) > 1:
        fail("state file %s has a duplicated `status:` field." % state_path)
    status = m[0].strip("\r\n \t")
    if not status:
        fail("state file %s has an empty `status:` field." % state_path)
    if status not in known_states:
        # A value of "(none)" (the gate's own bootstrap sentinel), or any
        # other string outside this role's known-state set, read from an
        # EXISTING state file is a broken input — never rendered as the
        # current state to inject a prompt about. This matches
        # state-gate.sh's refusal so the injector and the gate never
        # disagree on the same file.
        fail("state file %s has `status: %s`, which is not a member of this role's known-state set." % (state_path, status))

matching = [r for r in rows if r[0] == status]

lines = []
lines.append("OK")
lines.append("current state: %s" % status)
if matching:
    lines.append("legal transitions from %s:" % status)
    for frm, to, actor, precond in matching:
        lines.append("  - %s -> %s | actor: %s | precondition: %s" % (frm, to, actor, precond))
else:
    lines.append("no legal transitions listed from %s in transition-rules.md." % status)
print("\n".join(lines))
PY
)"
rc=$?

status_line="$(printf '%s\n' "$out" | head -n1)"

if [ "$rc" -ne 0 ] || [ "${status_line%%$'\t'*}" = "FAIL" ]; then
  reason="${status_line#FAIL$'\t'}"
  [ -n "$reason" ] || reason="transition-rules.md or $STATE_FILE_NAME could not be parsed."
  fail_block "$reason"
fi

body="$(printf '%s\n' "$out" | tail -n +2)"

cat <<EOF
<verify-transition-rules status="ok">
$body

A row with actor "user" requires that the user has said something in this
conversation naming that transition; the model must record, as one line
appended to $STATE_FILE_NAME, the user utterance it read as the basis for
any transition it makes.
</verify-transition-rules>
EOF
exit 0
