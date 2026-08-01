# issue-23 gate A+ final remediation — proposal

**Phase-1 proposal only. No code, gate script, `hooks.json`, `install.sh`,
`README.md`, or manifest changes are made by this PR. Phase-2 execution
opens only after a human APPROVE per contract v3 s19.**

files phase-2 will touch (not touched by this PR):
`verify-state-guard/hooks/state-guard.sh`, `verify-state-guard/hooks/hooks.json`,
`verify/hooks/hooks.json`, `install.sh`, `verify-state-guard/tests/run-gate-tests.sh`,
`tests/run-gate-tests.sh` and the other four suites (missing-core case),
`README.md` (only if the phase-2 repo-wide grep finds a stray reference —
see D5).

## Request (paraphrased intent)

A 2026-08-01 re-audit graded this rulebook C: eight named defects, of which
core #75 (gate-lib source guard + missing-core test + `gate_bash_write_targets`
port) and on-the-record #182 (`CLAUDE_PLUGIN_ROOT_CORE` injection in spawn)
are named as common preconditions to land first. Requirement: fix every
surviving defect (reusing core #75's confirmed guard/rules for the common
items), make `hooks.json` matchers and code's tool coverage fully consistent
(advertised/tested branches must be reachable in production), ship the full
suite green including a missing-core case with a recorded
`compliance-check` pass, and drive old role names/ghost files in
README/manifest to zero.

## Survey outcome summary

Of the 8 defects, **7 are confirmed real** and **1 is stale**
(`docs/issue-23/reports/defect-verification/current-state-survey.md`):

| # | Defect | Verdict |
|---|---|---|
| 1 | Production core reference unverifiable (fixture-only green) | confirmed |
| 2 | state-guard not migrated (gate-lib, kill-switch, replace_all, resolve_root) | confirmed |
| 3 | Window/clamp only clamps reproduced/cleared (false-allow) | confirmed |
| 4 | install.sh installs 1/5 | confirmed |
| 5 | README old repo name | **stale** — already fixed by issue-20's phase-2 (commit `7ee99a4`); skipped below |
| 6 | Bash matcher not registered | confirmed |
| 7 | Fixture canon drift undetected | confirmed |
| 8 | Missing-core mandatory test absent | confirmed |

Defects #1/#7/#8 share one root cause (every test harness unconditionally
pins `CLAUDE_PLUGIN_ROOT_CORE` to the checked-in fixture) and are addressed
together below (D1).

## Constraints

- C1 (precondition): core #75's and on-the-record #182's exact landed guard
  shape is not inspectable from this repo's filesystem or by network from
  this session (survey precondition-check section). Phase-2 must re-confirm
  core #75's actual function surface against the installed `core` plugin
  before writing the missing-core guard/test — this proposal names the
  *pattern* (`CLAUDE_PLUGIN_ROOT_CORE`-defaulted source line, fail-closed on
  a missing/unreadable target) it must satisfy, not invented function names
  for #75-only additions.
- C2 (survey §2): `state-guard.sh`'s non-migration is not a partial gap —
  issue-20 never touched this file (its file list omits it). This is a
  from-scratch migration of the same kind already done three times in this
  repo, not a new design.
- C3 (survey §2, scout-brief §2): `verify-state-guard/` is installable
  independently of `verify/` (five separate marketplace entries, each
  self-contained per README). The migrated `state-guard.sh` must not source
  `verify/hooks/_gate-common.sh` across the plugin boundary — it inlines
  `gate_normalize_path`/realpath-root calls per gate-lib's own pattern, the
  same way the other three already-migrated gates each do independently.
- C4 (survey §3, scout-brief §3): the false-allow is that only
  `reproduced`/`cleared` are clamped against `highest_state`; `reproducing`
  passes through unchecked. The fix generalizes the existing single-purpose
  check into one regression check applied to every recognized `new_state`,
  not a new state model.
