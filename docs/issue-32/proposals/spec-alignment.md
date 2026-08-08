---
status: proposed
files:
  - README.md
  - verify/skills/finding-record/SKILL.md
  - verify/skills/finding-record/templates/finding-record-template.md
  - verify/skills/severity-classification/SKILL.md
  - docs/handbooks/gate-tests.md
  - verify-directive-depth/hooks/directive.sh
  - docs/issue-32/reports/implementation.md
---

# Proposal: layer the defect-verification.spec.json evidence vocabulary onto this rulebook (issue #32)

## Request

Mirror execution-observation-rulebook#63's completed pattern: the
marketplace (tokenmaxxxer/on-the-record) landed
`roles/specs/defect-verification.spec.json` in issue #521 — required
fields, closed enums, reference-resolution + recomputation rules, a
4-bucket `loop_state`, and a board-decidable `use_when`. This rulebook's
methodology docs, handbooks, and hooks must be brought into alignment
with that spec's vocabulary: no role-scope change, and gate/reference
logic stays referenced from the marketplace rather than forked locally.

## Constraints

- No role-scope change: `verify` still only decides reproduced vs
  not-reproduced by independent attempt — this proposal touches naming
  and documented vocabulary, not what the role does or decides.
- Every spec required-field name (`verdict`, `repro_steps`, `evidence`,
  `severity`, `status`, `finding_type`) must appear at least once in this
  rulebook's methodology/handbook docs (issue #32 acceptance check,
  grep-per-field exits 0).
- `loop_state` vocabulary in docs/hooks must be a superset that includes
  every spec bucket value (`reproducing`, `cleared`,
  `cannot-attempt-independent-reproduction`, `environment-setup-failed`) —
  shown as a grep set-diff in the phase-2 record.
- Reference marketplace gates rather than forking rule logic: the spec's
  `reference_resolution.checked_by` names
  `on-the-record/hooks/role-spec-reference-guard.sh` — this rulebook must
  point at that gate by name for the evidence reference-resolution rule,
  not reimplement it.
- Existing working field names (`outcome`, `steps`) and existing gate
  behavior (`verify-finding-gate`, `verify-outcome-gate`,
  `verify-state-guard`) must keep working unchanged — this is an
  additive vocabulary layer, not a rename, per the issue body's "layer
  the spec's per-claim evidence vocabulary onto existing structures."
- `python3 -m pytest -q` must exit 0, or the phase-2 record states
  `unverifiable: no test suite present` (issue #32 acceptance).

## Rationale

Two structural approaches were available for closing the field-name gap
(`repro_steps` vs `steps`, `finding_type` vs the overloaded `severity`
field on the finding block, `status` absent):

- **Considered and rejected: rename the working fields outright** (`steps`
  -> `repro_steps`, split `finding_type` out of the finding block's
  `severity` value) to match the spec 1:1. Rejected because the issue
  explicitly scopes this as "layer ... onto existing structures, no role
  scope change" — renaming would touch every gate that parses those field
  names (`verify-finding-gate/hooks/finding-gate.sh`,
  `verify-outcome-gate/hooks/outcome-gate.sh`,
  `verify-state-guard/hooks/state-guard.sh`) and their test fixtures, a
  scope well beyond a documentation-vocabulary alignment, and it risks
  breaking already-landed records in `docs/issue-*/reports/` that use the
  current names.
- **Chosen: layer the spec's exact tokens alongside the existing names** in
  prose (e.g. "the per-attempt `steps` field — the spec's `repro_steps`")
  so every required-field name is grep-findable without touching gate
  parsing logic or renaming anything the gates already enforce. This
  satisfies the issue's acceptance check (grep-per-field exits 0) while
  keeping the additive posture the issue calls for, and matches the
  completed execution-observation-rulebook#63 pattern of aligning
  vocabulary without forking rule logic.

For `loop_state`, the alternative of *replacing* `idle`/`reproduced` with
the spec's bucket names was rejected the same way: the spec's
progress/terminal/refusal/error buckets are additive categories (a role
can carry states beyond the spec's minimum — the JSON has no
`additionalStates: false` marker), and `verify-state-guard`'s rank-based
gate logic depends on the existing 4-rank order
(`idle=0 < reproducing=1 < reproduced=2 < cleared=3`). Removing `idle` or
`reproduced` would break `state-guard.sh`'s rank comparisons. The chosen
approach adds the two missing named states
(`cannot-attempt-independent-reproduction`,
`environment-setup-failed`) to the documented vocabulary as the refusal/
error categories, without renumbering the existing rank table.

## What will be done

1. `README.md`'s `## Record vocabulary` section: add the spec's exact
   field tokens (`repro_steps`, `status`, `finding_type`) alongside the
   existing description, naming which existing field each corresponds to;
   extend the documented `loop_state` list with
   `cannot-attempt-independent-reproduction` and
   `environment-setup-failed`, described as the refusal/error states a
   record may carry alongside `idle/reproducing/reproduced/cleared`.
2. `verify/skills/finding-record/SKILL.md`: in the field-list section
   (currently `steps` at point 4), add a parenthetical naming
   `repro_steps` as the spec's field name for the same content; add a
   parenthetical on the finding block's `severity: blocking|advisory`
   value naming `finding_type` as the spec's separate field name for that
   enum, and cross-reference `status` as the spec's free-text field for
   the attempt's overall disposition (mapped to the existing `outcome`
   value where the two overlap, noting `status` is spec's incident-level
   status, `outcome`/`verdict` is spec's per-attempt call — see field
   table added below the existing list).
