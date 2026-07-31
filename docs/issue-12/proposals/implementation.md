# issue-12 build proposal

files: `verify/hooks/directive.sh`, `verify/hooks/hooks.json`,
`verify/hooks/trailer-gate.sh` (delete), `verify/hooks/record-fields-gate.sh`
(delete), `verify/hooks/handbook-trigger-gate.sh` (delete),
`tests/stub-check.sh` (new), `tests/run-gate-tests.sh`

## Request (paraphrased intent)

core landed a single canon for role-agnostic pieces every rulebook used to
vendor: warrant-hunt (core #63) and the three role-agnostic gates plus a
shared directive-boilerplate function (core #66), both merged to core
`main`. This issue is this rulebook's per-rulebook follow-up: drop the local
copies these canon promotions made redundant, point at core instead, and
preserve verify's genuine role-specific difference (its `cleared` terminal
state) explicitly rather than letting it silently regress to core's
`landed` default.

## Constraints (from the survey)

- No `agents/warrant-hunter.md` or hunt-cadence directive exists in this
  repo — item 1 of the issue is a confirmed no-op here, not silently
  skipped.
- `verify/hooks/closed-checks-gate.sh` and `_gate-common.sh` are
  verify-specific, not canon copies, and are out of scope — untouched.
- `directive.sh`'s stub shape is dictated by core's
  `core/hooks/tests/stub-check.sh` (structural check: must source
  `role-directive.sh`, call `core_role_directive`, carry no other logic
  line) and by `core_role_directive`'s four-argument signature
  (`you_decide, use_when, produces, hand_off`) plus its own fixed closing
  `RECORD:` line — role-unique content is preserved as those four
  arguments' text, not reworded.
- `record-fields-gate.sh`'s terminal-state divergence (`cleared` here vs.
  core's `landed` default) is exactly the case core's own issue-66 record
  calls out as needing an explicit `RECORD_FIELDS_TERMINAL_STATES` env
  override before the local copy is deleted.
- Everything else in `verify/`'s hook tree (closed-checks logic, skills,
  README) stays as-is; this is a reference-transition, not a rewrite of
  verify's judgment content.

## What will be done

1. Delete `verify/hooks/trailer-gate.sh`, `verify/hooks/
   record-fields-gate.sh`, `verify/hooks/handbook-trigger-gate.sh` — core's
   `core/hooks/hooks.json` already fires its own copies globally
   (`PreToolUse` matcher `.*`) for every plugin install, this one included.
2. Edit `verify/hooks/hooks.json`: remove the three deleted files'
   `PreToolUse` entries (the `Write|Edit|MultiEdit|NotebookEdit` matcher
   entry for `record-fields-gate.sh` and the `Bash` matcher entries for
   `handbook-trigger-gate.sh`/`trailer-gate.sh`), keeping
   `closed-checks-gate.sh`'s entry and the `SessionStart` → `directive.sh`
   entry unchanged. Add an `env` block on whatever entry core documents for
   this purpose (`RECORD_FIELDS_TERMINAL_STATES=cleared`), so verify's
   `cleared` terminal state survives the switch to core's copy instead of
   silently regressing to `landed`-only.
3. Replace `verify/hooks/directive.sh` with the stub form: source
   `core/hooks/lib/role-directive.sh` (resolved relative to the core
   plugin's install path, per that file's own documented usage), then call
   `core_role_directive` with four strings carrying this repo's existing
   role-unique content — `YOU DECIDE` (own-reproduction basis, never
   review/qa's verdict, never a fix), current `RESEARCH` +
   `CURRENT-STATE SURVEY` sections merged into `use_when`, current
   `PROPOSAL` section as `produces`, current `EXECUTION JUDGMENT` +
   `RECORD REQUIREMENTS` sections (band mapping, evidence-or-refused,
   waiver rule, closed_checks-vs-sha rule) merged into `hand_off` —
   trimming only the record-path/phase-gating language that
   `core_role_directive`'s own fixed closing line already states, so it is
   not duplicated.
4. No separate `RECORD_FIELDS_TERMINAL_STATES` file is needed beyond the
   `hooks.json` env set in step 2 — this repo has no other place role
   config lives.
5. Add `tests/stub-check.sh` as a verbatim copy of
   `core/hooks/tests/stub-check.sh`, alongside the existing
   `tests/parse-check.sh`/`tests/deny-only-check.sh` copies, per that
   file's own "every rulebook copies this file verbatim" header.
6. Edit `tests/run-gate-tests.sh`: drop the three `run` cases that invoke
   `trailer-gate.sh`/`record-fields-gate.sh`/`handbook-trigger-gate.sh`
   directly against `$HOOKS` (`verify/hooks`, now missing those files) —
   core's own issue-66 landing added its own test coverage for these three
   files, so re-deriving that coverage here would be a second, divergeable
   copy of tests for logic this repo no longer owns. Keep this harness's
   coverage of `closed-checks-gate.sh` (verify-specific, stays local)
   unchanged.
7. Run `tests/stub-check.sh verify` and `tests/parse-check.sh` against the
   rewritten `directive.sh`; record both outcomes in
   `docs/issue-12/reports/implementation.md` — item 5 of the issue.

## Out of scope

- `verify/hooks/closed-checks-gate.sh`, `_gate-common.sh`, both skills
  directories, and `README.md` — no edits.
- Any change to core (`tokenmaxxxer-core`) itself — that promotion is
  already merged; this PR only consumes it.
- Phase 2 execution itself: this PR stops after the phase-1 proposal — no
  APPROVE, no implementation, per this issue's explicit scope.
- Rewording verify's judgment content (band mapping, evidence-or-refused,
  waiver rule) beyond relocating it into the stub's four arguments —
  meaning preserved verbatim, not rewritten.

## How it'll be known to work

- `git grep -rIn "trailer-gate.sh|record-fields-gate.sh|
  handbook-trigger-gate.sh" verify/` returns only `closed-checks-gate.sh`'s
  own file (no self-reference) and no hits for the three deleted files
  anywhere under `verify/`.
- `bash tests/stub-check.sh verify/hooks` exits 0 and reports
  `directive.sh` as a role-directive stub.
- `bash tests/parse-check.sh` still passes on the rewritten `directive.sh`.
- `python3 -c "import json; json.load(open('verify/hooks/hooks.json'))"`
  parses and contains no entry referencing a deleted filename.
- `bash tests/run-gate-tests.sh` passes with only `closed-checks-gate.sh`
  cases remaining.
