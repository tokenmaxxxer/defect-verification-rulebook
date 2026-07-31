loop_state: landed
code_under_review: HEAD

## What was done

Executed the approved proposal (docs/issue-12/proposals/implementation.md)
verbatim, in one batch:

1. Deleted `verify/hooks/trailer-gate.sh`, `verify/hooks/record-fields-gate.sh`,
   `verify/hooks/handbook-trigger-gate.sh` — core's `core/hooks/hooks.json`
   (`PreToolUse` matcher `.*`) already fires its own copies of these three
   for every plugin install.
2. Edited `verify/hooks/hooks.json`: removed the three deleted gates'
   `PreToolUse` entries, kept `closed-checks-gate.sh`'s entry and the
   `SessionStart` -> `directive.sh` entry unchanged, and set
   `RECORD_FIELDS_TERMINAL_STATES=cleared` in an `env` block on the
   remaining `PreToolUse` entry so verify's genuine `cleared` terminal
   state survives the switch to core's `record-fields-gate.sh` instead of
   silently regressing to core's `landed`-only default.
3. Replaced `verify/hooks/directive.sh` with the stub form: sources
   `core/hooks/lib/role-directive.sh` (resolved relative to the core
   plugin's install path) and calls `core_role_directive` with four
   variables carrying this repo's role-unique content verbatim —
   `YOU_DECIDE` (own-reproduction basis), `USE_WHEN` (RESEARCH +
   CURRENT-STATE SURVEY merged), `PRODUCES` (PROPOSAL section), `HAND_OFF`
   (EXECUTION JUDGMENT + RECORD REQUIREMENTS merged, trimming the
   record-path/phase-gating language `core_role_directive`'s own fixed
   closing line already states). Each argument is a single-line `$'...'`
   assignment so `core/hooks/tests/stub-check.sh`'s structural check (no
   line beyond a var assignment, the source line, or the one call) passes.
4. No separate terminal-states file needed — item 2's `hooks.json` env set
   is verify's only role config location.
5. Added `tests/stub-check.sh` as a verbatim copy of
   `core/hooks/tests/stub-check.sh`, alongside the existing
   `tests/parse-check.sh`.
6. Edited `tests/run-gate-tests.sh`: dropped the `record-fields-gate.sh`
   direct-invocation cases and the `trailergate` helper + its three cases
   (both gates are core-owned now, with core's own issue-66 test coverage);
   kept `closed-checks-gate.sh` coverage (verify-specific, unchanged).

## Why

Reference transition only, per the approved proposal (basis: docs/issue-12/
proposals/implementation.md, itself derived from upstream core issues #63
and #66, merged to core main as commits 2fd1fcb/130cb13) — no rewrite of
verify's judgment content. Item 1 of the issue (warrant-hunter copy removal)
was confirmed a no-op for this repo in the phase-1 survey (no
`agents/warrant-hunter.md` or hunt-cadence directive exists here).

## Verification run (issue item 5)

All four commands from the proposal's "how it'll be known to work" section,
run against the finished tree:

- `git grep -rIn "trailer-gate.sh|record-fields-gate.sh|handbook-trigger-gate.sh" verify/`
  — no hits.
- `bash tests/stub-check.sh verify/hooks` — exit 0, reports
  `verify/hooks/directive.sh is a role-directive stub` and no vendored
  copies of the three canon gates or `parse-check.sh`.
- `bash tests/parse-check.sh` — exit 0, all 3 remaining hook files
  (`_gate-common.sh`, `closed-checks-gate.sh`, `directive.sh`) parse under
  `/bin/bash`.
- `python3 -c "import json; json.load(open('verify/hooks/hooks.json'))"` —
  parses; no entry references a deleted filename.
- `bash tests/run-gate-tests.sh` — exit 0, `3 passed, 0 failed`
  (`closed-checks-gate.sh` cases only, as scoped).

## Open findings

None. All five issue items executed and verified per above; no defect or
open question surfaced during the transition.
