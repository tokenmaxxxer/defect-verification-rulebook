# install

Current state of `install.sh`.

One-shot user-scope installer for the `tokenmaxxxer-verify` marketplace and
this repo's plugin set. Registers only the `tokenmaxxxer-verify`
marketplace and installs only this repository's plugins — no other
repository, no other marketplace.

`GITHUB_REPO` names `tokenmaxxxer/defect-verification-rulebook` — this
repo's actual GitHub location (per `git remote -v`), matching README's
`Install` section. Before issue-26 both named the pre-rename
`tokenmaxxxer/verify-agent-rulebook`, a stale string that never matched
this repo's real remote.

`PLUGINS` array names all five plugins this repo ships (as of issue-23;
before that it named only `verify`, a 1-of-5 defect):
`verify`, `verify-finding-gate`, `verify-outcome-gate`,
`verify-state-guard`, `verify-directive-depth` — the same five, in the
same order, that README's manual `Install` section documents. The
install/update loops iterate `"${PLUGINS[@]}"` generically, so keeping this
array in sync with README's list (and with
`.claude-plugin/marketplace.json`'s `plugins` array) is a data change, not
a control-flow change, whenever a plugin is added or removed.

Two install paths: a real `claude` CLI (standalone or the binary bundled in
the VSCode extension) at `--scope user`, or a CLI-less fallback that writes
`~/.claude/settings.json` directly (`TOKENMAXXXER_SETTINGS_ONLY=1` forces
this path). The fallback resolves and prefix-checks the settings path
against the user's home directory before any write, backs up before
writing, and follows a symlink rather than replacing it.