- C5 (survey §6, scout-brief §4): `closed-checks-gate.sh`'s `Bash` branch is
  already implemented and tested (`cc-bash-write-target` case) but
  unreachable because `verify/hooks/hooks.json`'s matcher omits `Bash`.
  Adding `Bash` to `verify-state-guard/hooks/hooks.json`'s matcher is
  contingent on `state-guard.sh` itself growing `Bash` handling as part of
  its gate-lib migration (C2) — otherwise the matcher change alone would
  route `Bash` calls into code that falls through to `allow()`, a silent
  no-op gate rather than a fix. `verify-finding-gate`/`verify-outcome-gate`
  are out of scope: neither gate's code has any `Bash` branch, and the
  issue's requirement is reachability of what already exists, not new
  Bash-surface invention.
- C6 (survey §4): `install.sh`'s `PLUGINS` array names one plugin
  (`verify`); README's manual install section already lists all five
  correctly, so the fix is `install.sh`-only, aligning it to the same five
  entries README already documents.
- C7 (survey §5): README's old-repo-name defect is stale for the file this
  survey targeted (`README.md` itself matches `install.sh`/`marketplace.json`
  exactly). It is not dropped outright — phase-2 does one repo-wide grep for
  stray old-name/ghost-file strings (the survey's targeted read is not a
  substitute for a full sweep) before closing requirement #4, but no README
  rewrite is proposed here absent a phase-2 grep hit.

## Design (phase-1 direction, phase-2 executes)

