# issue-17 defect-verification: phase-2 delivery record

## What was done

Implemented the plugin set the approved proposal
(`docs/issue-17/proposals/defect-verification-rulebook-enforcement.md`) and the
issue's "요구 정정" comment specified: each adopted methodology element as its
own independent, self-contained plugin, rather than one deepened gate inside
`verify`.

Four new top-level plugins, each with its own `.claude-plugin/plugin.json`,
`hooks/`, `hooks.json`, `README.md`, kill switch, and self-runnable test
suite:

- **`verify-directive-depth`** — `hooks/directive.sh` (SessionStart), the
  facet-structured phase-1/phase-2 directive (numbered steps, a judgment
  criterion, a "never" line for each facet), replacing the prose-only
  `USE_WHEN`/`HAND_OFF` shape. Sources core's `role-directive.sh` the same
  way the prior `verify/hooks/directive.sh` did — canon referenced, not
  copied. No gate of its own. Kill switch `VERIFY_DIRECTIVE_DEPTH_OFF`.
- **`verify-outcome-gate`** — `hooks/outcome-gate.sh` (PreToolUse), enforces
  the three-value outcome set (`reproduced` / `not-reproduced` /
  `blocked: needs-repro-access`) and an `evidence:` field per attempt on
  writes to `docs/issue-<n>/reports/verify.md`. 7/7 tests pass. Kill switch
  `VERIFY_OUTCOME_GATE_OFF`.
- **`verify-finding-gate`** — `hooks/finding-gate.sh` (PreToolUse), layered
  beside `verify-outcome-gate`: once `outcome: reproduced` appears, requires
  the paired `finding` block's `verdict:`, `addressed_to: coding`, and
  `severity: blocking|advisory`, all missing/invalid fields reported
  together. 8/8 tests pass. Kill switch `VERIFY_FINDING_GATE_OFF`.
- **`verify-state-guard`** — `hooks/verify-state.sh` (PostToolUse +
  SessionStart, passive state writer/rebuilder) and `hooks/state-guard.sh`
  (PreToolUse gate), enforcing contract row 69's
  `idle < reproducing < reproduced < cleared` order and refusing a `cleared`
  write with an unresolved `severity: blocking` finding. State file
  `.claude/verify-state-issue-<n>.json`. 9/9 tests pass. Kill switch
  `VERIFY_STATE_GUARD_OFF`.

Integration (done directly, not delegated, since it touches shared files):

- `.claude-plugin/marketplace.json` — registered all four new plugins
  alongside the existing `verify` entry; updated `verify`'s own description
  to point at the sibling plugins instead of claiming directive/field-gate
  ownership it no longer has.
- `verify/hooks/hooks.json` — removed the `SessionStart` entry pointing at
  `verify/hooks/directive.sh` (superseded by `verify-directive-depth`);
  `verify/hooks/directive.sh` deleted, its content having moved into the new
  plugin's deepened rewrite. `closed-checks-gate.sh`'s `PreToolUse` entry is
  untouched — it still enforces §16 sha-matching independently.
- `verify/.claude-plugin/plugin.json` — description updated to match.
- `tests/run-gate-tests.sh` — now also runs each new plugin's own test suite
  as a subprocess (kept genuinely independent — no shared test code between
  plugins), and exits non-zero if any suite fails.

## Why

Issue #17's "요구 정정" comment required restructuring from "deepen one gate
inside `verify`" into "four independent, `freelunch`-level-complete
plugins, one per methodology element, each in `marketplace.json`." The
phase-1 proposal already designed this exact plugin set and composition
(which plugins compose 기획서 vs. 산출물 규범); this delivery builds precisely
that design, changing nothing about scope C1-C7 from the approved proposal.

## Upstream basis

- Approval: issue #17 comment `APPROVE issue-17/defect-verification` (human
  approver, single-account mode).
- `docs/issue-17/proposals/defect-verification-rulebook-enforcement.md`
  (approved design, "Plugin set" table and "What will be done" section).
- Canon exemplars referenced (never copied): `verify/hooks/closed-checks-gate.sh`
  and `verify/hooks/_gate-common.sh` (this repo, fail-closed/root-resolution
  shape); `core/hooks/record-fields-gate.sh`,
  `core/contract/role-handoff-contract.md` row 69 (loop_state order),
  `warrant/hooks/state.sh` + `hunt-state.sh` (state-file writer/rebuilder
  shape) — all read from `tokenmaxxxer-core`/`claude-plugins` checkouts on
  this machine, not vendored into any new plugin.

loop_state: landed

## Open findings

None. Nothing found during this delivery that blocks landing.

## Next steps / resolution path

N/A — `loop_state: landed` is terminal for this record; no next steps or
open-finding resolution path required.
