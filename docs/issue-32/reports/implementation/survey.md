# Survey: rulebook vs roles/specs/defect-verification.spec.json (issue #32)

Subject: issue-32. Upstream: tokenmaxxxer/on-the-record main,
`roles/specs/defect-verification.spec.json` (fetched via `gh api
repos/tokenmaxxxer/on-the-record/contents/...`, landed per issue #521).

## Scout skip record

Skip condition applied: **the spec leaves no design decision open.**
`roles/specs/defect-verification.spec.json` fixes the exact field names,
closed enums, `loop_state` bucket contents, and `use_when.board_condition`
text; the task is to make those exact tokens appear in this rulebook's
docs (issue #32 acceptance: grep-per-field exits 0, loop_state set-diff
shown), not to design a vocabulary. There is no alternative naming or
structure to weigh — the spec is the naming. Per execution-observation-
rulebook#63's completed pattern (mirrored here per the issue body), this
is the same "align to a landed spec" shape, not a design task.

## Upstream spec (verbatim fields)

- `required_fields`: `verdict` (enum: `reproduced`, `not-reproduced`),
  `repro_steps` (string), `evidence` (ref[]), `severity` (string, free
  text — deliberately not an enum per the spec's own
  `reference_resolution.rule`), `status` (string, free text), `finding_type`
  (enum: `blocking`, `advisory`).
- `reference_resolution.rule`: every `evidence[]` entry resolves to an
  existing repo path, commit sha, or line-anchored citation — no orphan
  references (issue-515 invariant 2). `checked_by:
  on-the-record/hooks/role-spec-reference-guard.sh`.
- `recomputation.rule`: `verdict` is derived by executing `repro_steps`
  against the cited `evidence`, never asserted standalone with no attached
  repro log (issue-515 invariant 4). `checked_by: TBD` — per-role
  recomputation enforcement is an explicit on-the-record follow-up, not
  yet built anywhere upstream.
- `write_scope`: `["docs/issue-<n>/reports/defect-verification.md"]`.
- `loop_state`: `progress: [reproducing]`, `terminal: [cleared]`,
  `refusal: [cannot-attempt-independent-reproduction]`,
  `error: [environment-setup-failed]`.
- `use_when.board_condition`: "an execution-observation or
  conformance-review record's result is disputed by another comment on the
  same commit sha AND no defect-verification record exists yet for that
  dispute."

## Current-state grep (write set for the field-presence check)

Grepped every spec required-field name across this repo's methodology/
handbook docs and hooks (excluding `docs/issue-*/` history and `.git`):

| spec field      | present today | where |
|---|---|---|
| `verdict`       | yes, but different referent | `verify/skills/finding-record/SKILL.md` uses `verdict` for the *finding*'s Present/Surface/Absent/Incorrect/Unverifiable axis (contract §2), not for the top-level reproduced/not-reproduced call — that call is currently named `outcome` (`verify/skills/finding-record/SKILL.md:62`, `verify-finding-gate/hooks/finding-gate.sh`) |
| `repro_steps`   | **absent** — current field is named `steps` (`verify/skills/finding-record/SKILL.md:72`) |
| `evidence`      | present, same referent (`SKILL.md`, `verify-outcome-gate/hooks/outcome-gate.sh`, README.md) |
| `severity`      | present, same referent (deterministic band, `verify/skills/severity-classification/SKILL.md`, `verify-state-guard/hooks/state-guard.sh`) — but doubles as the finding-block field that also carries `blocking`/`advisory` (see `finding_type` row) |
| `status`        | **absent** as a record field — `status` only appears in `verify-state-guard/README.md`/`state-guard.sh` describing *this repo's own* PR/plugin status, not an incident-record field |
| `finding_type`  | **absent** by name — the concept exists but is folded into `severity: blocking\|advisory` on the finding block (`SKILL.md:78-82`), conflating the free-text severity band with the closed blocking/advisory gate value the spec keeps as a separate field |

Files carrying this rulebook's methodology/handbook/hook surface (the
write set for phase 2, pending approval):

- `README.md` — role vocabulary section (`## Record vocabulary`)
- `verify/skills/finding-record/SKILL.md`
- `verify/skills/finding-record/templates/finding-record-template.md`
- `verify/skills/severity-classification/SKILL.md`
- `docs/handbooks/gate-tests.md`
- `verify-directive-depth/hooks/directive.sh` (HAND_OFF string enumerates
  the outcome set and steps)
- `docs/specs/README.md` (checked for a role-handoff-contract cross-index
  that also needs the vocabulary layered on)

## loop_state grep (current vs spec)

Current 4-state set, read from `verify-state-guard/hooks/verify-state.sh:45`
and `state-guard.sh:96` (`RANKS = {"idle": 0, "reproducing": 1,
"reproduced": 2, "cleared": 3}`) and restated in `README.md`'s `## Record
vocabulary`: `idle, reproducing, reproduced, cleared`.

Spec 4-bucket set (flattened): `reproducing, cleared,
cannot-attempt-independent-reproduction, environment-setup-failed`.

Set-diff:
- only in current: `idle`, `reproduced`
- only in spec: `cannot-attempt-independent-reproduction`,
  `environment-setup-failed`
- shared: `reproducing`, `cleared`

`idle`/`reproduced` are not contradicted by the spec — the spec's
4-bucket shape (progress/terminal/refusal/error) is a different
partitioning than a flat state list, and `on-the-record`'s own spec
format allows a role's `loop_state` to carry states beyond the minimum the
spec enumerates (the spec states required buckets, not an exhaustive
closed list — confirmed by reading the JSON's shape: each bucket is a
list, not capped at one entry, and no `additionalStates: false` marker is
present). The rulebook is missing the two named refusal/error states
outright: today, "can't attempt at all" collapses into the attempt-level
`blocked: needs-repro-access` outcome, and there is no environment-setup
failure state distinct from a normal attempt outcome.

## Prior-decision context

`docs/decisions/README.md` and `docs/specs/README.md` hold no existing
defect-verification-spec-alignment entry — this is the first alignment
pass against `on-the-record` issue #521's landed spec. `docs/issue-26` and
`docs/issue-30`'s reports show the state-guard/kill-switch remediation
history but predate the spec landing and do not reference
`roles/specs/defect-verification.spec.json`.

## What changes (summary, feeds the proposal)

1. Add `repro_steps`, `status`, and `finding_type` as named tokens
   somewhere in the methodology/handbook surface (grep-passable), without
   renaming the working field names elsewhere and breaking the gates —
   layer the spec vocabulary alongside (`repro_steps` next to `steps`,
   etc.), never fork new gate logic.
2. Add `cannot-attempt-independent-reproduction` and
   `environment-setup-failed` to the documented `loop_state` vocabulary
   (README.md, and wherever `verify-state.sh`/`state-guard.sh` comments
   enumerate ranks) as named refusal/error states, layered onto the
   existing 4-state rank list rather than replacing it.
3. Reference `on-the-record/hooks/role-spec-reference-guard.sh` by name
   for evidence reference-resolution instead of writing new gate logic —
   this rulebook already has `evidence` reference checks distributed
   across `verify-outcome-gate` and `verify/hooks/closed-checks-gate.sh`;
   the proposal will point at the marketplace gate as the source of truth
   for the reference-resolution rule rather than duplicating it.
