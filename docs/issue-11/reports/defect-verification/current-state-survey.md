# issue-11 current-state survey

## Scope of the audit

Read this repo's full `verify/` tree (`hooks/directive.sh`,
`hooks/record-fields-gate.sh`, `hooks/closed-checks-gate.sh`,
`hooks/trailer-gate.sh`, `hooks/handbook-trigger-gate.sh`,
`skills/finding-record/SKILL.md` + template,
`skills/severity-classification/SKILL.md`), the root `README.md`, and
`docs/specs/approvers.md`, plus the phase-1 precedents at
`docs/issue-6/proposals/coding.md`, `docs/issue-8/proposals/coding.md`,
`docs/issue-12/proposals/implementation.md` and its paired
`docs/issue-12/reports/implementation/survey.md`. `docs/decisions/` and
`docs/handbooks/` are both empty in this repo — no existing ADRs or
handbook content to reconcile against.

## What "the role" already is here

The branch/board-gate keys writes to `docs/issue-11/**` on the branch's role
token, `defect-verification` (`issue-11/defect-verification`), but the
plugin directory and every hook/skill file in this repo names the role
`verify`. This is the same role this issue calls "defect-verification"
domain-wise: independently reproducing whether a defect exists in what
coding built, never re-litigating review's or qa's verdict, never fixing.
The two names refer to one role; this survey and the proposal use
`verify` when citing existing files and `defect-verification` only for
issue/branch/path plumbing, per the board-gate's own naming.

## Existing rulebook maturity — already fairly deep

This is not a blank rulebook. Per-item findings:

1. **`directive.sh`** — already migrated to the core-canon
   `core_role_directive` stub (per commit `a057481`, issue-12/13's
   precedent), carrying `YOU_DECIDE` / `USE_WHEN` / `PRODUCES` / `HAND_OFF`
   as four heredoc strings. `HAND_OFF` already states: own-reproduction
   basis only, every attempt recorded even when empty, evidence-or-refused
   for `reproduced`, deterministic band→severity mapping
   (Critical/High→blocking, Medium/Low/Unknown→advisory), waiver rule for
   `cleared`, and the `closed_checks` vs. `code_under_review:` sha rule.
2. **`finding-record` skill** — already defines a two-value `outcome` set
   (`reproduced | not-reproduced`), an evidence-or-refused rule enforced
   before write, and a `finding` block schema (`requirement`, `verdict`
   drawn from a five-value set `Present/Surface/Absent/Incorrect/
   Unverifiable`, `evidence`, `rationale`, `spec_vs_built` conditional on
   `Incorrect`, `addressed_to: coding`, `severity`). A field-skeleton
   template exists at `verify/skills/finding-record/templates/
   finding-record-template.md`.
3. **`severity-classification` skill** — already a deterministic
   table-lookup, explicitly rejecting DREAD's averaged-score shape (cites
   the "too subjective, inconsistently scored" critique) in favor of two
   named sourced alternatives: Chromium's five-band scale (S0
   Critical .. S4 Unknown) or Microsoft's four-level bug bar
   (Critical/Important/Moderate/Low, non-averaged, characteristic
   lookup), either mapping to the contract's binary
   `severity: blocking|advisory` gate field.
4. **`record-fields-gate.sh`** — enforces minimum record content
   (contract v3 s20); terminal state is `cleared`, reachable only with no
   unresolved blocking finding or an explicit waiver.
5. **`closed-checks-gate.sh`** — a verify-specific (non-canon) gate: a
   `closed_checks:` cite is valid only against the record's own
   `code_under_review:` sha, never the working-branch HEAD.
6. **`trailer-gate.sh`** — commits staging `docs/issue-<n>/**` carry
   `Subject: issue-<n>`.
7. **`handbook-trigger-gate.sh`** — s21 same-turn handbook sync.

## What is genuinely open / unaddressed by the existing rulebook

- **No named methodology for a reproduction *attempt itself*** —
  `finding-record` records an attempt's outcome and evidence, but nothing
  in the directive or skills states how an attempt should be structured
  (e.g., a fixed precondition/steps/expected/actual shape, à la a test
  incident report) before it is judged reproduced or not. The evidence
  field is a pointer, not a required attempt-write shape.
- **No named root-cause step** — the role's mandate is explicitly "whether
  a defect exists," not causal analysis, but the survey should confirm
  whether any root-cause framing (5 Whys / Ishikawa) is in scope for a
  finding's `rationale` field, or explicitly out of scope (role does not
  fix, and root-cause attribution arguably belongs to coding, not verify).
- **No phase-1 proposal norm specific to this role** — `docs/proposals/
  README.md` says only "drafts, RFCs. Empty for now"; the three existing
  precedent proposals (issue-6, issue-8, issue-12) share a de facto shape
  (files/write-set header, "Request," "Constraints," "What will be done,"
  "Out of scope," "How it'll be known to work") but nothing documents that
  shape as a required norm, and nothing ties it to a defect-verification-
  specific evidentiary standard (e.g., is a scout-brief mandatory the way
  this session's own directives require, and is a "Sources:" list
  mandatory the way IEEE 829-style traceability requires for phase-2 test
  documentation).
- **No existing reference to IEEE 829 / ISO 29119-3, ISTQB severity-vs-
  priority, or a reproduction-report methodology** anywhere in this repo
  (`git grep -rIn "IEEE 829\|ISTQB\|29119"` returns no hits) — the
  Chromium/Microsoft severity citation is the only external standard
  currently sourced into the rulebook.
- **No canon reference pattern check performed yet for this issue** — the
  proposal's plugin reflection plan must confirm whether any newly adopted
  norm belongs in `verify/`'s own tree (role-specific judgment content,
  the pattern already used for `closed-checks-gate.sh`) or should instead
  be phrased as a reference to core canon, per the "core canon scripts are
  reference-only, never copy" rule this session operates under and per the
  issue-12/13 precedent (`a057481`).

## Write set implied for phase 1 (this PR only)

- `docs/issue-11/reports/defect-verification/current-state-survey.md` (this file).
- `docs/issue-11/reports/defect-verification/scout-brief.md`.
- `docs/issue-11/proposals/defect-verification-rulebook.md`.

No file under `verify/`, `docs/decisions/`, `docs/handbooks/`, or
`docs/issue-11/reports/defect-verification.md` (the phase-2 record) is
touched by this PR.
