---
code_under_review:
  - README.md
  - verify/skills/finding-record/SKILL.md
  - verify/skills/finding-record/templates/finding-record-template.md
  - verify/skills/severity-classification/SKILL.md
  - docs/handbooks/gate-tests.md
  - verify-directive-depth/hooks/directive.sh
loop_state: landed
---

# Implementation record — issue #32

## What was done

Layered the marketplace `roles/specs/defect-verification.spec.json`
(tokenmaxxxer/on-the-record, issue #521) evidence vocabulary onto this
rulebook's existing methodology docs/handbooks, additively, per
`docs/issue-32/proposals/spec-alignment.md`:

1. `README.md`'s `## Record vocabulary` section: added the spec's field
   tokens (`repro_steps`, `status`, `finding_type`, `verdict`) as
   cross-references to the existing field names, and extended the
   documented `loop_state` list with the spec's refusal/error states
   (`cannot-attempt-independent-reproduction`, `environment-setup-failed`).
2. `verify/skills/finding-record/SKILL.md`: added `repro_steps` as the
   spec's name for `steps`, `finding_type` as the spec's name for the
   finding block's `severity: blocking|advisory` value, a note on `status`
   as the spec's incident-level disposition, and a field cross-reference
   table.
3. `verify/skills/finding-record/templates/finding-record-template.md`:
   added inline comments naming `repro_steps`, `finding_type`, and
   `status` next to the corresponding template fields — no template field
   renamed.
4. `verify/skills/severity-classification/SKILL.md`: added a paragraph
   distinguishing the spec's `severity` (deterministic band) from
   `finding_type` (the closed `blocking|advisory` gate value).
5. `docs/handbooks/gate-tests.md`: added a "Marketplace spec field
   coverage (issue-32)" section listing the six required-field names and
   naming `on-the-record/hooks/role-spec-reference-guard.sh` as the gate
   this rulebook's evidence reference-resolution rule maps to (referenced
   by name, not forked).
6. `verify-directive-depth/hooks/directive.sh`: added `repro_steps` as a
   named alternative in the `HAND_OFF` string's evidence-pointer wording
   — string content only, no behavior change.

No gate `.sh` logic changed; no field renamed; no `verify-record.md`
schema change enforced by any gate.

## Why

Issue #32 (mirroring execution-observation-rulebook#63's completed
pattern) requires this rulebook's docs to carry every
`defect-verification.spec.json` required-field name and a `loop_state`
superset of the spec's bucket values, while explicitly scoping the work
as "layer ... onto existing structures, no role scope change." Renaming
working fields (`steps` -> `repro_steps`, splitting `finding_type` out of
`severity`) would touch every gate that parses those names and risk
breaking already-landed records — out of scope per the proposal's
Rationale. Layering the spec's exact tokens alongside existing names in
prose satisfies the acceptance grep checks without touching gate parsing
or renaming anything.

## Upstream basis

docs/issue-32/proposals/spec-alignment.md (approved via issue comment
`APPROVE issue-32/implementation`, upstream commit 2cf93a596fd62652165685c422275f90bf207695).

## Acceptance check results

**Required-field grep (issue #32 acceptance, `grep -rl <field> README.md
docs/handbooks verify/skills`), each exits 0 (file found):**

- `verdict` — found in README.md, verify/skills/severity-classification/SKILL.md, verify/skills/finding-record/SKILL.md, verify/skills/finding-record/templates/finding-record-template.md, docs/handbooks/gate-tests.md
- `repro_steps` — found in README.md, verify/skills/finding-record/templates/finding-record-template.md, docs/handbooks/gate-tests.md, verify/skills/finding-record/SKILL.md
- `evidence` — found in README.md, verify/skills/finding-record/SKILL.md, docs/handbooks/gate-tests.md, verify/skills/finding-record/templates/finding-record-template.md
- `severity` — found in README.md, verify/skills/finding-record/templates/finding-record-template.md, docs/handbooks/gate-tests.md, verify/skills/finding-record/SKILL.md, verify/skills/severity-classification/SKILL.md
- `status` — found in README.md, verify/skills/finding-record/templates/finding-record-template.md, verify/skills/finding-record/SKILL.md, docs/handbooks/gate-tests.md
- `finding_type` — found in README.md, verify/skills/finding-record/templates/finding-record-template.md, docs/handbooks/gate-tests.md, verify/skills/finding-record/SKILL.md, verify/skills/severity-classification/SKILL.md

**`loop_state` set-diff** — this rulebook's documented set (README.md:
`idle, reproducing, reproduced, cleared, cannot-attempt-independent-reproduction,
environment-setup-failed`) vs. the spec's bucket values
(`reproducing, cleared, cannot-attempt-independent-reproduction,
environment-setup-failed`): spec set is a subset of the documented set —
`grep -o 'reproducing\|cleared\|cannot-attempt-independent-reproduction\|environment-setup-failed' README.md | sort -u`
returned all four spec values present; documented set is a strict
superset (adds `idle`, `reproduced`).

**`python3 -m pytest -q`**: `unverifiable: no test suite present` — ran
from repo root, collected 0 items ("no tests ran in 0.02s"); this
repository's test surface is `tests/run-gate-tests.sh` /
`tests/stub-check.sh` (bash), not pytest-collected Python tests.

**Existing gate suites** (`tests/run-gate-tests.sh`), confirming
additive-only: full run passed — verify-outcome-gate, verify-finding-gate,
verify-state-guard, verify-directive-depth, and the top-level
closed-checks-gate suites all green, no regressions.

## What did not work

None.

## open findings

None raised against this delivery. The proposal's Out-of-scope section
flags `verify-state-guard/hooks/state-guard.sh`'s `RANKS`/`LOOP_STATE_RE`
not yet recognizing the two hyphenated spec states as a follow-up for a
future issue — not an open finding against this delivery, since this
proposal scoped documentation/vocabulary only.