**D1 — Missing-core mandatory test + fixture-drift guard (closes #1, #7, #8).**
Add one new case to each of the five test suites
(`tests/run-gate-tests.sh`, `verify-outcome-gate/`, `verify-finding-gate/`,
`verify-state-guard/` (post-C2), `verify-directive-depth/`) that invokes the
gate/directive with `CLAUDE_PLUGIN_ROOT_CORE` **unset** and no fallback
`core/` directory present (a scratch dir with no sibling `core/`), asserting
the fail-closed contract each already documents ("FAIL-CLOSED: ...an
unresolvable project root...") extends to a genuinely missing core: deny (or
a clearly labeled early, non-zero, informative exit), never a silent
allow and never an uninformative crash. This is the concrete missing-core
mandatory case the issue names. Separately, re-confirm — as part of
phase-2's closing step, mirroring issue-20 proposal item 7 — that
`tests/fixtures/core-compliance-check.sh` and `tests/fixtures/core/hooks/lib/*`
are re-synced against the actually-installed core plugin's current output
before the missing-core test is written, so the new test is not itself
exercising a stale fixture.

**D2 — state-guard gate-lib migration (closes #2).**
`verify-state-guard/hooks/state-guard.sh`: source
`${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh` exactly as the three
already-migrated gates do; replace the hand-rolled trap with
`gate_trap_fail_closed`; replace the fail-open `case ... esac` kill switch
with `gate_kill_switch_active "${VERIFY_STATE_GUARD_OFF:-}"`; replace the
inline JSON parse with `gate_parse_json_or_deny`; replace the inline path
normalize with `gate_normalize_path` called against a realpath'd `root`
(per issue-20's C6 pattern — `gate_normalize_path` itself is deliberately
non-symlink-resolving); replace the unconditional
`current.replace(o, nn, 1)` Edit/MultiEdit reconstruction with
`gate_reconstruct_write`, which already honors per-edit `replace_all` and
reconstructs `NotebookEdit`. Per C3, this is done inline (sourcing
`gate-lib.sh` directly), not by reaching into `verify/hooks/_gate-common.sh`.
The `loop_state` ordering/blocking-finding logic itself is untouched by this
step — D3 handles it.

**D3 — Window/clamp generalization (closes #3).**
In the same file, generalize the skip-ahead check from:

```python
if new_state in ("reproduced", "cleared") and highest_rank < RANKS["reproducing"]:
    deny(...)
```

to a check applied to every recognized `new_state`:

```python
if RANKS[new_state] < highest_rank:
    deny("... loop_state may not regress from a previously recorded state ...")
if new_state in ("reproduced", "cleared") and highest_rank < RANKS["reproducing"]:
    deny(...)  # existing skip-ahead check, unchanged
```

(exact variable names/branch shape to be confirmed against the file at
phase-2 time — this is the direction, not a diff). Add fixtures for the case
the current suite never exercises: a record at `highest_state: cleared`
attempting to write `loop_state: reproducing` again, asserting deny.

**D4 — install.sh fixed to the real five-plugin set (closes #4).**
`PLUGINS=(verify)` becomes the five plugins README's `Install` section
already lists: `verify`, `verify-finding-gate`, `verify-outcome-gate`,
`verify-state-guard`, `verify-directive-depth`. The install/update loops
already iterate `"${PLUGINS[@]}"` generically, so this is a data change to
the array, not new control flow — matching the same install order the
README already documents.

**D5 — Manifest/README sweep (closes remaining piece of requirement #4).**
Run one repo-wide grep for old bundle/role-name strings and ghost-file
references across `README.md`, `.claude-plugin/marketplace.json`, and every
`verify*/.claude-plugin/plugin.json`, per C7. If it finds nothing (as this
survey's targeted read already suggests), record that explicitly as the
delivery evidence for requirement #4's README/manifest clause rather than
silently skipping it. If it finds something, fix it as a direct, narrow
edit (not a rewrite) — this is documentation-sync, not a design decision.

**D6 — hooks.json matcher fix (closes #6).**
Add `Bash` to `verify/hooks/hooks.json`'s `PreToolUse` matcher:
`"Write|Edit|MultiEdit|NotebookEdit|Bash"`. Add the same to
`verify-state-guard/hooks/hooks.json`'s matcher **only after** D2 lands
`state-guard.sh`'s own `Bash` handling (per C5) — sequenced so no matcher
ever routes a tool call into a script blind to it. `verify-finding-gate`/
`verify-outcome-gate` matchers are left unchanged (no `Bash` branch in
either gate's code; out of scope per C5).

**D7 — Compliance close-out (closes remainder of requirement #3).**
Phase-2 ends by running core's `compliance-check.sh` (the real one, against
the actually-installed core plugin, not the pinned fixture copy) against
every `verify*/hooks/` directory and recording clean output as delivery
evidence in `docs/issue-23/reports/defect-verification.md` (that record file
is phase-2-only; not created by this PR).

## Test plan (phase-2)

- New: missing-core case per gate/directive suite (D1), ×5 suites.
- New: `state-guard.sh`'s own suite gains the gate-lib-migration mandatory
  cases already established as this repo's own precedent (issue-20 design
  item 5): `Edit`+`replace_all: true` against a multiply-occurring
  `old_string`; `MultiEdit` mixing `replace_all` true/false; malformed JSON;
  kill-switch set to an unrecognized value asserting the gate **stays
  active**; absolute vs `./`-prefixed path equivalence; a `Bash`-tool write
  reaching the same target a `Write` call would (via `gate_bash_write_targets`,
  now reachable per D6).
- New: `loop_state` regression case — `cleared` then `reproducing` again,
  asserting deny (D3).
- Updated: `tests/run-gate-tests.sh`'s suite list already invokes
  `verify-state-guard/tests/run-gate-tests.sh` as a subprocess — no new
  wiring needed there once that suite itself grows.
- Full suite green (all five plugins) plus a recorded `compliance-check.sh`
  pass against the real installed core (D7) is the delivery gate for
  requirement #3.

## Non-goals

- Reimplementing any part of core's gate-lib/role-directive — reference
  only, per `docs/handbooks/canon-scripts.md`'s reference-not-copy rule,
  same as the three already-migrated gates.
- Adding `Bash` matcher/handling to `verify-finding-gate`/`verify-outcome-gate`
  — no code path there needs it (C5).
- A README rewrite absent a phase-2 grep hit (C7/D5) — the targeted survey
  read found the file already correct.
- Any change to core's own repo, or to on-the-record's spawn.py — both are
  consumed by reference/precondition only.

## Open question for the approver

None on defect scope or fix shape — all seven confirmed defects have a
determined fix direction from this repo's own already-migrated gates
(gate-lib pattern) or from the defect's own code (window/clamp,
matcher/hooks.json, install.sh array). The one genuinely unresolved item —
core #75's and on-the-record #182's exact landed guard/test shape — is not
a design choice for a human to pick between; it is a fact phase-2 must
re-confirm against the installed core plugin before coding the missing-core
guard specifics, and is called out as such (C1) rather than left silently
assumed.
