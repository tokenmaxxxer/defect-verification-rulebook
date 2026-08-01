# issue-23 scout brief

Scout-skip does not fully apply: seven of the eight defects are bounded by
explicit core precedent and this repo's own already-migrated gates
(`closed-checks-gate.sh`, `finding-gate.sh`, `outcome-gate.sh`,
`directive.sh`), so their fix shape is copy-the-pattern, not open design.
But two points had a genuine open question at survey time — the exact
restructuring of the window/clamp logic (§3) and where the `Bash` matcher
belongs (§6) — so one lightweight sweep was done: grep this repo's own
prior `docs/*/proposals/` for prior art, per the task's scout-decision
instruction, rather than inventing a new design from scratch. No external
web research was performed.

## Sweep performed

`grep`/read across `docs/issue-20/proposals/gate-a-plus-remediation.md`,
`docs/issue-17/proposals/`, `docs/issue-11/proposals/` for state-guard,
gate-lib adoption, and matcher-registration precedent.

## Findings

1. **gate-lib migration shape (§2)**: issue-20's proposal design item 1
   gives the exact call-site pattern already used by
   `closed-checks-gate.sh`/`finding-gate.sh`/`outcome-gate.sh`:
   `gate_trap_fail_closed`, `gate_kill_switch_active`,
   `gate_parse_json_or_deny`, `gate_normalize_path` (called against a
   realpath'd `root`, per issue-20's C6 — `gate_normalize_path` is
   deliberately non-symlink-resolving, so callers realpath `root` once at
   startup, not the library), and `gate_reconstruct_write` for
   Edit/MultiEdit/NotebookEdit reconstruction with `replace_all` honored.
   `state-guard.sh`'s migration is the same pattern a fourth time — no new
   design needed, confirmed by reading the already-migrated files directly
   in this survey (not merely by citing the old proposal).

2. **`resolve_root` de-duplication (§2)**: `verify/hooks/_gate-common.sh`
   already exists and is already sourced by `closed-checks-gate.sh`
   (`. "$HERE/_gate-common.sh"`) but lives inside the `verify/` plugin
   directory. `state-guard.sh` lives in the sibling `verify-state-guard/`
   plugin — plugins in this repo are self-contained
   (`.claude-plugin/plugin.json`, own `hooks/`, own `tests/`) per the
   README's own description, so `verify-state-guard/` cannot assume
   `verify/hooks/_gate-common.sh` is present at install time (a user may
   install `verify-state-guard` without `verify`, per the marketplace
   listing them as five independent installable plugins). No prior-art
   proposal addresses cross-plugin helper sharing. Decision made here
   (documented, not left open): `verify-state-guard/hooks/state-guard.sh`
   should call `gate_normalize_path`/realpath-root inline per gate-lib's
   own pattern (same as the other three migrated gates each do
   independently) rather than reach across a plugin boundary to source
   `verify/hooks/_gate-common.sh` — this avoids inventing a new
   cross-plugin dependency the marketplace's install model does not
   support, and matches what the three already-migrated gates do (none of
   them source a helper from a *different* plugin either).

3. **Window/clamp restructuring (§3)**: no prior-art proposal covers
   `loop_state` ordering logic specifically (issue-20's proposal scope was
   `verify/`, not `verify-state-guard/`). The fix is determined by the
   state-guard's own already-stated contract, not by precedent: extend the
   existing `if new_state in ("reproduced", "cleared") and highest_rank <
   RANKS["reproducing"]` check into a general `RANKS[new_state] <
   highest_rank` regression check for every recognized `new_state`, so
   `reproducing` is clamped the same way `reproduced`/`cleared` already
   are, closing the false-allow in §3 without inventing new state values or
   changing the four-state model.

4. **Bash matcher registration (§6)**: no prior-art proposal touches
   `hooks.json` matcher strings (issue-20's remediation was gate-internal
   logic, not dispatch wiring). The fix is mechanical given §6's own
   evidence: `closed-checks-gate.sh` already fully implements and tests a
   `Bash` branch; the only missing piece is adding `Bash` to
   `verify/hooks/hooks.json`'s `PreToolUse` matcher string
   (`"Write|Edit|MultiEdit|NotebookEdit|Bash"`) so the dispatch that
   Claude Code's harness performs actually reaches the branch the code and
   tests already assume is reachable. `verify-state-guard/hooks/hooks.json`
   should gain the same matcher addition once `state-guard.sh` itself
   grows a `Bash` branch (via gate-lib migration, §2) — otherwise adding
   the matcher alone would route `Bash` calls into a script with no `Bash`
   handling, which would fall through to `allow()` for tool not in
   `("Write","Edit","MultiEdit","NotebookEdit")` today, silently no-op-ing
   instead of gating. `verify-finding-gate`/`verify-outcome-gate` are out
   of scope for this matcher change — neither gate's own code contains a
   `Bash` branch, and the issue's requirement #2 is "advertised and tested
   branches must be reachable," not "add Bash coverage everywhere."
