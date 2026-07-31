# issue-17 scout brief

**Mode**: local-codebase sweep, sequential (single session, no parallel
subagent/tool fan-out — the issue text itself names the one exemplar class
that matters here: sibling rulebook plugins already checked out on this
machine implementing the exact "directive+gate+test" shape issue #17 asks
for). Web search was not used: the comparison class issue #17 names
(implementation-rulebook's hook-machine bar, and canon's own
methodology-gate pattern) is intra-system prior art, not external market
practice, and is more directly load-bearing than a web search on generic
"policy enforcement hook" patterns would be. 2 stages: sweep (list sibling
rulebook plugins + read their gate/state scripts) + one deepening round
(read `implementation-rulebook`'s state-tracking pair in full).

## Must-bes (every enforcement-carrying rulebook plugin here has these)

- A dedicated PreToolUse gate script per role-specific methodology, layered
  ADDITIONALLY on top of any generic core-canon field gate, never replacing
  it (pricing: `methodology-gate.sh` alongside canon's `record-fields-gate.sh`).
- Fail-closed on every path: unparseable JSON, non-dict payload,
  unreconstructable resulting content, missing python3 — all `deny`, never
  silently `allow`.
- A `permissionDecision` of `deny` (exit 2) or pass-through (exit 0) only —
  never an `allow` verdict emitted by the gate itself (`tests/deny-only-check.sh`,
  already in this repo, enforces this repo-wide).
- Scope check first: the gate is a no-op (`allow`) for any write outside its
  named target path pattern, so it never blocks unrelated writes.
- Order/state constraints (when the methodology has a required sequence)
  live in a separate small state file + guard script pair, not folded into
  the field-presence gate (`state.sh` + `hunt-guard.sh`), so the
  step-order check and the field-presence check can fail independently and
  be tested independently.
- A matching subprocess test file under the repo-root `tests/` directory,
  same shape as the field gate itself (`tests/run-gate-tests.sh`'s `run()`
  helper spins up a scratch git repo, feeds a JSON tool-call payload on
  stdin, reads the exit code).

## Performance axes these exemplars compete on

1. **Precision of the "required element present" check** — pricing's gate
   uses a small `has_any(...)` keyword-set per element rather than one giant
   regex, so a missing element names itself specifically in the deny
   message (adopt).
2. **Fail-closed completeness** — every exemplar traps `EXIT` first
   (`__fc`) before any `set -e`/sourcing, so a mid-script crash still denies
   (adopt — already this repo's own `closed-checks-gate.sh` pattern too).

## Adopt

- Layer a new `finding-fields-gate.sh` beside `closed-checks-gate.sh`,
  reusing `_gate-common.sh`'s `resolve_root` and the same fail-closed trap —
  checks the attempt/finding required-field list from
  `finding-record/SKILL.md` (§ "The artifact and its field list") is
  present in the resulting write content.
- Add a `state.sh`-equivalent (`verify-state.sh`) tracking the single
  contract-mandated order fact this role actually has —
  `idle -> reproducing -> reproduced -> cleared` (contract row 69) — and a
  `state-guard.sh` refusing a write that jumps straight to `cleared`/
  `reproduced` with no prior `reproducing` state recorded, mirroring
  `hunt-guard.sh`'s shape.
- A matching `tests/run-gate-tests.sh` extension (allow/deny pairs), same
  `run()` helper already used for `closed-checks-gate.sh`.

## Skip

- Gating severity-value *correctness* (that the assigned band actually
  matches the defect class) — this is a judgment call a string-match gate
  cannot verify without re-deriving the reproduction itself; only
  *presence* of a `severity: blocking|advisory` value is mechanically
  checkable, matching pricing's own skip of "verdict number correctness"
  in favor of "verdict number is labeled."
- Gating "evidence is verify's own attempt, not a restatement of qa/review's" —
  unenforceable by static content inspection; stays prose-only in
  `HAND_OFF`, same posture issue-11 already left this element in.
- A new agents/ directory or repeating checklist — the only repeated
  procedure here (per-attempt recording) is already a single skill
  (`finding-record`); issue #17's "if needed" branch for agents/checklists
  does not apply, this role has no additional cyclical sub-procedure beyond
  what `finding-record` already covers.

## Gap line

Current state already meets: fail-closed shape, scope-first no-op,
deny-only verdicts, subprocess test harness shape (all inherited from
`closed-checks-gate.sh`/`tests/run-gate-tests.sh`, nothing new to build
there). Missing: field-presence enforcement for attempt/finding records,
the three-value outcome set enforcement, and state-order enforcement —
exactly the three items this proposal adds.

Sources:
- /home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh
- /home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/hooks.json
- /home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/state.sh
- /home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/hunt-state.sh
- /home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/hunt-guard.sh
- /home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/coding-progress-gate.sh
- verify/hooks/closed-checks-gate.sh, verify/hooks/_gate-common.sh, tests/run-gate-tests.sh, tests/deny-only-check.sh (this repo)
- /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/contract/role-handoff-contract.md (row 69, §16, §~220-224)
