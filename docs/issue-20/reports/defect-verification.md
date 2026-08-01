# issue-20 gate A+ remediation — phase-2 delivery record

## What was done

Delivered the approved proposal
(`docs/issue-20/proposals/gate-a-plus-remediation.md`) in full: migrated the
gate-house-standard-eligible gates onto core's `gate-lib.sh`/`gate-lib.py`
(issue #72), fixed the finding-window two-sided bound, upgraded the
`code_sha` extraction to block-scoped, added the issue's mandatory test
cases, resynced `README.md`, and ran core's `compliance-check.sh` as
closing evidence.

1. **Gate-lib migration** — `verify/hooks/closed-checks-gate.sh`,
   `verify-finding-gate/hooks/finding-gate.sh`, and
   `verify-outcome-gate/hooks/outcome-gate.sh` now source core's
   `gate-lib.sh`/`gate-lib.py` instead of hand-rolling the
   trap/kill-switch/JSON-parse/path-normalize/reconstruct machinery.
   `outcome-gate.sh` was not in the proposal's original file list — the
   phase-1 survey's C5 claim that it carried no kill switch was wrong (it
   has `VERIFY_OUTCOME_GATE_OFF` with the same pre-issue-72 fail-open case
   statement); `compliance-check.sh` independently confirmed the same
   kill-switch and reconstruction-violation trips the two originally-listed
   gates had, so it was migrated too rather than left as a second instance
   of the exact defect class this issue exists to close.
   `gate_reconstruct_write` closes the `replace_all`/`NotebookEdit` bug in
   all three; `gate_normalize_path(realpath(root), path)` preserves the
   prior symlink-resolving behavior per proposal C6; each gate also gained
   Bash-tool-write coverage via `gate_bash_write_targets` (deny fail-closed,
   since a shell command's effect on file content can't be inspected).
2. **Directive-depth fix** — `verify-directive-depth/hooks/directive.sh`'s
   `CLAUDE_PLUGIN_ROOT_CORE` fallback already followed core's documented
   pattern (proposal C1); the local `VERIFY_DIRECTIVE_DEPTH_OFF`
   kill-switch case statement was removed per C2 in favor of
   `core_role_directive`'s own `<ROLE>_CYCLE_OFF` handling. The test harness
   now provisions a fixture `core/` (`tests/fixtures/core/`, pinned copies
   of `gate-lib.sh`/`gate-lib.py`/`role-directive.sh`) and sets
   `CLAUDE_PLUGIN_ROOT_CORE`/`CLAUDE_ROLE` so the script runs
   deterministically. `tests/parse-check.sh` deleted per C2 (vendored drift
   of a now-core-owned hook).
3. **Finding-window two-sided bound** — `finding-gate.sh:window_for` now
   binds each `outcome: reproduced` occurrence on both sides (previous
   section/outcome boundary through next), completing what the function's
   own docstring already promised. New fixtures cover fields-before-outcome
   and multi-attempt mixed ordering — the case the prior 8/8-green suite
   never exercised.
4. **Semantic upgrade** — `closed-checks-gate.sh` now extracts `code_sha`
   only from inside a `closed_checks:` block's own extent (its line to the
   next top-level field/heading), not the whole reconstructed document.
5. **Mandatory test cases** — added to `tests/run-gate-tests.sh`,
   `verify-finding-gate/tests/run-gate-tests.sh`, and
   `verify-outcome-gate/tests/run-gate-tests.sh`: Edit+`replace_all: true`
   against a multiply-occurring `old_string`, MultiEdit mixing
   `replace_all` true/false, malformed/empty JSON, kill-switch set to an
   unrecognized value (asserts the gate stays active), absolute and
   `./`-prefixed path variants matching the same fixture, and a Bash-tool
   write reaching the guarded path.
6. **README sync** — root `README.md` rebuilt from the actual five-plugin
   layout (`verify`, `verify-finding-gate`, `verify-outcome-gate`,
   `verify-state-guard`, `verify-directive-depth`, root `tests/`), each with
   its real kill-switch env var and hook path; ghost references
   (`record-fields-gate.sh`, `trailer-gate.sh`, `handbook-trigger-gate.sh`,
   `VERIFY_CYCLE_DISABLE`, `tests/parse-check.sh`) removed.
7. **Compliance close-out** — `tests/fixtures/core-compliance-check.sh`
   (pinned copy of core's `compliance-check.sh`, issue #72) run against
   every plugin's `hooks/` dir:

       verify/hooks                 -> ok — closed-checks-gate.sh
       verify-finding-gate/hooks    -> ok — finding-gate.sh
       verify-outcome-gate/hooks    -> ok — outcome-gate.sh
       verify-state-guard/hooks     -> no *-gate.sh files found (state-guard.sh
                                       does not match the *-gate.sh glob this
                                       core-canon detector scans by; not in
                                       this issue's file list, no fix
                                       requested for it)
       verify-directive-depth/hooks -> no *-gate.sh files found (directive.sh
                                       is not a gate)

   Clean on every file the detector actually scans.

## Why

The 2026-08-01 audit graded this rulebook's gates B: a 1/7 shipped-suite
failure and a forward-only finding window that a "mention passes" bypass
could exploit. The issue asked all named defects fixed to A+ across every
axis, with an explicit precondition — adopt core's now-landed gate-house
standard (issue #72) by reference, never reimplement it. This delivery
builds exactly what the approved proposal designed, with one addition
(`outcome-gate.sh`) the proposal's own survey missed but its own closing
criterion (a clean `compliance-check.sh` run) caught.

## Upstream basis

- Approval: issue #20 comment `APPROVE issue-20/defect-verification`
  (human approver JiwonJung94, single-account mode).
- `docs/issue-20/proposals/gate-a-plus-remediation.md` (approved design,
  constraints C1-C7, design items 1-7).
- `docs/issue-20/reports/defect-verification/current-state-survey.md`
  (phase-1 reproduction of the 1/7 failure, the forward-only window bug,
  and the substring-only semantic checks).
- Core's gate-house standard (issue #72,
  `core/hooks/lib/gate-lib.sh`/`gate-lib.py`,
  `core/hooks/tests/compliance-check.sh`) — consumed by reference at the
  documented `CLAUDE_PLUGIN_ROOT_CORE`-relative path; pinned copies under
  `tests/fixtures/core/` exist only so this repo's own suite runs
  deterministically without a live core plugin install, never sourced by
  any shipped gate.

loop_state: landed

## Open findings

None. Nothing found during this delivery that blocks landing.
`tests/deny-only-check.sh`'s pre-existing FAIL (no gate refuses a
field-free `verify.md` write, proposal C7) remains unfixed as scoped — an
explicit non-goal, flagged there as a follow-up candidate, not a finding
against this delivery.

## Next steps / resolution path

N/A — `loop_state: landed` is terminal for this record; no next steps or
open-finding resolution path required.
