# tokenmaxxxer / defect-verification-rulebook

The `verify` role on contract v3. A verify session is spawned with two
plugin sets installed: this marketplace's five `verify*` plugins, and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/verify`, record at
`docs/issue-<n>/reports/verify.md`. This rulebook owns only what is
verify-specific. Core also ships the gate-house standard
(`core/hooks/lib/gate-lib.sh`/`gate-lib.py`, issue #72): every PreToolUse
gate below sources it by reference rather than hand-rolling the
trap/kill-switch/JSON-parse/path-normalize/reconstruct machinery.

## What `verify` decides

Whether a defect exists in what was built, found by independently
attempting to reproduce it — never a re-litigation of review's verdicts,
never a holistic quality judgment, never a fix. It prevents a defect that
review's pass and qa's attempts both missed from reaching landing
unchallenged. A blocking finding is never overridden by a clean
review-record.

## What is here

Five plugins, each self-contained with its own `.claude-plugin/plugin.json`,
`hooks/`, `tests/`, and `README.md`:

    verify/                     skills only — finding-record (attempt +
                                finding schema) and severity-classification
                                (deterministic band lookup + band→gate) —
                                plus closed-checks-gate.sh (PreToolUse: a
                                closed_checks cite must match the record's
                                code_under_review: sha — never the working
                                branch HEAD). No kill switch.
    verify-finding-gate/        finding-gate.sh (PreToolUse): a written
                                outcome: reproduced must carry a paired
                                finding block (verdict:, addressed_to:
                                coding, severity:) inside the same attempt
                                window, on either side of the outcome: line.
                                Kill switch: VERIFY_FINDING_GATE_OFF
    verify-outcome-gate/        outcome-gate.sh (PreToolUse): every
                                outcome: is one of the three adopted values
                                and carries an evidence: field.
                                Kill switch: VERIFY_OUTCOME_GATE_OFF
    verify-state-guard/         state-guard.sh + verify-state.sh: loop_state
                                only advances forward and a `cleared` write
                                is refused while an unresolved blocking
                                finding exists.
                                Kill switch: VERIFY_STATE_GUARD_OFF
    verify-directive-depth/     directive.sh (SessionStart): sources core's
                                role-directive with verify's YOU_DECIDE/
                                USE_WHEN text. Kill switch is core's own
                                per-role DEFECT_VERIFICATION_CYCLE_OFF — no
                                local kill switch; core_role_directive owns it.
    tests/                      repo-level checks (never installed):
                                run-gate-tests.sh (runs every plugin's own
                                suite as a subprocess), stub-check.sh
                                (drift-recurrence detector against core
                                canon), deny-only-check.sh (empty-record
                                substance probe against every *-gate.sh),
                                fixtures/ (pinned core gate-lib.sh/
                                gate-lib.py/role-directive.sh + a
                                compliance-check.sh copy, so the suite runs
                                deterministically without a live core
                                plugin install)

## Record vocabulary

`loop_state`: `idle, reproducing, reproduced, cleared` (terminal:
`cleared` — reachable only with no unresolved blocking finding or an
explicit human waiver). Cross-role signals: per-attempt `outcome:
reproduced|not-reproduced` with `evidence:`, inline `finding` blocks with
`addressed_to: coding` + `severity: blocking|advisory`, `closed_checks:`
keyed to `code_under_review:`.

## Install

    claude plugin marketplace add tokenmaxxxer/defect-verification-rulebook
    claude plugin install verify@tokenmaxxxer-verify
    claude plugin install verify-finding-gate@tokenmaxxxer-verify
    claude plugin install verify-outcome-gate@tokenmaxxxer-verify
    claude plugin install verify-state-guard@tokenmaxxxer-verify
    claude plugin install verify-directive-depth@tokenmaxxxer-verify

Per-plugin kill switches are listed under "What is here" above.

## Run the checks

    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/stub-check.sh
    /bin/bash tests/deny-only-check.sh
