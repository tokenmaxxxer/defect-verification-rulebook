# issue-17 defect-verification enforcement maturation — proposal

files (phase 2 only, not touched by this PR): `verify/hooks/directive.sh`,
`verify/hooks/finding-fields-gate.sh` (new), `verify/hooks/verify-state.sh`
(new), `verify/hooks/state-guard.sh` (new), `verify/hooks/hooks.json`,
`tests/run-gate-tests.sh`

## Request (paraphrased intent)

Issue-11's phase-2 delivery (`128d518`) adopted six methodology elements
(fixed attempt shape, severity-vs-priority boundary, three-value outcome
set, repeat-run note, deterministic severity scoring, no root-cause
requirement) but landed all of them as directive/skill prose only. Issue
#17 asks that the adopted norm be pushed from prose into the same kind of
mechanical enforcement `implementation-rulebook`'s hook machine already
demonstrates for coding, and that the two facets (phase-1 proposal
discipline, phase-2 record discipline) each get concrete, checkable
step/criterion/prohibition text rather than a one-line `PRODUCES` summary.

## Constraints

- C1 (survey): exactly one gate exists today
  (`closed-checks-gate.sh`), and it enforces only §16 sha-matching — no
  field-presence check, no outcome-set check, no state-order check exists
  anywhere in this plugin (survey, "Gates" section).
