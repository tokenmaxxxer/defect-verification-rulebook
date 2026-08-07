---
Subject: issue-30
---

# Current-state survey — issue #30

Scope: pure bugfix, no open design decision (scout-directive skip
condition). The issue names the exact defect (fail-open exit-code
classification in test harnesses), the exact fix direction (distinguish
exit 2 from other nonzero, assert deny message, migrate kill switch to
`gate_kill_switch_active`, stop silencing state-writer failures), and the
exact acceptance criteria. Scouting for exemplar test-harness patterns
adds nothing a bash `case` statement fix needs. Scout sweep skipped.

## Write set (verified by reading each file)

All four harnesses already use the correct `0) allow ;; 2) deny ;; *)
got="exit-$rc"` three-way split in their generic `run`/`run_raw`/
`run_raw_precreate` helpers — the bug is confined to ONE inline block per
file: the `run_missing_core`/D1 "missing-core" case, which still uses
the two-way `0) allow ;; *) fail-closed` idiom the issue describes.

1. `tests/run-gate-tests.sh:83-90` (`run_missing_core`) — line 87:
   `case "$rc" in 0) got=allow ;; *) got=fail-closed ;; esac`. No deny
   message assertion (report() only checks exit classification).
2. `verify-state-guard/tests/run-gate-tests.sh:126-132` (D1 inline
   block) — line 130: same two-way case. No message assertion.
3. `verify-outcome-gate/tests/run-gate-tests.sh:85-91` (D1 inline
   block) — line 89: same two-way case. No message assertion.
4. `verify-finding-gate/tests/run-gate-tests.sh:138-144` (D1 inline
   block) — line 142: same two-way case. No message assertion.

Confirmed via `tests/fixtures/core/hooks/lib/gate-lib.sh`'s
`gate_trap_fail_closed` (all four production gates call this first) that
in production every abnormal exit is remapped to exactly 2 — so the
missing-core case's "want=fail-closed, any nonzero passes" test can
currently pass even if a future regression makes some path exit 1
(bypassing the trap, e.g. inside `run_missing_core`'s own harness logic
or a future code path not wrapped by the trap), and that gap is exactly
what issue #30 flags. Tightening the assertion to `want=deny` (exit
code 2 only) closes it, matching the already-correct generic helpers in
the same files.

5. `verify-state-guard/hooks/verify-state.sh` — the passive
   PostToolUse/SessionStart state writer (NOT a PreToolUse gate; never
   denies a tool call by design, per its own docstring lines 21-24).
   Two sub-defects named in the issue:
   - Lines 28-31: hand-rolled kill-switch case statement
     (`case "${VERIFY_STATE_GUARD_OFF:-}" in ""|0|false|no|off) ;; *)
     exit 0 ;; esac`) — same fail-open-on-typo bug `gate_kill_switch_active`
     (in `tests/fixtures/core/hooks/lib/gate-lib.sh:74-81`, real one at
     `${CLAUDE_PLUGIN_ROOT_CORE}/hooks/lib/gate-lib.sh`) was written to
     fix: an unrecognized/typo'd value here takes the `*)` branch and
     disables the writer, inverting the intended default. Sibling gate
     `verify-state-guard/hooks/state-guard.sh:8-11` already sources
     gate-lib.sh and calls `gate_kill_switch_active` correctly — this
     file does not source gate-lib.sh at all today.
   - Line 37: `python3 <<'PY' 2>/dev/null || exit 0` — every exception
     inside the heredoc (unwritable `.claude/`, a JSON bug, an unexpected
     schema) is swallowed with `2>/dev/null` and treated identically to
     "job done successfully," with zero diagnostic surfaced anywhere.

## Constraint found while surveying

`verify-state.sh` is explicitly documented (lines 21-24) as
"NEVER block or crash the session it is trying to help" — it is not a
gate and must keep exiting 0 unconditionally regardless of internal
failure. The fix for defect 5's silencing must add a diagnostic (stderr)
without changing the exit-0-always contract; the issue's own acceptance
criterion is "State-writer failure emits a diagnostic," not "state
writer denies."

`verify-state.sh` runs standalone (not via a sourced gate-lib — it is
inlined per issue-23 C3's "no cross-plugin source" rule, mirrored in
`state-guard.sh`'s comment at lines 2-7). It cannot `source` core's
gate-lib.sh for `gate_kill_switch_active` without either duplicating
core's resolution logic or accepting a cross-file dependency that
contradicts the C3 constraint already recorded for this exact directory.
The kill-switch is a two-line pure function (no other gate-lib
machinery is needed here — no trap, no JSON parsing, no deny protocol,
since this file is not a gate at all); inlining just that function's
logic (matching gate-lib.sh's documented semantics exactly: unrecognized
value stays active, only recognized on-spellings 1/true/yes/on disable)
satisfies "migrate the kill switch to gate_kill_switch_active" in spirit
— same fixed default, same recognized-on-spellings set — without
violating the C3 no-cross-plugin-source constraint that already governs
this exact file.

## Existing test coverage to extend

`verify-state-guard/tests/run-gate-tests.sh:83-88` already has a
`state-kill-switch-unrecognized-value-stays-active` case, but it targets
`state-guard.sh` (the gate), not `verify-state.sh` (the passive writer)
— `verify-state.sh`'s own kill switch has no test today. New assertions
needed:
- `verify-state.sh` kill switch: typo'd `VERIFY_STATE_GUARD_OFF` value
  keeps the writer active (state file still gets written).
- `verify-state.sh` failure path: a forced internal failure (e.g.
  unwritable `.claude/` dir) still exits 0 (contract preserved) AND
  emits a stderr diagnostic (new, testable via captured stderr).
