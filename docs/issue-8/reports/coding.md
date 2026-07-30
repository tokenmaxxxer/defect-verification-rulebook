# issue-8 coding record

code_under_review: HEAD (this commit)
loop_state: cleared

## Why

Finish stripping routing-side vocabulary out of this rulebook, per issue
#8: restate every record obligation as a pure record-format requirement
(path, that it's written first in phase 2, that loop_state updates every
transition, that phase 2 without it committed means the obligation was
not met), with no mention of wake, board-as-routing, `WAKES-ON`,
downstream roles, or `wake-routing.md`.

## Upstream basis

- Issue #8 body: routing vocabulary leak, requires pure record-format
  restatement, no pointers to on-the-record canon.
- PR #9 phase-1 survey (`docs/issue-8/reports/coding/survey.md`) and
  proposal (`docs/issue-8/proposals/coding.md`), merged 2026-07-30.

## What was done

Executed the approved proposal verbatim on the two-file write set:

1. `verify/hooks/directive.sh` — replaced the `YOUR RECORD IS THE BOARD`
   block with `RECORD REQUIREMENTS`: kept the record's path, that it is
   written as this role's first act of phase 2, that its `loop_state`
   updates at every transition, and that ending phase 2 without it
   committed means the obligation was not met. Dropped "board" framing,
   "WAKES-ON", "machine wake-up dead", and the `wake-routing.md` repoint.
2. `verify/skills/severity-classification/SKILL.md:54` — deleted the
   trailing sentence pointing to `docs/specs/wake-routing.md`; the
   preceding §5 severity-band sentence stands unchanged.

## closed_checks

- name: routing-vocab-grep
  code_sha: HEAD (this commit)
  result: `git grep -InE "WAKES-ON|wake-routing|board-as-routing|IS THE
  BOARD"` returns zero hits outside `docs/issue-*`. One incidental
  "downstream loops continue" hit remains in
  `verify/skills/severity-classification/SKILL.md:13` (pre-existing
  §5 blocking/advisory definition quote, not routing/board framing, not
  in the proposal's write set) — left untouched per scope.
- name: bash-parse
  code_sha: HEAD (this commit)
  result: `bash -n verify/hooks/directive.sh` parses.
- name: parse-check-suite
  code_sha: HEAD (this commit)
  result: `tests/parse-check.sh` — all 6 files ok.

## What did not work

(none)

## Open findings

None addressed to coding as of this record.

## Next steps

None — proposal fully implemented within its two-file write set.

## Open-finding resolution path

No open blocking finding exists against this record. If one arrives, it
is resolved by adding a `resolved_findings:` entry here with the fix
commit sha before further build commits proceed (coding-progress gate).
