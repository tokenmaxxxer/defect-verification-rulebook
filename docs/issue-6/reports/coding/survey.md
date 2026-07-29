# issue-6 current-state survey

## Scope of the audit

`git grep -ril wake` (excluding `docs/issue-*`) over the whole repo returns
exactly two files:

- `verify/hooks/directive.sh` — three hits (lines 53, 55, 60), all inside
  one block: `YOUR RECORD IS THE BOARD`.
- `verify/skills/severity-classification/SKILL.md` — one hit (line 52).

No other rulebook file (hooks, skills, docs/specs, docs/handbooks,
docs/decisions, docs/proposals, docs/reports) mentions wake/WAKES-ON.
`docs/specs/role-handoff-contract.md` does not exist in this repo (it
ships from `tokenmaxxxer-core`), so there is no local contract table to
touch — the issue's "core contract s3 table removed via
tokenmaxxxer-core#36" already happened upstream.

## Per-hit classification

1. `verify/hooks/directive.sh:53-60` — states that WAKES-ON reads
   `docs/issue-<n>/reports/verify.md` ONLY, and that an uncommitted
   record leaves "no downstream role" wakeable. This mixes two things:
   (a) a statement about *this role's own record* (write it first,
   update `loop_state`) — keep, this is exactly the carve-out the issue
   preserves; (b) an assertion about the WAKES-ON *mechanism itself*
   (what reads what, who gets woken) — this is routing content and must
   repoint to `docs/specs/wake-routing.md` (on-the-record, canon per the
   issue) rather than being restated here.

2. `verify/skills/severity-classification/SKILL.md:50-54` — states that
   `blocking`/`advisory` is "the field this contract's gates and other
   roles' WAKES-ON rows actually consult (§3, §5)". This directly names
   that other roles' WAKES-ON rows consult this field — a routing
   restatement — and cites contract §3, the table the issue says was
   removed upstream. Must strip the "other roles' WAKES-ON rows" /
   §3 mention and repoint the routing claim to the on-the-record host
   doc. The severity-band vocabulary claim itself (§5, this role's own
   field) is not a routing statement and stays.

## Write set (frozen)

- `verify/hooks/directive.sh`
- `verify/skills/severity-classification/SKILL.md`

No other files change. No env var, dependency, schema, or migration is
touched — pure prose edit to two existing files.

## Scout: skipped

Skip condition: pure textual repoint against an issue that already names
the exact grep, the exact carve-out (own record states/format stays),
and the exact destination doc (`docs/specs/wake-routing.md`) — no design
decision is open for this change-class to scout.
