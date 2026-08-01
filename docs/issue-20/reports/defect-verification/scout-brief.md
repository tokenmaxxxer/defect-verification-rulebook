# issue-20 scout brief (defect-verification, gate A+ remediation)

Mode: single-session sequential fetch (no parallel dispatch available for
external repo reads in this turn — recorded per scout-directive fallback
rule). 2 stages: (1) fetch core's `gate-lib.sh`/`gate-lib.py` +
`gate-house-standard.md` + `compliance-check.sh` from `tokenmaxxxer-core@main`
via `gh api`; (2) run `compliance-check.sh`'s two detection rules by hand
against this repo's gates (its own script requires a local checkout of core,
not available here — ran its two `grep` conditions manually instead, same
logic). Saturated after stage 2: the standard's shape is fully specified in
the handbook doc (function list, migration checklist, mandatory test-case
list) and this repo's own violations are directly greppable — a third round
would not change any design decision.

## Must-bes (from the landed gate-house standard, core issue #72)

- Source `gate-lib.sh` for trap/kill-switch/deny/allow/bash-write-scan;
  load `gate-lib.py` via `importlib.util.spec_from_file_location` for
  JSON-parse/path-normalize/write-reconstruct. Never vendor a copy —
  `canon-manifest.txt` + `stub-check.sh` catch a vendored copy (this repo's
  own `stub-check.sh` already demonstrates that exact catch for
  `parse-check.sh`, see survey §1).
- `gate_kill_switch_active`: only `1|true|yes|on` (case-insensitive)
  disables; every other value, recognized-off or unrecognized, stays
  active. Fixes the exact `case ... esac` shape this repo's
  `finding-gate.sh`/`directive.sh` both currently use.
- `gate_reconstruct_write`: full `Write`/`Edit`/`MultiEdit`/`NotebookEdit`
  reconstruction honoring each edit's own `replace_all` independently.
- Mandatory six-case test harness per the standard doc (`run-gate-lib-tests.sh`
  shape): `replace_all: true` against multiply-occurring `old_string`;
  mixed `replace_all` true/false within one `MultiEdit`; malformed JSON
  (truncated/non-object/empty); kill-switch unrecognized-value-stays-active;
  absolute + `./`-prefixed path parity with the relative fixture; a
  `Bash`-tool write reaching the same target a `Write`-tool call would.
- `compliance-check.sh` invoked against a rulebook's own `hooks/` dir must
  come back clean before the migration counts as done (per-repo checklist
  step 4).

## Gap line (what this repo already meets vs. what's missing)

Already meets: fail-closed trap shape (byte-identical to
`gate_trap_fail_closed`), stderr-only deny protocol (matches `gate_deny`).
Missing, confirmed by manually applying `compliance-check.sh`'s own two
`grep` rules against this repo's `*-gate.sh` files: (1) `finding-gate.sh`
matches the kill-switch violation pattern (`${VERIFY_FINDING_GATE_OFF:-`
present, `gate_kill_switch_active` absent); `closed-checks-gate.sh` and
`outcome-gate.sh`/`state-guard.sh` have no `_OFF` var at all, so that rule
doesn't fire on them (no kill switch to migrate, not a violation) — adding
one is out of scope per the issue (fix existing defects, not invent new
surface). (2) both `closed-checks-gate.sh` and `finding-gate.sh` match the
reconstruction violation pattern (`.replace(o, nn, 1)` with no
`gate_reconstruct_write` call) — this is the confirmed `replace_all`-ignoring
defect from survey §4, independently corroborated by core's own detector
logic, not just this survey's manual reading.

## Adopt / skip

- Adopt: reference-only sourcing of `gate-lib.sh`/`gate-lib.py` exactly per
  the handbook's usage comment (env-var-defaulted path, never a hardcoded
  relative guess) — this is the issue's explicit "참조 채택, 자체 재구현
  금지" instruction, not a choice.
- Adopt: the six-case mandatory test harness shape, adapted to this repo's
  two migrating gates (finding-gate.sh, closed-checks-gate.sh) plus the
  finding-window adjacency fix (survey §2) and absolute-path case (issue's
  own ask).
- Skip: adding a kill switch to gates that don't have one today
  (`closed-checks-gate.sh`, `outcome-gate.sh`, `state-guard.sh`) — the
  standard fixes existing kill switches, it does not mandate every gate
  carry one, and the issue's remediation list does not ask for new surface.
- Skip: reimplementing `gate_normalize_path`'s symlink-free contract as
  symlink-resolving at the library level — the existing gates' additional
  `os.path.realpath` call is a local choice to keep (call
  `gate_normalize_path` on the realpath'd root, not change the shared
  function), matching the library's own documented call-site contract.

## Segment fit

This is an internal enforcement-hook migration inside one plugin-set repo,
not a market-facing product — the "exemplar" here is core's own already-migrated
gates (issue #72's background says core's own seven gates now all call
`gate_kill_switch_active`) and the landed standard doc itself, both fetched
directly rather than inferred. No external product category applies; skipped
without loss.

Sources:
- https://raw.githubusercontent.com/tokenmaxxxer/tokenmaxxxer-core/main/core/hooks/lib/gate-lib.sh
- https://raw.githubusercontent.com/tokenmaxxxer/tokenmaxxxer-core/main/core/hooks/lib/gate-lib.py
- https://github.com/tokenmaxxxer/tokenmaxxxer-core/blob/main/docs/handbooks/gate-house-standard.md
- https://github.com/tokenmaxxxer/tokenmaxxxer-core/blob/main/core/hooks/tests/compliance-check.sh
- https://github.com/tokenmaxxxer/tokenmaxxxer-core/blob/main/core/hooks/lib/role-directive.sh
