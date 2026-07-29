# issue-6 coding record

code_under_review: HEAD (this commit)
loop_state: cleared

## Why

Wake-routing ownership migration step 3 (issue #6): this rulebook must
contain nothing about which role a state wakes. Canon for that now lives
at `docs/specs/wake-routing.md` (on-the-record repo); this repo keeps
only statements about a role's own record states/format.

## Upstream basis

- Issue #6 body: operator decision 2026-07-30, core contract s3 wake
  table removed via tokenmaxxxer-core#36.
- PR #7 phase-1 survey (`docs/issue-6/reports/coding/survey.md`) and
  proposal (`docs/issue-6/proposals/coding.md`), approved via
  single-account mode: comment `APPROVE issue-6/coding` by
  @JiwonJung94 (approvers.md) on PR #7, 2026-07-29T22:45:53Z.

## What was done

Executing the approved proposal verbatim on two files found by
`git grep -ril wake` (excluding `docs/issue-*`):

1. `verify/hooks/directive.sh` — drop `WAKES-ON` term and the
   "no downstream role can ever be woken by it" clause from the
   `YOUR RECORD IS THE BOARD` block; keep own-record-format language
   (write first in phase 2, update `loop_state` at every transition,
   the phase-1-only-issue failure mode); add a repoint to
   `docs/specs/wake-routing.md`.
2. `verify/skills/severity-classification/SKILL.md:50-54` — drop
   "and other roles' WAKES-ON rows actually consult" and the `§3` cite
   (table removed upstream); keep the `§5` severity-band vocabulary
   claim; add a repoint to `docs/specs/wake-routing.md`.

## closed_checks

- name: post-edit grep still returns exactly the same two files, neither
  containing `WAKES-ON` or naming another role as wake target
  code_sha: HEAD (this commit)
- name: `bash -n verify/hooks/directive.sh` parses
  code_sha: HEAD (this commit)
- name: `tests/parse-check.sh` passes
  code_sha: HEAD (this commit)

## What did not work

(none yet)

## Open findings

None addressed to coding as of this record.

## Next steps

Apply the two edits, run closed_checks, commit, push, update this
record's loop_state to `cleared`.

## Open-finding resolution path

No open blocking finding exists against this record. If one arrives, it
is resolved by adding a `resolved_findings:` entry here with the fix
commit sha before further build commits proceed (coding-progress gate).
