# issue-8 build proposal

files: `verify/hooks/directive.sh`, `verify/skills/severity-classification/SKILL.md`

## Request (paraphrased intent, secrets stripped)

Finish stripping routing-side vocabulary (wake, board-as-routing-device,
`WAKES-ON`, downstream roles, pointers to `wake-routing.md`) out of this
rulebook, restating every record obligation as a pure record-format
requirement: path, kind, `loop_state` vocabulary, required fields, write
the record first in phase 2, update `loop_state` on every transition,
commit on branch. Historical docs (`docs/issue-*`, `docs/proposals`,
`docs/reports`) untouched.

## Constraints

- Only the two files the survey found change — same write set issue-6
  already touched, no new hits.
- Own-record-format language (write the record first in phase 2, update
  `loop_state` at every transition, commit on branch, what belongs in the
  record) is preserved verbatim in meaning.
- No repoint to `docs/specs/wake-routing.md` survives anywhere — the issue
  is explicit that a rulebook does not need to know routing exists at
  all, so even the pointer-only form issue-6 left behind is removed, not
  reworded.
- No new files, no doc created under `docs/specs/`.

## What will be done

1. `verify/hooks/directive.sh`, replace the `YOUR RECORD IS THE BOARD`
   block with a `RECORD REQUIREMENTS` block that keeps only: the record's
   path (`docs/issue-<n>/reports/verify.md`), that it is written as this
   role's first act of phase 2, that its `loop_state` field updates at
   every transition, and that phase 2 ending without it committed on the
   branch means the record obligation was not met. Drop the "board"
   framing, drop "machine wake-up dead", drop the `wake-routing.md`
   repoint.
2. `verify/skills/severity-classification/SKILL.md:54`, delete the
   trailing sentence "For which roles' loops those gates affect, see
   `docs/specs/wake-routing.md`." The preceding sentence (the field is
   contract-consulted, not a computed average) stands unchanged.

## Out of scope

- Editing `docs/specs/wake-routing.md` or any file at the on-the-record
  repo.
- Any file outside the two-file write set, including `docs/issue-*` trees.
- Any change to gate/hook control flow — prose only, no `.sh` logic
  touched.
- Phase 2 execution itself: this PR stops after the phase-1 proposal:
  no APPROVE, no implementation, per this issue's explicit scope.

## How it'll be known to work

- Post-edit `git grep -rInE "WAKES-ON|wake-routing|board-as-routing|
  downstream|IS THE BOARD|\bwake"` (excluding `docs/issue-*`) returns no
  hits at all.
- `bash -n verify/hooks/directive.sh` still parses (heredoc/prose change
  only).
- `tests/parse-check.sh` still passes (unchanged gate behavior).
