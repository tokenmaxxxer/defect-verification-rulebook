---
name: finding-record
description: Use while acting as the verify role in the reproducing or reproduced state, to record one outcome per reproduction attempt — and, when a defect reproduces, a finding addressed to coding — in verify-record.md. Use whenever an attempt has been made and needs an outcome written down — never to fix or patch what was found.
---

# finding-record

Belongs to `reproducing` (initial recording) and `reproduced` (dispute
resolution or re-examination recorded inline, still against the same
attempt). Produces the per-attempt outcome record, and any escalating
`finding` block, inside `verify-record.md`, the role's state file, at the
attempt blocks below the header block.

This skill never writes to any file other than `verify-record.md`. It does
not fix, patch, or suggest a patch for anything it finds — it reports.

## What it asks the user for

Nothing, by default — recording an outcome is verify's own reproduction
work, made solo. The skill asks the user only when it cannot attempt a
reproduction at all from what it has: "coding-record points at a runtime
condition I can't trigger from a static diff — can you point me at
deployed access, or should this attempt stay open pending that?" That
answer, or the absence of one, decides whether the attempt proceeds; when
no reproduction can be attempted at all, that situation is recorded as the
`blocked: needs-repro-access` outcome (see below), not left as
unstructured prose only. It does not gate the write of an attempt already
made.

In `reproduced`, if a finding is disputed, this skill asks the user to
state their side, records it, and re-examines the reproduction evidence —
it does not treat the dispute itself as a request to fix anything.

## The outcome set

Exactly one of, per attempt:

- **`reproduced`** — the defect reproduces, with evidence.
- **`not-reproduced`** — the attempt did not reproduce a defect. Recorded
  regardless, so a later pass can see the ground already covered rather
  than repeating it blind.
- **`blocked: needs-repro-access`** — the attempt could not be made at all
  from what is available (missing runtime access, missing repro input,
  etc). Recorded with an `evidence`-equivalent field naming what access or
  information is missing, so an unattempted attempt is never
  indistinguishable from a genuinely-tried-and-clean one.

When an attempt reproduces, this skill additionally writes an inline
`finding` block per `docs/specs/role-handoff-contract.md` §2's `finding`
row, `addressed_to: coding`, carrying `severity: blocking` or `advisory` —
never merged into the attempt's own outcome field.

## The artifact and its field list

Written to `verify-record.md`, in this repository's root (path
configurable via `VERIFY_RECORD_NAME`), as one `---`-delimited block per
attempt below the header block. Attempt fields:

1. **`attempt`** — a stable identifier for what was being tested, verbatim
   reference to the claim under test (a qa defect report, a review
   requirement marked `Present`, or verify's own devised path).
2. **`outcome`** — `reproduced`, `not-reproduced`, or
   `blocked: needs-repro-access`.
3. **`evidence`** — a pointer into the actual reproduction: repro steps,
   commit sha, run output, or a log excerpt. Never a paraphrase of what was
   attempted — the reproduction path itself. This is what makes the record
   actionable: an outcome of `reproduced` with no evidence pointer is
   refused by this skill before it is written (see below). For attempts
   about suspected intermittent/nondeterministic behavior, `evidence` must
   record how many times the attempt was run and how many times it
   reproduced — not a single pass/fail.
4. **`steps`** — what was actually run or checked to attempt the
   reproduction (the marketplace `roles/specs/defect-verification.spec.json`
   names this same content `repro_steps`), stated from the explicit
   starting runtime state (flag/config/fixture) the attempt assumes — an
   implied starting state is not a fact a later reader can re-check.
5. **`expected`** / **`actual`** — required only when the claim under test
   states an expectation (mirrors the IEEE 829 Test Incident Report
   shape); omit when not applicable.
6. **`evidence_kind`** — what the `evidence` pointer actually is
   (recording, transcript, log excerpt, diff, command output), stated
   rather than left implicit, so a reader is never left guessing whether
   they hold the whole picture or one fragment of it.
7. **`environment`** — the commit sha and run/build context, captured at
   the moment the attempt is made rather than reconstructed afterward; a
   reconstructed environment note is a guess, a captured one is a fact the
   evidence can be checked against on a later, moved-forward sha. A
   `blocked: needs-repro-access` outcome still records the actual
   command/output attempted where one exists, not a bare prose note —
   evidence-artifact discipline governs all three outcome values, not only
   `reproduced`.

When an attempt reproduces, the accompanying `finding` block carries,
verbatim from the contract: `requirement`, `verdict`
(`Present|Surface|Absent|Incorrect|Unverifiable`), `evidence`, `rationale`,
`spec_vs_built` (required only when `verdict: Incorrect`),
`addressed_to: coding`, `severity: blocking|advisory` (the spec's
separate `finding_type` field names this same
`blocking|advisory` value — kept distinct from the deterministic
`severity` band described in
`verify/skills/severity-classification/SKILL.md`). The spec's `status`
field is the incident-level free-text disposition; this rulebook's
`outcome`/`verdict` are the per-attempt call the spec's `status` is
derived from, not a renamed version of it.

Spec field-token cross-reference table (`roles/specs/defect-verification.spec.json`
field name -> this rulebook's field):

| spec field     | this rulebook's field                                  |
| -------------- | -------------------------------------------------------|
| `verdict`      | `verdict` (finding block) / `outcome` (attempt block)   |
| `repro_steps`  | `steps`                                                 |
| `evidence`     | `evidence`                                              |
| `severity`     | `severity` (deterministic band, see severity-classification) |
| `status`       | incident-level disposition derived from `outcome`/`verdict` |
| `finding_type` | the finding block's `severity: blocking\|advisory` value |

Template at
`verify-cycle/skills/finding-record/templates/finding-record-template.md`
is the field skeleton this skill fills in per attempt.

## Refusal the skill itself enforces

This skill refuses to accept an outcome of `reproduced` with no `evidence`
pointer. `not-reproduced` still requires an `evidence` field describing
what was attempted, since by definition there is no reproduction evidence
to point at otherwise. `blocked: needs-repro-access` requires its own
`evidence`-equivalent field naming what access or information is missing.

## What this skill never does

- Fix, patch, or propose a patch for anything it records, even if the user
  asks it to while giving an answer — if asked to fix what it found, say
  plainly that this role reports and does not fix, and that the finding
  stands recorded as-is pending coding's own resolution of it.
- Merge `reproduced`/`not-reproduced`/`blocked: needs-repro-access` into a
  single pass/fail signal that loses which attempts were even taken.
- Write to any file other than `verify-record.md`.
- Treat a clean `review-record` as grounds to skip a reproduction attempt
  or record a `not-reproduced` outcome without actually attempting it.
