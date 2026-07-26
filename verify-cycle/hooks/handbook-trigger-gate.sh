#!/usr/bin/env bash
# --- fail-closed trap: FIRST executable statement, before any set/source. Any
# abort with a code that is neither 0 (allow) nor 2 (deny) is forced to 2 (DENY),
# since Claude Code PreToolUse treats non-2 exits as non-blocking (fail-OPEN).
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Bash matching 'git commit'): enforces contract §21's
# handbook-trigger half. When a commit's changed-file set introduces or changes
# an operational surface (env/config/dependency/migration/run-setup-deploy) but
# does not also touch a docs/handbooks/<component>.md, the commit is refused.
#
# It needs the whole staged changed-file set at once, so it fires at commit
# time, not on a single Write. Peer sibling to state-gate.sh; never edits it.
#
# Operational-surface path heuristics (verify's declared list): dependency
# manifests (package.json, pyproject.toml, requirements*.txt, go.mod, Cargo.toml,
# Gemfile), container/build (Dockerfile, docker-compose*), env examples
# (*.env, *.env.example, .env*), migration dirs (**/migrations/**), CI/deploy
# workflows (.github/workflows/**, deploy/**), and run/setup scripts
# (install.sh, setup.sh, run.sh, Makefile).
#
# FAIL-CLOSED: unparseable JSON, non-dict event/tool_input, or a commit whose
# staged file set cannot be read (git failure) all DENY (exit 2). A Bash call
# that is not a git commit passes through.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=/dev/null
. "$HERE/_gate-common.sh"

command -v python3 >/dev/null 2>&1 || {
  echo "verify-cycle: refused — handbook-trigger-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

command_str="$(printf '%s' "$payload" | python3 -c '
import json,sys
try:
    e=json.loads(sys.stdin.read())
except Exception:
    print("__MALFORMED__"); sys.exit(0)
if not isinstance(e,dict):
    print("__MALFORMED__"); sys.exit(0)
if e.get("tool_name")!="Bash":
    sys.exit(0)
ti=e.get("tool_input")
if not isinstance(ti,dict):
    print("__MALFORMED__"); sys.exit(0)
c=ti.get("command")
print(c if isinstance(c,str) else "")
' 2>/dev/null || printf '__MALFORMED__')"

if [ "$command_str" = "__MALFORMED__" ]; then
  echo "verify-cycle: refused — handbook-trigger-gate.sh could not parse the tool-call payload; denying rather than guessing." >&2
  exit 2
fi
# Not a Bash tool call, or not a git commit -> not this gate's business.
case "$command_str" in
  *"git commit"*|*"git"*" commit"*) : ;;
  *) exit 0 ;;
esac

root="$(resolve_root "")"
if [ -z "$root" ]; then
  echo "verify-cycle: refused — handbook-trigger-gate.sh could not determine the project root for this commit; denying rather than guessing." >&2
  exit 2
fi

# Staged changed-file set.
if ! staged="$(git -C "$root" diff --cached --name-only 2>/dev/null)"; then
  echo "verify-cycle: refused — could not read the staged file set (git diff --cached failed) for this commit; denying rather than guessing." >&2
  exit 2
fi

_grc=0
VG_STAGED="$staged" python3 <<'PY' || _grc=$?
import os, re, sys, posixpath

# FAIL-CLOSED (python layer): any uncaught internal error becomes a DENY
# (exit 2), never an uncaught exit 1 (which Claude Code treats as fail-open).
# SystemExit is not routed here, so the deny(2) / pass(0) verdict paths below
# are preserved exactly.
def _fail_closed(_t, _v, _tb):
    sys.stderr.write("verify-cycle: refused — fail-closed: internal error: %s\n" % (_v,))
    os._exit(2)
sys.excepthook = _fail_closed

def deny(m):
    sys.stderr.write("verify-cycle: refused — " + m + "\n"); sys.exit(2)

files = [f for f in os.environ.get("VG_STAGED", "").splitlines() if f.strip()]
if not files:
    # Nothing staged -> nothing to enforce here.
    sys.exit(0)

def is_op_surface(p):
    base = posixpath.basename(p)
    if base in ("package.json", "pyproject.toml", "go.mod", "Cargo.toml",
                "Gemfile", "Dockerfile", "Makefile", "install.sh", "setup.sh", "run.sh"):
        return base
    if re.match(r'requirements.*\.txt$', base):
        return base
    if base.startswith("docker-compose"):
        return base
    if base.endswith(".env") or base.endswith(".env.example") or base.startswith(".env"):
        return base
    parts = p.split("/")
    if "migrations" in parts:
        return "migration (%s)" % p
    if p.startswith(".github/workflows/") or p.startswith("deploy/"):
        return "ci/deploy (%s)" % p
    return None

triggers = [(f, is_op_surface(f)) for f in files]
triggers = [(f, k) for (f, k) in triggers if k]
if not triggers:
    sys.exit(0)

touches_handbook = any(f.startswith("docs/handbooks/") for f in files)
if touches_handbook:
    sys.exit(0)

f, k = triggers[0]
deny("this commit changes %s (operational surface: %s) but does not touch any "
     "docs/handbooks/<component>.md. Per contract §21, update the component's handbook in the "
     "same unit of work." % (f, k))
PY

# FAIL-CLOSED (shell layer): map ANY terminal code that is neither 0 (pass) nor
# 2 (deny) to a deny, so a crash or 'set -e' propagating a bare non-2 code never
# leaves the guarded commit non-blocking.
if [ "$_grc" -ne 0 ] && [ "$_grc" -ne 2 ]; then
  echo "verify-cycle: refused — fail-closed: internal error (gate judge exited $_grc)." >&2
  exit 2
fi
exit "$_grc"
