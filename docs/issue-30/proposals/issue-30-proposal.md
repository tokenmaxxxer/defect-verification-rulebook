files:
- tests/run-gate-tests.sh
- verify-state-guard/tests/run-gate-tests.sh
- verify-outcome-gate/tests/run-gate-tests.sh
- verify-finding-gate/tests/run-gate-tests.sh
- verify-state-guard/hooks/verify-state.sh

## Request

Fix issue #30: four test harnesses' missing-core case classifies any
nonzero exit as "fail-closed," but Claude Code's PreToolUse only blocks
on exit 2 — a gate that regresses to exit 1 fails OPEN in production
while still passing the test. Tighten those four assertions to require
exit 2 specifically and assert the deny message. Separately, migrate
`verify-state-guard/hooks/verify-state.sh`'s hand-rolled kill switch to
the `gate_kill_switch_active` fail-open-on-typo fix, and stop silencing
its internal failures with `2>/dev/null || exit 0`.

Pure bugfix (scout-directive skip condition; see survey.md).

## Constraints

- `verify-state.sh` must keep its documented "never block or crash the
  session" contract: it must still exit 0 unconditionally on internal
  failure. Only the diagnostic visibility changes, not the exit code.
- `verify-state.sh` cannot `source` core's gate-lib.sh directly — issue-23
  C3 already established this file is inlined, no cross-plugin source,
  because verify-state-guard installs independently of other plugins
  (documented at `state-guard.sh:2-7`, mirrored by this file).
- The three other harnesses' generic `run`/`run_raw`/`run_raw_precreate`
  helpers already correctly three-way-split (`allow`/`deny`/`exit-$rc`);
  only each file's one inline missing-core block is in scope — no
  rewrite of the already-correct helpers.

## Rationale

For the missing-core assertions: considered leaving the exit-code check
as "any nonzero" and only adding a message assertion on top. Rejected —
a message assertion alone doesn't close the actual defect (exit 1 with
a correct-looking message would still pass), and the generic helpers in
the same files already prove the tighter `0)`/`2)`/`*)` three-way split
is the established local idiom; matching it is both more correct and
more consistent than inventing a second idiom.

For the kill switch: considered making `verify-state.sh` `source` core's
gate-lib.sh (the "real" migration) to call `gate_kill_switch_active`
directly. Rejected — issue-23 C3, already recorded for this exact file's
sibling, forbids cross-plugin sourcing for verify-state-guard, and pulling
in all of gate-lib.sh (trap/JSON-parse/deny machinery) for a two-line
kill-switch check this non-gate script doesn't otherwise need would add
unused surface. Instead, inline the same fixed-default logic
(unrecognized value stays active; only `1|true|yes|on` disables) so the
observable behavior matches `gate_kill_switch_active` exactly without
violating the sourcing constraint.

For silencing state-writer failures: considered writing failures to a
log file under `.claude/`. Rejected — no such logging convention exists
elsewhere in this repo, it adds a new persistence surface and cleanup
question for a best-effort background writer, and the issue's own
acceptance criterion ("emits a diagnostic") is satisfied by stderr,
which Claude Code hook stderr is already surfaced through existing
tooling. Emit to stderr instead — no new surface, and testable by
capturing stderr in the harness.

## What will be done

1. In each of the four harnesses' missing-core inline block, change
   `case "$rc" in 0) got=allow ;; *) got=fail-closed ;; esac` /
   `report fail-closed ...` to `case "$rc" in 0) got=allow ;; 2) got=deny
   ;; *) got="exit-$rc" ;; esac` / `report deny ...`, and capture stderr
   from that invocation to assert it contains a deny-shaped message
   (non-empty, matches the gate's own `refused —` prefix convention used
   elsewhere in the same file's other cases).
2. In `verify-state-guard/hooks/verify-state.sh`, replace the
   `case "${VERIFY_STATE_GUARD_OFF:-}" in ""|0|false|no|off) ;; *) exit 0
   ;; esac` block with an inline equivalent of `gate_kill_switch_active`'s
   documented semantics: lowercase the value, disable (exit 0) only on a
   recognized on-spelling (`1|true|yes|on`), stay active on empty, a
   recognized off-spelling, or any unrecognized value.
3. In the same file, change `python3 <<'PY' 2>/dev/null || exit 0` to
   capture stderr from the heredoc and, on nonzero exit, print a
   one-line diagnostic to this script's own stderr (e.g.
   `verify-state: internal error, state not updated: <captured tail>`)
   before still exiting 0 — contract-preserving, diagnostic-surfacing.
4. Add a `verify-state.sh`-targeted test case to
   `verify-state-guard/tests/run-gate-tests.sh` for: (a) a typo'd
   `VERIFY_STATE_GUARD_OFF` value still results in the state file being
   written (kill switch stays active), and (b) a forced internal failure
   (e.g. unwritable `.claude/`) still exits 0 but produces non-empty
   stderr.

## Out of scope

- Any other kill-switch or exit-code idiom outside the four named
  harnesses and `verify-state.sh` (e.g. the other, already-correct
  `run`/`run_raw` helpers in the same four files).
- Changing `verify-state.sh`'s exit-0-always contract, or turning it
  into a gate that can deny.
- Migrating other hand-rolled patterns not named in the issue.

## How you'll know it worked

- A gate hooks script stubbed to `exit 1` on its missing-core path makes
  all four harnesses' missing-core test FAIL (currently they'd pass).
- `bash tests/run-gate-tests.sh` (which chains all four suites) passes
  green against the real, unmodified gates/writer.
- A typo'd `VERIFY_STATE_GUARD_OFF` (e.g. `VERIFY_STATE_GUARD_OFF=typo`)
  still results in the state file being written by `verify-state.sh`,
  verified by the new test case.
- A forced `verify-state.sh` internal failure still exits 0 (session
  never blocked) and now emits a non-empty stderr diagnostic, verified
  by the new test case.