3. `verify/skills/finding-record/templates/finding-record-template.md`:
   add the same spec-token cross-references as inline comments next to
   the corresponding template fields, so a filled-in record can satisfy
   the grep check without changing the template's actual field names.
4. `verify/skills/severity-classification/SKILL.md`: add one paragraph
   distinguishing the deterministic band (`severity`, free text per the
   spec) from the closed `blocking|advisory` gate value (`finding_type`
   per the spec), matching what `finding-record/SKILL.md` now says.
5. `docs/handbooks/gate-tests.md`: add the spec required-field names to
   whatever field-coverage listing already exists there, and a line
   naming `on-the-record/hooks/role-spec-reference-guard.sh` as the
   marketplace gate this rulebook's evidence reference-resolution rule
   maps to.
6. `verify-directive-depth/hooks/directive.sh`: in the `HAND_OFF` string
   (the three-value outcome enumeration), add `repro_steps` as the named
   spec token alongside the existing "evidence pointer (repro steps, ...)"
   wording — no behavior change, string content only.
7. `docs/issue-32/reports/implementation.md` (phase 2, after approval):
   the phase-2 record itself, carrying the required `code_under_review:`/
   `loop_state:` frontmatter, the grep-per-field results, the loop_state
   set-diff, and the `python3 -m pytest -q` result (or the
   `unverifiable:` line) per the issue's acceptance checks.

## Out of scope

- Renaming any working field (`outcome`, `steps`) or gate-parsed value —
  covered under Rationale above.
- Building `on-the-record/hooks/role-spec-reference-guard.sh`'s
  `checked_by` enforcement locally — the spec itself marks
  `recomputation.checked_by: TBD` as an on-the-record follow-up, not this
  rulebook's job.
- Any change to `verify-finding-gate`, `verify-outcome-gate`, or
  `verify-state-guard`'s actual gate logic (the `.sh` PreToolUse scripts) —
  this proposal is documentation/vocabulary alignment only; the rank
  table and gate behavior are untouched.
- Adding a `status` field to the written record schema as a new required
  gate-checked field — it is documented as a spec cross-reference, not
  wired into `finding-gate.sh`/`outcome-gate.sh` as an enforced field,
  since that would be a gate-behavior change beyond "layer vocabulary."
- Fixing `verify-state-guard/hooks/state-guard.sh`'s rank table and
  `loop_state` regex to actually recognize
  `cannot-attempt-independent-reproduction`/`environment-setup-failed`
  as valid states (the after-proposal hunt,
  `docs/reports/2026-08-09-hunt-spec-alignment.md`, found the gate's
  `RANKS` table omits both and its `LOOP_STATE_RE` doesn't match
  hyphenated identifiers at all, so a record declaring either state is
  silently allowed with no monotonicity/blocking-finding check). This
  proposal documents the two states as vocabulary only; making
  `state-guard.sh` actually enforce them is gate-behavior work outside
  this docs-alignment write set and is flagged here for a follow-up
  issue rather than folded into this one.

## How you'll know it worked

- `grep` for each of `verdict`, `repro_steps`, `evidence`, `severity`,
  `status`, `finding_type` across this rulebook's methodology/handbook
  docs exits 0 for every field (the issue's own acceptance check).
- A grep set-diff of this rulebook's documented `loop_state` vocabulary
  against `{reproducing, cleared,
  cannot-attempt-independent-reproduction, environment-setup-failed}`
  shows the spec set is a subset of the documented set, recorded verbatim
  in the phase-2 record.
- `python3 -m pytest -q` exits 0, or the record states `unverifiable: no
  test suite present`.
- Existing gate test suites (`tests/run-gate-tests.sh` per plugin) still
  pass unchanged, confirming the additive-only claim.
