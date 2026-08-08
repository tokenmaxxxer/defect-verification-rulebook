---
name: severity-classification
description: Use while acting as the verify role in the reproduced state, when a reproduced defect is escalated as a finding addressed to coding, to attach a severity band (blocking or advisory) to that finding. Use to decide how a reproduced attempt's finding gates landing; never to decide whether the attempt reproduced at all.
---

# severity-classification

Belongs to `reproduced`. Runs after `finding-record` has already recorded a
`reproduced` outcome and its accompanying `finding` block — this skill only
sets that finding's `severity` field, per
`docs/specs/role-handoff-contract.md` §5: "`severity: blocking | advisory`.
`blocking` means loops that DEPEND ON the addressed role's output pause
until the finding is resolved. `advisory` means downstream loops continue;
the finding is context, not a gate."

## What it asks the user for

Nothing to compute the band itself — severity is verify's own judgment
call, made solo, from what the reproduction demonstrated. It asks the user
only if a severity band is disputed after the fact by coding, in which case
it may retain the finding but adjust the recorded band — the finding is
never dropped on dispute, only re-rated.

## The shape of the classification

A **deterministic table-lookup**, not an averaged subjective score, mirroring
the practice research review-rulebook already established for this
org's use of severity: Microsoft's SDL bug bar replaced DREAD's averaged
damage/reproducibility/exploitability/affected-users/discoverability score
for being too subjective and inconsistently scored. This skill uses one of
two sourced deterministic band shapes, chosen by the engagement:

- **Chromium's five bands** — Critical (S0) / High (S1) / Medium (S2) /
  Low (S3) / Unknown (S4), each defined by a concrete capability (arbitrary
  code/resource access at full privilege = Critical; cross-origin data read
  or code exec in another origin's context = High; limited info
  read/modify, or harmless-alone-but-combinable = Medium;
  higher-severity-in-theory but with extreme mitigating/limited-scope
  factors = Low). A Chromium-scale severity of Critical or High normally
  maps to `severity: blocking`; Medium, Low, or Unknown normally maps to
  `severity: advisory`, subject to the engagement's own judgment.
- **Microsoft's four-level bug bar** — Critical / Important / Moderate /
  Low, looked up from characteristics of the finding (attacker
  authentication state: anonymous vs. authenticated; scope: default vs.
  special-configuration scenario; persistence: temporary vs. permanent),
  not computed from a weighted average. Critical or Important normally
  maps to `severity: blocking`; Moderate or Low normally maps to
  `severity: advisory`.

Do not use DREAD's averaged-score shape for this skill, per the sourced
disagreement above. `blocking` vs. `advisory` is the field this contract's
gates actually consult (§5); the chosen band scale is a tool for reaching
that call consistently, not a contract-visible field itself.

## Two distinct spec fields, not one

The marketplace `roles/specs/defect-verification.spec.json` names two
separate fields where this skill and `finding-record` together produce
one deterministic band and one closed gate value: its `severity` field is
the free-text deterministic band this skill computes (Chromium's five
bands or Microsoft's four-level bug bar, above); its `finding_type` field
is the closed `blocking|advisory` enum that `finding-record` writes onto
the finding block and that this rulebook's gates (`verify-finding-gate`,
`verify-outcome-gate`) actually consult. The two must not be collapsed:
`severity` informs the `finding_type` call but is not itself the gated
value.

## The artifact

Writes a `severity` field onto the finding's existing block in
`verify-record.md` (the same block `finding-record` wrote), not a separate
file — this is an addition to an existing finding, not a new artifact.

## What this skill never does

- Compute severity as an average of subjective factors (the DREAD shape).
- Decide whether a defect reproduced — that is `finding-record`'s job,
  prior to this skill running.
- Fix, patch, or propose remediation for the finding it classifies.
- Let a `review-record` in `loop_state: reported` with a clean verdict
  downgrade or drop a `severity: blocking` finding — per contract §4,
  review's and verify's verdicts are independent.
