#!/usr/bin/env bash
# Passive state writer for verify-state-guard.
#
# Two duties, both best-effort and non-blocking:
#
#   PostToolUse (Write|Edit|MultiEdit|NotebookEdit): after a write to
#   docs/issue-<n>/reports/verify.md has already landed on disk, read its
#   loop_state: field and, if its rank (idle=0 < reproducing=1 <
#   reproduced=2 < cleared=3) is higher than the currently recorded
#   .claude/verify-state-issue-<n>.json highest_state (or no state file
#   exists yet), overwrite the state file with the new highest rank
#   reached. The recorded highest state is NEVER lowered — this is how
#   "reproducing was reached at some point" survives the record later
#   moving on to reproduced/cleared.
#
#   SessionStart: for any docs/issue-*/reports/verify.md whose state file is
#   missing, bootstrap the state file from the record's CURRENT loop_state
#   (best-effort recovery; a fresh session cannot know intermediate states
#   that already happened, only where the record stands right now).
#
# This is NOT a gate. It never denies a tool call. Any internal problem
# (missing python3, unresolvable root, unparseable payload) is silently
# swallowed with exit 0 — a passive state writer must never block or crash
# the session it is trying to help.
#
# Kill switch: export VERIFY_STATE_GUARD_OFF=1

# Inline equivalent of core's gate_kill_switch_active (issue-72): an
# unrecognized value stays ACTIVE (the fixed default); only a recognized
# on-spelling disables. Cannot source core's gate-lib.sh here — issue-23 C3
# forbids cross-plugin sourcing for verify-state-guard.
vs_off_lc="$(printf '%s' "${VERIFY_STATE_GUARD_OFF:-}" | tr '[:upper:]' '[:lower:]')"
case "$vs_off_lc" in
  1|true|yes|on) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"

vs_errfile="$(mktemp 2>/dev/null || echo /tmp/verify-state.$$.err)"
VS_PAYLOAD="$payload" VS_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}" VS_CWD="${PWD:-}" python3 <<'PY' 2>"$vs_errfile"
import json, os, posixpath, re, sys

RANKS = {"idle": 0, "reproducing": 1, "reproduced": 2, "cleared": 3}
LOOP_STATE_RE = re.compile(r'^\s*loop_state\s*:\s*([A-Za-z]+)\s*$', re.M)
ISSUE_RE = re.compile(r'^docs/issue-([0-9]+)/reports/verify\.md$')


def plausible_root(d):
    if not d or not os.path.isdir(d):
        return False
    return os.path.exists(os.path.join(d, ".git")) or os.path.isfile(
        os.path.join(d, "docs", "specs", "role-handoff-contract.md")
    )


def resolve_root(target):
    import subprocess
    pd = os.environ.get("VS_PROJECT_DIR", "")
    if plausible_root(pd):
        try:
            return os.path.realpath(pd)
        except OSError:
            pass
    for cand_dir in ([os.path.dirname(target)] if target else []) + [os.environ.get("VS_CWD", "") or "."]:
        try:
            out = subprocess.run(
                ["git", "-C", cand_dir, "rev-parse", "--show-toplevel"],
                capture_output=True, text=True, timeout=5,
            )
        except (OSError, ValueError):
            continue
        if out.returncode == 0:
            top = out.stdout.strip()
            if top:
                return top
    return ""


def state_path(root, n):
    return os.path.join(root, ".claude", "verify-state-issue-%s.json" % n)


def read_highest(path):
    try:
        with open(path, encoding="utf-8-sig") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return None
    v = data.get("highest_state") if isinstance(data, dict) else None
    return v if v in RANKS else None


def write_highest(path, value):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump({"highest_state": value}, fh)
            fh.write("\n")
        os.replace(tmp, path)
    except OSError:
        pass


def extract_loop_state(text):
    matches = LOOP_STATE_RE.findall(text)
    return matches[-1] if matches else None


def bump(root, n, new_state):
    if new_state not in RANKS:
        return
    p = state_path(root, n)
    cur = read_highest(p)
    if cur is None or RANKS[new_state] > RANKS[cur]:
        write_highest(p, new_state)


def do_posttooluse(event, root):
    ti = event.get("tool_input")
    if not isinstance(ti, dict):
        return
    path = ti.get("file_path") or ti.get("notebook_path")
    if not isinstance(path, str) or not path:
        return
    n = path.replace("\\", "/")
    a = posixpath.normpath(n if posixpath.isabs(n) else (posixpath.join(root, n) if root else n))
    try:
        resolved = posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
    except OSError:
        resolved = a
    rel = resolved[len(root):].lstrip("/") if root and (resolved == root or resolved.startswith(root + "/")) else n
    m = ISSUE_RE.match(rel)
    if not m:
        return
    issue_n = m.group(1)
    if not os.path.isfile(resolved):
        return
    try:
        with open(resolved, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError:
        return
    ls = extract_loop_state(text)
    if ls is None:
        return
    bump(root, issue_n, ls.lower())


def do_sessionstart(event, root):
    docs_dir = os.path.join(root, "docs")
    if not os.path.isdir(docs_dir):
        return
    for name in sorted(os.listdir(docs_dir)):
        m = re.match(r'^issue-([0-9]+)$', name)
        if not m:
            continue
        issue_n = m.group(1)
        rec = os.path.join(docs_dir, name, "reports", "verify.md")
        if not os.path.isfile(rec):
            continue
        p = state_path(root, issue_n)
        if os.path.isfile(p):
            continue
        try:
            with open(rec, encoding="utf-8-sig") as fh:
                text = fh.read(1 << 20)
        except OSError:
            continue
        ls = extract_loop_state(text)
        if ls is None:
            continue
        ls = ls.lower()
        if ls in RANKS:
            write_highest(p, ls)


raw = os.environ.get("VS_PAYLOAD", "")
try:
    event = json.loads(raw) if raw else {}
except ValueError:
    sys.exit(0)
if not isinstance(event, dict):
    sys.exit(0)

hook_event = event.get("hook_event_name") or event.get("hook_event") or ""
ti = event.get("tool_input")

root_hint = ""
if isinstance(ti, dict):
    ph = ti.get("file_path") or ti.get("notebook_path")
    if isinstance(ph, str):
        root_hint = ph
root = resolve_root(root_hint)
if not root:
    sys.exit(0)

if hook_event == "SessionStart" or not isinstance(ti, dict):
    do_sessionstart(event, root)
else:
    do_posttooluse(event, root)
PY
vs_rc=$?
if [ "$vs_rc" -ne 0 ]; then
  echo "verify-state: internal error, state not updated: $(tail -c 500 "$vs_errfile" 2>/dev/null)" >&2
fi
rm -f "$vs_errfile"

exit 0
