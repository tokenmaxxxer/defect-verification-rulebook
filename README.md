# tokenmaxxxer / verify-agent-rulebook

The `verify` role on contract v3. A verify session is spawned with two
plugin sets installed: this marketplace's `verify` plugin, and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/verify`, record at
`docs/issue-<n>/reports/verify.md`. This rulebook owns only what is
verify-specific.

## What `verify` decides

Whether a defect exists in what was built, found by independently
attempting to reproduce it — never a re-litigation of review's verdicts,
never a holistic quality judgment, never a fix. It prevents a defect that
review's pass and qa's attempts both missed from reaching landing
unchallenged. A blocking finding is never overridden by a clean
review-record.

## What is here

    verify/hooks/directive.sh           SessionStart — the four facets:
                                        research (what survives a clean
                                        review; what qa/review already tried),
                                        survey (read everything), proposal
                                        (verbatim attempt list +
                                        code_under_review), judgment
                                        (own-reproduction basis, record empty
                                        attempts, evidence-or-refused,
                                        band→blocking mapping, waiver rule)
    verify/hooks/record-fields-gate.sh  s20 minimum content on the record
    verify/hooks/closed-checks-gate.sh  a closed_checks cite must match the
                                        record's code_under_review: sha —
                                        never the working branch HEAD
    verify/hooks/trailer-gate.sh        commits staging docs/issue-<n>/** carry
                                        `Subject: issue-<n>`
    verify/hooks/handbook-trigger-gate.sh  s21 same-turn handbook sync
    verify/skills/finding-record        attempt + finding schema
    verify/skills/severity-classification  deterministic band lookup + band→gate
    tests/                              repo-level checks (never installed)

## Record vocabulary

`loop_state`: `idle, reproducing, reproduced, cleared` (terminal:
`cleared` — reachable only with no unresolved blocking finding or an
explicit human waiver). Cross-role signals: per-attempt `outcome:
reproduced|not-reproduced` with `evidence:`, inline `finding` blocks with
`addressed_to: coding` + `severity: blocking|advisory`, `closed_checks:`
keyed to `code_under_review:`.

## Install

    claude plugin marketplace add tokenmaxxxer/verify-agent-rulebook
    claude plugin install verify@tokenmaxxxer-verify

Kill switch: `VERIFY_CYCLE_DISABLE=1`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh
