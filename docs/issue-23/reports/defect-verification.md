# issue-23 gate A+ final remediation — phase-2 delivery record

## What was done

Delivered the approved proposal
(`docs/issue-23/proposals/gate-a-plus-final-remediation.md`) in full:
migrated `state-guard.sh` onto core's `gate-lib.sh`/`gate-lib.py` (D2),
generalized the window/clamp regression check to every recognized
`new_state` (D3), fixed `install.sh`'s plugin array to the real five-plugin
set (D4), swept README/manifest for stray old-name/ghost-file references
(D5, none found), added `Bash` to `verify`'s and `verify-state-guard`'s
`hooks.json` matchers now that both gates have `Bash` handling (D6), and
re-synced the pinned core fixtures against the real installed core plugin
plus added a missing-core mandatory test case to all five suites (D1),
closing with a `compliance-check.sh` run against the real installed core
recorded below (D7). One item beyond the issue's named 7 defects was fixed
in the same pass: the three already-migrated gates
(`closed-checks-gate.sh`, `finding-gate.sh`, `outcome-gate.sh`) and
`verify-directive-depth/hooks/directive.sh` all sourced `gate-lib.sh`/
`role-directive.sh` with no `||` guard — core issue #75's confirmed
fail-open defect, caught by re-syncing the fixture from the real core
(whose `compliance-check.sh` now detects exactly this) and by direct
inspection before the fix. The phase-2 delivery prompt named "source 가드
적용" explicitly, so this is in scope, not an unrequested addition.

1. **state-guard gate-lib migration (D2)** — `verify-state-guard/hooks/state-guard.sh`
   now sources `${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh`
   (guarded with `||`, inline per C3 — no cross-plugin source into
   `verify/hooks/_gate-common.sh`) and calls `gate_trap_fail_closed`,
   `gate_kill_switch_active`, `gate_parse_json_or_deny`,
   `gate_normalize_path`, `gate_reconstruct_write`, and (new)
   `gate_bash_write_targets` for a `Bash`-tool-write branch matching the
   other three gates' shape. The hand-rolled trap, fail-open kill-switch
   case statement, and unconditional `.replace(..., 1)` reconstruction
   (which silently ignored `replace_all` and never reconstructed
   `NotebookEdit`) are gone. `resolve_root`/`_gate_plausible_root` remain
   inlined (C3 forbids sourcing across the plugin boundary), unchanged in
   content from before.
2. **Window/clamp generalization (D3)** — added
   `if RANKS[new_state] < highest_rank: deny(...)` ahead of the existing
   reproduced/cleared skip-ahead check, so every recognized `new_state` is
   clamped against `highest_state`, not just the two previously-checked
   target states. New case `regression-cleared-then-reproducing` (a record
   at `highest_state: cleared` re-declaring `loop_state: reproducing`) now
   denies; before this fix it was an unclamped false-allow, reproduced by
   direct code inspection in the phase-1 survey.
3. **install.sh (D4)** — `PLUGINS` array now lists all five plugins
   (`verify`, `verify-finding-gate`, `verify-outcome-gate`,
   `verify-state-guard`, `verify-directive-depth`), matching README's
   install order; the install/update loops needed no control-flow change.
4. **README/manifest sweep (D5)** — repo-wide grep for old bundle/role-name
   strings and ghost-file references across `README.md`,
   `.claude-plugin/marketplace.json`, and this repo's plugin manifests
   (one `marketplace.json` lists all five plugins; there are no separate
   per-plugin `plugin.json` files) found nothing. No rewrite made.
5. **hooks.json matcher fix (D6)** — `verify/hooks/hooks.json` and
   `verify-state-guard/hooks/hooks.json` `PreToolUse` matchers changed from
   `Write|Edit|MultiEdit|NotebookEdit` to
   `Write|Edit|MultiEdit|NotebookEdit|Bash`, sequenced after item 1 so
   `state-guard.sh` has its own `Bash` branch before the matcher can route
   a `Bash` call to it. `verify-finding-gate`/`verify-outcome-gate`
   matchers unchanged — no `Bash` branch in either gate, out of scope per
   proposal C5.
6. **Source guard fix (D1/D7-adjacent, repo-wide)** — every `. ".../gate-lib.sh"`
   and `. ".../role-directive.sh"` source line
   (`verify/hooks/closed-checks-gate.sh`,
   `verify-finding-gate/hooks/finding-gate.sh`,
   `verify-outcome-gate/hooks/outcome-gate.sh`,
   `verify-state-guard/hooks/state-guard.sh`,
   `verify-directive-depth/hooks/directive.sh`) now carries the `||` guard
   core issue #75 requires (`|| { echo "...: cannot source ..." >&2; exit 2; }`).