- C2 (survey): `finding-record/SKILL.md` already states the full required
  field list (`attempt`/`outcome`/`evidence`/`steps`/conditional
  `expected`/`actual`, plus the finding block's contract-verbatim fields)
  and the refusal norm — this proposal's gate checks exactly that
  already-adopted list, inventing no new fields.
- C3 (survey): contract row 69 fixes the verify-record state list as
  `idle,reproducing,reproduced,cleared` and §~220-224 forbids `cleared`
  with an unresolved blocking finding — the only sequence constraint this
  role actually has, and the one this proposal's state guard targets.
- C4 (scout, adopt): every enforcement-carrying sibling plugin here layers
  a role-specific gate additionally on top of (never replacing) the generic
  gate, fails closed on unparseable/unreconstructable input, never emits an
  `allow` `permissionDecision`, and ships a matching subprocess test in
  `tests/run-gate-tests.sh`'s `run()` shape — this proposal reuses that
  shape exactly, per `pricing/hooks/methodology-gate.sh` and this repo's
  own `closed-checks-gate.sh`.
- C5 (scout, adopt): order constraints get a separate small state file +
  guard pair rather than being folded into the field gate, per
  `implementation-rulebook`'s `state.sh`/`hunt-guard.sh` split — keeps
  field-presence and state-order failures independently testable.
- C6 (scout, skip): severity-value *correctness* and "evidence is verify's
  own attempt" are not gated — both require re-deriving the reproduction
  itself, which no static-content check can do; only literal presence is
  checked, consistent with `methodology-gate.sh`'s own skip of verdict
  correctness.
- C7 (canon constraint, per issue): canon-owned mechanics (stub shape,
  `_gate-common.sh`'s `resolve_root`, the generic core `record-fields-gate.sh`
  minimum-content check, `trailer-gate.sh`, `handbook-trigger-gate.sh`) are
  referenced and reused, never copied or re-implemented in `verify/`.

## What will be done (phase 2 design; not executed by this PR)

1. **Directive depth** — replace `directive.sh`'s single-line `PRODUCES`
   string with a facet-structured heredoc (phase 1 / phase 2 each get their
   own numbered steps, a judgment-criteria line, and a "never" line),
   mirroring the depth `no-footgun/hooks/directive.sh` already carries for
   its own facet gate:
   - Phase 1 (`USE_WHEN`, already scout-protocol shaped from issue-11 —
     extend, don't replace): steps = read coding/qa/review records ->
     enumerate candidate attempts naming their source (qa report / review
     Present verdict / self-devised) -> name `code_under_review:` and which
     `closed_checks` will be cited vs re-derived. Criterion: an attempt list
     with no named source per item is rejected as too vague to act on.
     Never: proposing a fix, re-litigating review's verdict as the attempt
     itself.
   - Phase 2 (`HAND_OFF`): steps = attempt -> record outcome (one of the
     three values, always) -> on `reproduced`, write the finding block ->
     assign severity by the deterministic band, never freehand -> check
     `cleared` eligibility (no unresolved blocking finding). Criterion:
     every attempt taken has a recorded outcome, no exceptions, including
     empty ones. Never: skipping an attempt's outcome, merging the
     three-value set into pass/fail, setting a priority/fix-urgency value,
     citing a `closed_checks` entry against a stale sha.
2. **`finding-fields-gate.sh`** (new, PreToolUse, registered alongside
   `closed-checks-gate.sh` in `hooks.json`, same matcher and target path
   `docs/issue-<n>/reports/verify.md`): on a write reconstructable per the
   existing `closed-checks-gate.sh` content-reconstruction logic, requires
   the resulting content to carry, per attempt block: an `outcome:` value
   that is exactly one of `reproduced`, `not-reproduced`, or `blocked:
   needs-repro-access` (anything else denied by name); an `evidence:` field
   (any outcome); and when `outcome: reproduced` appears, a paired
   `finding` block carrying `verdict:`, `addressed_to: coding`, and
   `severity: blocking` or `severity: advisory` (missing any one denied by
   name, per-field, mirroring `methodology-gate.sh`'s per-element `missing`
   list rather than one generic denial).
3. **`verify-state.sh` + `state-guard.sh`** (new pair, mirroring
   `state.sh`/`hunt-guard.sh`): a small state file
   (`.claude/verify-state-issue-<n>.json`, same on-disk convention as
   `hunt-state.sh`) records the highest state reached
   (`idle < reproducing < reproduced < cleared`); `state-guard.sh`, a
   second PreToolUse hook on the same write surface, denies a write whose
   resulting content declares `cleared` or `reproduced` with no prior
   `reproducing`-state write ever recorded for that issue, and denies a
   `cleared` write whose resulting content still shows an unresolved
   `severity: blocking` finding with no paired resolution note.
4. **Gate tests**: extend `tests/run-gate-tests.sh` with allow/deny pairs
   for both new gates (valid three-value outcome / invalid outcome string /
   `reproduced` missing evidence / `reproduced` missing finding fields /
   `cleared` skipping `reproducing` / `cleared` with unresolved blocking
   finding), using the file's existing `run()` helper unchanged.
5. **No new agents/checklist**: per scout-brief skip — the role's one
   repeating procedure (`finding-record`) is already a single skill; issue
   #17's "if needed" branch does not trigger here.

## Out of scope

- Any edit to `verify/hooks/*.sh`, `verify/hooks/hooks.json`,
  `tests/run-gate-tests.sh`, or `docs/issue-17/reports/verify.md` (the
  phase-2 record) — none touched by this PR; this document is design only.
- Any change to core (`tokenmaxxxer-core`) or copying canon gate logic into
  `verify/` — `finding-fields-gate.sh` and `state-guard.sh` are role-unique
  additions layered beside canon's generic gates, per C7.
- Gating severity-value correctness or attempt-authorship (evidence is
  genuinely verify's own) — C6.
- Phase 2 execution itself — this PR stops after the phase-1 proposal, no
  APPROVE, no implementation, pending a human approver in
  `docs/specs/approvers.md`.
- Exact on-disk state-file schema and path for item 3 — left as a phase-2
  implementation detail within the frozen `idle<reproducing<reproduced<cleared`
  order this proposal fixes.

## How it'll be known to work (phase 1 acceptance)

- `docs/issue-17/reports/defect-verification/current-state-survey.md` and
  `scout-brief.md` exist; the brief states its sweep mode explicitly and
  carries a non-empty `Sources:` list.
- Every Constraint (C1-C7) above traces to a named survey section or a
  scout-brief adopt/skip line.
- `git diff --stat main...HEAD -- verify/ tests/` is empty (no phase-2 file
  touched by this PR).
- `git grep -n "idle,reproducing,reproduced,cleared\|methodology-gate.sh\|hunt-guard.sh" docs/issue-17/` finds the design's cited exemplars and contract anchor.
