---
name: verify-cycle
description: Use when acting as the `verify` role — adversarially attempting to reproduce defects in a change that coding and qa have already produced artifacts for, and recording a per-attempt reproduced/not-reproduced outcome in verify-record.md, then asking the user to confirm the move to `cleared`. Use whenever asked to independently reproduce, adversarially verify, or stress a change that review has already passed, and never to fix, patch, or improve the code under verification.
---

# verify-cycle

Runs the `verify` role's state machine end to end. See
`docs/specs/state-machine.md` in this repository for the authoritative
transition table, rejection rule, and standing refusal — this file is the
practical walkthrough of using it.

## What this role is for

Adversarial reproduction of defects that coding, qa, and review may all
have missed. `verify` depends on `coding-record`, `qa-record`, and
`review-record` (`docs/specs/role-handoff-contract.md` §4) — it reads what
was built, what qa already tried, and what review concluded, then goes
looking for what none of them caught. Its findings are independent of
review's: per contract §4, "a `verify` finding with `severity: blocking` is
not overridden by a `review-record` in `loop_state: reported` with a clean
verdict — review's and verify's verdicts are independent, and verify's
blocking findings gate landing on their own terms." The plugin's
`PreToolUse` gate (`hooks/state-gate.sh`) will refuse edits to the code
under verification just as it refuses any other unrelated action this role
has no business performing — this skill's job is to keep you from
attempting that in the first place, not to rely on the gate to catch it,
since the gate's write rule is scoped to `verify-record.md` and verify's
own owned record path alone.

## What you are handed, and what you depend on

You are given the change, and what coding and qa have already produced for
the subject — their records, including qa's reproduction attempts and
review's per-requirement verdicts. Reading every other role's record is
always allowed (contract §4's READ-broad rule); what your own conclusion
may cite as its basis is narrower — a `finding`'s basis must be your own
independent reproduction attempt, not a restatement of review's or qa's
prior conclusion standing in for one. A clean `review-record` is context,
never proof that nothing remains to find.

## Walking the state machine

1. **`idle` -> `reproducing`**: triggered by coding and qa having both
   produced artifacts for the subject (contract §3's first verify wake —
   "coding and qa have both produced artifacts for a subject"). Begin
   independent reproduction attempts once instructed.
2. **`reproducing`**: for each defect surface you take up — a claim in
   qa's record, a requirement review marked `Present`, or a path of your
   own devising — attempt to reproduce it directly against the running
   system or the diff, and record exactly one outcome per attempt in
   `verify-record.md`:
   - **reproduced** — the defect reproduces, with evidence (repro steps,
     commit sha, run output).
   - **not reproduced** — the attempt did not reproduce a defect; record
     what was attempted regardless, so a later pass can see the ground
     already covered.
   Never skip recording an attempt just because it came up empty — an
   unrecorded attempt is indistinguishable from one never made.
3. **`reproducing` -> `reproducing`** (self-loop, gated on the user):
   verify needs evidence or access that coding or qa must grant before a
   specific reproduction attempt can continue — record this without
   inventing a new state.
4. **`reproducing` -> `reproduced`**: once every reproduction attempt taken
   up in this pass carries a recorded outcome.
5. **`reproduced` -> `reproduced`** (self-loop, gated on the user): a
   finding addressed to verify, or a disputed reproduction, is re-examined
   and the outcome re-recorded inline against the same attempt.
6. **`reproduced` -> `cleared`** (gated): once no unresolved
   `severity: blocking` finding remains — or the user explicitly waives one
   under contract §8's human-judgment seat — ask the user to confirm the
   move to `cleared`. Do not attempt the write until they answer in their
   own turn, unambiguously; content alone (every attempt recorded) is never
   consent by itself.

## The record file's shape

```markdown
---
status: reproducing
---
---
attempt: <what was attempted, verbatim reference to the claim under test>
outcome: reproduced
evidence: <repro steps, commit sha, run output>
---
---
attempt: <next attempt>
outcome: not-reproduced
evidence: <what was tried>
---
```

One header block carrying `status:` (and no `attempt:` key), followed by
one block per reproduction attempt. A `finding` block, when verify escalates
a reproduced defect to coding, carries the schema in
`docs/specs/role-handoff-contract.md` §2's `finding` row:
`requirement`, `verdict`, `evidence`, `rationale`, `spec_vs_built`
(required only when `verdict: Incorrect`), `addressed_to: coding`,
`severity: blocking|advisory`. `docs/specs/state-machine.md` documents this
shape and the gate's exact parsing rules.

## What never happens in this role

- Editing, patching, or "helpfully fixing" the code under verification.
- Treating a complete-looking attempt log as consent to publish it.
- Letting a clean `review-record` stand in for verify's own reproduction
  attempt.
- Recording an outcome with no evidence pointer.