7. **Fixture re-sync + missing-core tests (D1)** —
   `tests/fixtures/core/hooks/lib/{gate-lib.sh,gate-lib.py,role-directive.sh}`
   and `tests/fixtures/core-compliance-check.sh` re-synced from the
   actually-installed core plugin
   (`~/.claude/plugins/marketplaces/tokenmaxxxer/runs/rulebooks/tokenmaxxxer-core/core`),
   confirming C1's assumption directly: the installed core already carries
   issue #75's `||`-guard pattern and `gate_bash_write_targets`. A new
   missing-core case was added to all five test suites — unset
   `CLAUDE_PLUGIN_ROOT_CORE` with no fallback `core/` directory present at
   this checkout's root (there genuinely is none) — asserting fail-closed
   rather than crash-uninformatively or silently allow. All five pass.

Full suite: `bash tests/run-gate-tests.sh` — 72 passed, 0 failed (was 56
before this delivery; verify +1, verify-outcome-gate +1, verify-finding-gate
+1, verify-state-guard +12, verify-directive-depth +1).

`compliance-check.sh` (core's real detector, not the pinned fixture) run
against every `verify*/hooks/` directory:

```
=== verify/hooks ===
compliance-check: ok — verify/hooks/closed-checks-gate.sh
=== verify-finding-gate/hooks ===
compliance-check: ok — verify-finding-gate/hooks/finding-gate.sh
=== verify-outcome-gate/hooks ===
compliance-check: ok — verify-outcome-gate/hooks/outcome-gate.sh
=== verify-state-guard/hooks ===
compliance-check: no *-gate.sh files found under verify-state-guard/hooks — nothing to check
=== verify-directive-depth/hooks ===
compliance-check: no *-gate.sh files found under verify-directive-depth/hooks — nothing to check
OVERALL rc=0
```

`state-guard.sh` does not match `compliance-check.sh`'s `*-gate.sh` glob,
so it is not structurally scanned by that detector even though it is a
gate in every functional sense and was migrated in item 1 above. This is a
naming-convention gap in the detector's glob, not a defect this issue
named or this proposal scoped to fix (the filename is referenced by
`hooks.json`, this repo's own test suite, and its own header comments —
renaming is a separate, larger-blast-radius change); recorded as an
observed gap, not silently left unmentioned.

## Why

The 2026-08-01 re-audit graded this rulebook C: 7 confirmed defects (an
8th, README's old repo name, was already stale from issue-20's phase-2),
naming core #75 and on-the-record #182 as common preconditions. Both
preconditions are confirmed landed (core #75's `||`-guard pattern and
`gate_bash_write_targets` are present in the real installed core plugin,
directly inspected — see item 7 above; on-the-record #182 is outside this
repo's scope to verify further and was not needed for any fix here). This
delivery builds exactly what the approved proposal designed, plus the one
source-guard gap the phase-2 prompt named explicitly and
`compliance-check.sh` against the real core independently confirmed.

## Upstream basis

- Approval: issue #23 comment `APPROVE issue-23/defect-verification`
  (human approver JiwonJung94, single-account mode).
- `docs/issue-23/proposals/gate-a-plus-final-remediation.md` (approved
  design, constraints C1-C7, design items D1-D7).
- `docs/issue-23/reports/defect-verification/current-state-survey.md`
  (phase-1 reproduction of all 7 confirmed defects) and
  `docs/issue-23/reports/defect-verification/scout-brief.md`.
- Core's gate-house standard (issue #72/#75,
  `core/hooks/lib/gate-lib.sh`/`gate-lib.py`,
  `core/hooks/tests/compliance-check.sh`) — consumed by reference at the
  documented `CLAUDE_PLUGIN_ROOT_CORE`-relative path; pinned copies under
  `tests/fixtures/core/` exist only so this repo's own suite runs
  deterministically without a live core plugin install, never sourced by
  any shipped gate. Re-synced from the real installed core plugin as part
  of this delivery (item 7 above).

loop_state: landed

## Open findings

None. Nothing found during this delivery that blocks landing. The
`state-guard.sh`/`compliance-check.sh` glob-naming gap (item under
"compliance-check.sh" above) is recorded as an observation, not a finding
against this delivery — it is a pre-existing filename, unrelated to the
gate-lib migration this delivery performed, and renaming it is outside the
approved proposal's scope.

## Next steps / resolution path

N/A — `loop_state: landed` is terminal for this record; no next steps or
open-finding resolution path required.
