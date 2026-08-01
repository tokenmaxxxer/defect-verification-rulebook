#!/usr/bin/env bash
# One-shot installer for the tokenmaxxxer verify-agent-rulebook stack.
# Registers ONLY the tokenmaxxxer-verify marketplace and installs ONLY this
# repository's plugins (verify) plus its bundle (verify).
# Names no other repository and no other marketplace.
#
# Installs for your account only (user scope). Uses a real `claude` CLI
# (standalone, or the binary bundled inside the VSCode extension) at
# --scope user, or falls back to writing ~/.claude/settings.json directly.
# Applies on every machine-local session but does NOT travel with any repo.
set -euo pipefail

MARKET="tokenmaxxxer-verify"
BUNDLE="verify"
GITHUB_REPO="tokenmaxxxer/verify-agent-rulebook"
PLUGINS=(verify verify-finding-gate verify-outcome-gate verify-state-guard verify-directive-depth)

usage() {
  cat <<'USAGE'
Usage: install.sh

  Installs the tokenmaxxxer-verify stack for your account only. Applies to
  every machine-local session but does not travel with any repo, and does
  not reach Claude Code on the web / Slack cloud sessions.
  -h, --help  Show this help.

Environment:
  TOKENMAXXXER_SETTINGS_ONLY=1      Skip the CLI and write settings directly.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

MARKET_SOURCE="$GITHUB_REPO"
SETTINGS_SOURCE_JSON="{\"source\": \"github\", \"repo\": \"$GITHUB_REPO\"}"

# Merge extraKnownMarketplaces + enabledPlugins into a settings.json at $1,
# preserving any existing content. Used for the CLI-less fallback.
#
# Safety, in order:
#   - resolve the settings path and prefix-check it against the user's home
#     directory BEFORE any write;
#   - on parse failure of existing settings, abort leaving the original
#     file untouched;
#   - back up before writing;
#   - follow a symlink rather than replacing it.
write_settings() {
  python3 - "$MARKET" "$BUNDLE" "$SETTINGS_SOURCE_JSON" "$1" "${PLUGINS[@]}" <<'PY'
import json, os, shutil, sys

market, bundle, source_json, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
plugins = sys.argv[5:]
key = f"{bundle}@{market}"

home = os.path.realpath(os.path.expanduser("~"))
requested = os.path.expanduser(path)
requested_abs = os.path.abspath(requested)
# Resolve and prefix-check against the user's home directory BEFORE any
# write. A parent that does not exist yet cannot be realpath'd meaningfully,
# so check the nearest existing ancestor's resolved path instead of the
# leaf — the same containment guarantee, without requiring the file to
# already exist.
check = requested_abs
while not os.path.exists(check):
    parent = os.path.dirname(check)
    if parent == check:
        break
    check = parent
resolved_check = os.path.realpath(check)
if resolved_check != home and not resolved_check.startswith(home + os.sep):
    sys.exit(f"ERROR: refusing to write outside the home directory ({requested_abs} resolves under {resolved_check}).")

path = requested_abs
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
# A dotfiles setup often symlinks this file. os.replace() below would swap the
# link for a regular file and quietly detach the user's real settings, so write
# through to whatever it points at.
if os.path.islink(path):
    path = os.path.realpath(path)
    print(f"    settings.json is a symlink; writing through to {path}")

settings = {}
if os.path.exists(path):
    with open(path) as f:
        try:
            settings = json.load(f)
        except ValueError:
            sys.exit(f"ERROR: {path} is not valid JSON — fix it and re-run. Nothing was written.")
    shutil.copy2(path, path + ".bak")
    print(f"    backup written to {path}.bak")

settings.setdefault("extraKnownMarketplaces", {})[market] = {
    "source": json.loads(source_json)
}

# enabledPlugins is a record ({"plugin@market": true}), not an array.
enabled = settings.get("enabledPlugins")
if isinstance(enabled, list):
    enabled = {k: True for k in enabled}
elif not isinstance(enabled, dict):
    enabled = {}
for plugin in plugins:
    enabled[f"{plugin}@{market}"] = True
enabled[key] = True
settings["enabledPlugins"] = enabled

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print(f"    updated {path}")
PY
}

find_cli() {
  if command -v claude >/dev/null 2>&1; then
    command -v claude
    return
  fi
  # The VSCode extension bundles a full CLI; pick the newest version.
  ls -1d "$HOME"/.vscode-server/extensions/anthropic.claude-code-*/resources/native-binary/claude \
         "$HOME"/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude \
         2>/dev/null | sort -V | tail -1
}

CLI=""
[ -z "${TOKENMAXXXER_SETTINGS_ONLY:-}" ] && CLI="$(find_cli)" || true

if [ -n "$CLI" ] && [ -x "$CLI" ]; then
  echo "==> installing via CLI: $CLI"
  # Run the CLI from a scratch dir, never the invoking repo. `claude plugin
  # marketplace add` keys its write scope on the current directory; a
  # neutral cwd keeps every write at user scope.
  cd "$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}")" 2>/dev/null || cd / || true
  if "$CLI" plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
    echo "    marketplace '$MARKET' already registered"
  else
    "$CLI" plugin marketplace add "$MARKET_SOURCE"
  fi
  "$CLI" plugin marketplace update "$MARKET" >/dev/null 2>&1 || true

  install_failed=""
  for plugin in "${PLUGINS[@]}"; do
    "$CLI" plugin install "$plugin@$MARKET" --scope user || install_failed="$install_failed $plugin"
  done
  "$CLI" plugin install "$BUNDLE@$MARKET" --scope user || install_failed="$install_failed $BUNDLE"

  for plugin in "${PLUGINS[@]}"; do
    "$CLI" plugin update "$plugin@$MARKET" || true
  done
  "$CLI" plugin update "$BUNDLE@$MARKET" || true

  if [ -n "$install_failed" ]; then
    echo "==> FAILED to install:$install_failed"
    echo "    The rest of the stack is installed. Re-run this script — it is idempotent —"
    echo "    or install the failures individually with: $CLI plugin install <name>@$MARKET --scope user"
  else
    echo "==> installed $BUNDLE@$MARKET and verify."
  fi
else
  echo "==> no claude CLI found (standalone or bundled): writing user settings directly"
  if ! write_settings "$HOME/.claude/settings.json"; then
    echo "==> FAILED to write ~/.claude/settings.json (see the error above); nothing was installed." >&2
    exit 1
  fi
  echo "    the bundle and its dependency install on next session start"
fi

cat <<'MSG'
==> done (user scope). Start (or reload) a Claude Code session, then:
    - verify with /plugins
    - RECOMMENDED: open /plugin -> marketplaces -> tokenmaxxxer-verify and enable
      auto-update. There is no CLI/config switch for this toggle; it is a
      one-time interactive step.
    - without auto-update, refresh manually anytime:
      claude plugin update verify@tokenmaxxxer-verify
MSG
