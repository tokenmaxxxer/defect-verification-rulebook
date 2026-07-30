# issue-8 current-state survey

## Scope of the audit

`git grep -rInE "WAKES-ON|wake-routing|board-as-routing|downstream|IS THE
BOARD|\bwake"` (excluding `docs/issue-*`, historical) over the whole repo
returns exactly two files — the same two issue-6 touched:

- `verify/hooks/directive.sh` — the `YOUR RECORD IS THE BOARD` block
  (lines 53-61): names `WAKES-ON` as the reader, says an uncommitted
  record means "the board never saw your work", and repoints to
  `docs/specs/wake-routing.md` for "who this record's states summon".
- `verify/skills/severity-classification/SKILL.md` — line 54: "For which
  roles' loops those gates affect, see `docs/specs/wake-routing.md`."

`docs/specs/wake-routing.md` itself does not exist in this repo (it is
canon at the on-the-record repo) — both hits are pointers into a doc this
rulebook does not otherwise carry.

No other rulebook file (hooks, skills, `docs/specs`, `docs/handbooks`,
`docs/decisions`, `docs/proposals`, `docs/reports`) mentions any routing
vocabulary.

## Per-hit classification

1. `verify/hooks/directive.sh:53-61` — issue-6 already stripped the literal
   term `WAKES-ON` reader-name and the "downstream role" phrasing from the
   surrounding prose, but left: the heading naming what the block is
   ("board"), the repoint to `docs/specs/wake-routing.md`, and "machine
   wake-up dead" as the measured-failure clause. Issue-8 asks for the
   remainder: strip "board" framing from the heading/prose, strip the
   `wake-routing.md` pointer entirely (no repoint — "a rulebook does not
   need to know routing exists"), and restate what survives as pure
   record-format requirement: path, write-first-in-phase-2, update
   `loop_state` on every transition, commit on branch. The one thing this
   leaves out on purpose: *why* the record matters to anyone reading it —
   that motivation is exactly the routing knowledge the issue wants
   removed from the subject role.

2. `verify/skills/severity-classification/SKILL.md:54` — a single trailing
   sentence pointing to `wake-routing.md` for "which roles' loops those
   gates affect". The paragraph's substantive claim (`blocking`/`advisory`
   is the field the contract's gates consult, not a computed average) is
   already routing-free and stays; only the trailing pointer sentence is
   cut.

## Write set (frozen)

- `verify/hooks/directive.sh`
- `verify/skills/severity-classification/SKILL.md`

No other files change. No env var, dependency, schema, or migration is
touched — pure prose edit to two existing files, phase 2 only.

## Scout: skipped

Skip condition: pure textual strip against an issue that already names the
exact grep, the exact two files (confirmed independently above), and the
exact rule (record-format vocabulary only, no routing terms, no pointers)
— no design decision is open for this change-class to scout.
