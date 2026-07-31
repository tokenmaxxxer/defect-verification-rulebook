# issue-12 current-state survey

## Scope of the audit

Read `verify/`'s full hook tree (`_gate-common.sh`, `closed-checks-gate.sh`,
`directive.sh`, `handbook-trigger-gate.sh`, `record-fields-gate.sh`,
`trailer-gate.sh`, `hooks.json`) plus `tests/` and `README.md`, then diffed
against `tokenmaxxxer-core`'s merged canon (`core` main, commits `2fd1fcb`
issue-66 and `130cb13` issue-63, both already merged — checked out locally at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`).

`git grep -rIn "warrant"` over this whole repo returns **no hits**. This
rulebook's `README.md` lists its installed plugin set as `core, terse,
freelunch, scout` — `warrant` is not among them, and no
`agents/warrant-hunter.md` or hunt-cadence directive exists here. Item 1 has
no target in this repo: nothing to remove.

## Per-item findings

1. **warrant-hunter copy** — none found (see above). No-op for this repo.

2. **Gate copies to remove**: `verify/hooks/trailer-gate.sh` (177 lines),
   `verify/hooks/record-fields-gate.sh` (208 lines),
   `verify/hooks/handbook-trigger-gate.sh` (138 lines) are near-verbatim
   role-token substitutions of the same-named files now merged as core canon
   (`core/hooks/{trailer,record-fields,handbook-trigger}-gate.sh`,
   registered globally in `core/hooks/hooks.json`'s `PreToolUse` matcher
   `.*` — every plugin install gets them fired, not just core's own). Their
   entries in `verify/hooks/hooks.json` (`PreToolUse` → `Write|Edit|
   MultiEdit|NotebookEdit` for `record-fields-gate.sh`; `PreToolUse` →
   `Bash` for `handbook-trigger-gate.sh` and `trailer-gate.sh`) become
   redundant double-firing once core's copies run.

   `verify/hooks/closed-checks-gate.sh` and `verify/hooks/_gate-common.sh`
   are **not** canon copies — `closed_checks:`-vs-`code_under_review:` sha
   matching is verify-specific (contract v3 s19's verify facet), has no
   counterpart in core, and stays untouched, including its own `hooks.json`
   entry.

3. **directive.sh stub**: `verify/hooks/directive.sh` (63 lines) is a
   SessionStart hook with the pre-promotion boilerplate shape (trap,
   `VERIFY_CYCLE_DISABLE` kill switch, `CLAUDE_ROLE` guard, heredoc, closing
   `trap - EXIT; exit 0`) around one role-specific heredoc body. Core's
   `core/hooks/lib/role-directive.sh` now factors that exact boilerplate
   into a sourceable `core_role_directive(you_decide, use_when, produces,
   hand_off)` function, reading `CLAUDE_ROLE` itself and gating on
   `<ROLE>_CYCLE_OFF` (uppercased via `tr`, not `${var^^}`, for bash-3.2
   parse-check compatibility) — a different kill-switch var name than this
   repo's current `VERIFY_CYCLE_DISABLE`. The stub's required shape is
   fixed externally: `core/hooks/tests/stub-check.sh` (already core canon,
   not yet vendored here) fails any `directive.sh` that (a) does not source
   `role-directive.sh`, (b) does not call `core_role_directive`, or (c)
   carries any line beyond a plain var assignment, the source line, or the
   one call — i.e. any regrown boilerplate.

   Current body's four facets to carry into the four stub arguments:
   `YOU DECIDE` (own-reproduction basis, never review/qa's verdict),
   `RESEARCH`/`CURRENT-STATE SURVEY` (scout protocol — maps to `use_when`),
   `PROPOSAL` (maps to `produces`), `EXECUTION JUDGMENT` +
   `RECORD REQUIREMENTS` (maps to `hand_off`). `core_role_directive` itself
   appends a fixed closing `RECORD: docs/issue-<n>/reports/<role>.md,
   phase-gated per contract v3 s19` line — this repo's current closing
   record block should not be duplicated in the passed-in strings, only the
   role-unique judgment content (band mapping, evidence-or-refused rule,
   waiver rule, closed_checks-vs-sha rule) that isn't already stated by the
   shared closing line.

4. **Terminal-state divergence**: `verify/hooks/record-fields-gate.sh:185`
   hardcodes `TERMINAL = {"cleared"}`. Core's promoted copy
   (`core/hooks/record-fields-gate.sh:86`) defaults
   `RF_TERMINAL="${RECORD_FIELDS_TERMINAL_STATES:-landed}"` — `landed`, not
   `cleared`. Core's own issue-66 record
   (`docs/issue-66/reports/implementation.md`) names this exact case as the
   one place the promotion could not collapse per-role semantics, and
   states the fix explicitly: "a rulebook whose terminal states genuinely
   differ sets that var in its own `hooks.json` `env`... before deleting
   its local copy — otherwise it silently regresses to the `landed`-only
   default." verify's terminal state is `cleared` (README: "terminal:
   `cleared` — reachable only with no unresolved blocking finding or an
   explicit human waiver"), so `verify/hooks/hooks.json`'s entry for
   `record-fields-gate.sh` must set `RECORD_FIELDS_TERMINAL_STATES=cleared`
   in `env` once the local copy is deleted and core's copy takes over,
   or `cleared` silently stops counting as terminal (spurious next-steps/
   open-finding-resolution-path demands on an already-cleared record).

5. **stub-check.sh confirmation**: `core/hooks/tests/stub-check.sh` is not
   yet vendored under this repo's `tests/`. It is distributed "the way
   `parse-check.sh` already is" per its own header — this repo's
   `tests/parse-check.sh` is confirmed present and is the model to copy
   alongside it. Running it against `verify/hooks/` post-edit is how item 5
   ("confirm passing, record it") gets satisfied — currently N/A since the
   file isn't vendored and the stub doesn't exist yet.

## Write set implied (phase 2, frozen for the proposal)

- Delete: `verify/hooks/trailer-gate.sh`, `verify/hooks/record-fields-gate.sh`,
  `verify/hooks/handbook-trigger-gate.sh`.
- Rewrite: `verify/hooks/directive.sh` (stub form).
- Edit: `verify/hooks/hooks.json` (drop the three deleted gates' entries,
  add `RECORD_FIELDS_TERMINAL_STATES=cleared` env — core's own
  `PreToolUse: .*` firing means no replacement entries are needed for the
  three deleted gates).
- Add: `tests/stub-check.sh` (verbatim copy of core's canon file).
- Edit: `tests/run-gate-tests.sh` — currently invokes the three local gate
  files directly (`$HOOKS/$3`, `HOOKS="verify/hooks"`); once those files are
  deleted this harness needs to point its three gates' subprocess calls at
  the core plugin's installed copy instead, or those cases get dropped in
  favor of core's own test coverage (core's issue-66 record confirms core
  added its own coverage for these three files) — this is a design choice
  the proposal below has to make explicit since it is not one of the
  issue's five numbered items but is a direct consequence of deleting the
  files those tests invoke.
- Record: `docs/issue-12/reports/implementation.md`, phase 2 only.

## Scout: skipped

Skip condition: no design decision is open for the target shape itself —
the exact shape (core's `core_role_directive` signature,
`RECORD_FIELDS_TERMINAL_STATES` config knob, `stub-check.sh`'s structural
check) is fixed upstream by already-merged core canon (core issues #63/#66,
both closed and merged to `main`), not a choice this rulebook or its
external field makes. The one open call this survey found
(`tests/run-gate-tests.sh`'s fate) is answered from the same upstream
record (core added its own coverage for these three files), not from
scouting a product field.
