# issue-6 build proposal

files: `verify/hooks/directive.sh`, `verify/skills/severity-classification/SKILL.md`

## Request (paraphrased)

Wake-routing ownership migration step 3: this rulebook must contain
NOTHING about which role a state wakes. Statements about verify's own
record states/format (loop_state values, when to write the record, what
belongs in it) stay. Anything that names which role a state summons —
including a restated WAKES-ON trigger list — gets stripped or repointed
to the canon doc, `docs/specs/wake-routing.md` (on-the-record).

## Constraints

- Only the two files the survey found (`git grep -ril wake`, excluding
  `docs/issue-*`) change.
- Own-record-format language (write the record first in phase 2, update
  `loop_state` at every transition, `cleared` requires no unresolved
  blocking finding) is preserved verbatim in meaning — only the
  routing-mechanism claims move out.
- No new files, no new doc under `docs/specs/` — `docs/specs/wake-routing.md`
  is canon at the on-the-record repo, referenced by path, not duplicated
  here.

## What will be done

1. `verify/hooks/directive.sh`, `YOUR RECORD IS THE BOARD` block: drop
   the term `WAKES-ON` and the "no downstream role can ever be woken by
   it" clause (both name the routing mechanism/recipient). Keep: only
   `docs/issue-<n>/reports/verify.md` is execution-surface material;
   write it first in phase 2; update `loop_state` at every transition;
   the phase-1-only-issue failure mode this was measured against. Add
   one line repointing "who this record's states summon" to
   `docs/specs/wake-routing.md`.
2. `verify/skills/severity-classification/SKILL.md:50-54`: drop "and
   other roles' WAKES-ON rows actually consult" and the `§3` cite (the
   table it names was removed upstream per tokenmaxxxer-core#36). Keep
   the `§5`-sourced claim that `blocking`/`advisory` is a
   contract-visible field consumed by gates, and add a repoint to
   `docs/specs/wake-routing.md` for which roles' loops those gates
   affect.

## Out of scope

- Editing `docs/specs/wake-routing.md` itself (owned by the on-the-record
  repo, not this rulebook).
- Any file outside the two-file write set, including files under
  `docs/issue-*` trees.
- Any change to gate/hook logic — this is prose only, no `.sh` control
  flow changes.

## How it'll be known to work

- Post-edit `git grep -ril wake` (excluding `docs/issue-*`) returns the
  same two files, but neither line contains `WAKES-ON` or names another
  role/roles as the target of a wake.
- `bash -n` on `verify/hooks/directive.sh` still parses (heredoc/prose
  change only, no shell logic touched).
- `tests/parse-check.sh` still passes (unchanged gate behavior).
