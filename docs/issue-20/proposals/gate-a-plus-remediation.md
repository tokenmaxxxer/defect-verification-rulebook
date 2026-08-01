# issue-20 gate A+ remediation — proposal

files (phase 2 only, not touched by this PR): `verify/hooks/closed-checks-gate.sh`,
`verify-finding-gate/hooks/finding-gate.sh`, `verify-directive-depth/hooks/directive.sh`,
`tests/stub-check.sh`-flagged `tests/parse-check.sh` (delete), `tests/run-gate-tests.sh`,
`verify-finding-gate/tests/run-gate-tests.sh`, `verify/tests/*` (new six-case harness),
`README.md`

## Request (paraphrased intent)

A 2026-08-01 audit graded this rulebook's gates B: the gate shapes
themselves (fail-closed trap, three-value outcome set, severity banding)
are already top-tier, but two concrete defects sit under that design —
the shipped suite is 1/7 green on main, and the finding-fields check is
forward-only, so it can be satisfied by fields placed anywhere convenient
rather than inside the attempt they belong to. The issue asks all of it
fixed to A+ across every axis: path matching, fail-closed depth,
Edit/MultiEdit/`replace_all` reconstruction, deny-reason stderr delivery,
semantic checks upgraded from substring to section/adjacency/structure,
mandatory new test cases, green suite at delivery, and a README that
matches the real plugin set — with the explicit precondition that this
work adopts core's now-landed gate-house standard (`gate-lib.sh`/
`gate-lib.py`, issue #72) by reference, never by reimplementation.

## Constraints

- C1 (survey §1): the 1/7 failure is not a deleted file — it is
  `verify-directive-depth/hooks/directive.sh` sourcing a `core/`-relative
  fallback path that does not exist in this checkout, with a test harness
  that never sets `CLAUDE_PLUGIN_ROOT_CORE` to give it one. Fixing this is
  a test-environment/fallback fix, not a design decision: the source line
  itself already follows core's own documented usage pattern.
- C2 (survey §1, `stub-check.sh`): the same file's kill-switch case
  statement is independently flagged as regrown boilerplate on top of
  `core_role_directive`'s own per-role kill switch — remediation must
  remove the local duplicate, not patch it in place. `tests/parse-check.sh`
  is separately flagged as vendored drift of a now-core-owned hook and
  must be deleted outright (not modified) per `canon-scripts.md`'s
  reference-not-copy rule — same defect class the issue's core precondition
  exists to stop, so this PR fixes it too rather than leaving a second,
  adjacent instance of exactly what issue #72 targeted.
- C3 (survey §2): the finding-window bug is not "no adjacency check
  exists" — a per-attempt window already exists in
  `finding-gate.sh:window_for()`, and its own docstring already states the
  correct two-sided contract ("a small lookback to the previous heading").
  The fix is completing what the comment already promises: bound the
  window on **both** sides (previous section boundary through next section
  boundary, clipped at neighboring `outcome:` lines the same way the
  forward bound already is), not inventing a new scoping mechanism.
- C4 (survey §4, scout must-be): core issue #72 landed
  `core/hooks/lib/gate-lib.sh` + `gate-lib.py`, its own
  `compliance-check.sh` detector, and a mandatory six-case test harness
  shape — this repo's two field-reconstructing gates
  (`closed-checks-gate.sh`, `finding-gate.sh`) both independently trip
  `compliance-check.sh`'s own reconstruction-violation rule (confirmed by
  applying that rule's exact `grep` pattern by hand, scout-brief gap
  line), and `finding-gate.sh` trips its kill-switch rule too. The issue's
  explicit instruction ("자체 재구현 금지") makes sourcing the library the
  only compliant fix, not a design choice among alternatives.
- C5 (scout adopt/skip): gates without a kill switch today
  (`closed-checks-gate.sh`, `outcome-gate.sh`, `state-guard.sh`) get no new
  one — the standard fixes existing switches, it does not mandate every
  gate carry one, and the issue's remediation list names existing defects
  to fix, not new surface to add.
- C6 (survey §4): `gate_normalize_path` is deliberately non-symlink-resolving
  (its own docstring: callers needing that should realpath their `root`
  first) while both local gates currently call `os.path.realpath` on the
  full candidate path. The swap must preserve today's symlink-resolving
  behavior by realpath-ing `root` (once, at gate startup) and calling
  `gate_normalize_path(realpath(root), path)`, not by silently dropping
  symlink resolution to match the library's bare contract.
- C7 (survey §3, `deny-only-check.sh`): the empty-record substance probe
  already fails on this repo today (no gate refuses a field-free
  `verify.md` write) — this is pre-existing and out of this issue's
  explicit ask list (which names path-matching, fail-closed depth,
  Edit/MultiEdit/`replace_all`, deny-stderr, semantic-section-upgrade, and
  README, not "require non-empty records"); noted so phase-2 doesn't
  silently fold in unscoped hardening, and flagged as a candidate for a
  future issue rather than smuggled into this one.

## Design (phase-1 direction, phase-2 executes)

1. **Gate-lib migration** (`closed-checks-gate.sh`, `finding-gate.sh`):
   replace the inline JSON-parse/path-normalize/reconstruct trio with
   `gate_parse_json_or_deny`, `gate_normalize_path` (per C6's realpath-root
   pattern), and `gate_reconstruct_write`, sourced/loaded exactly per the
   handbook's usage comment (`CLAUDE_PLUGIN_ROOT_CORE`-defaulted path for
   the shell half; `GATE_LIB_PY` env var + `importlib` for the Python
   half — `gate-lib.sh` already exports `GATE_LIB_PY` when sourced, so no
   new env plumbing is needed). `finding-gate.sh`'s hand-rolled kill switch
   becomes `gate_kill_switch_active`. This closes C4/C1's `replace_all` bug
   directly: `gate_reconstruct_write` already honors per-edit `replace_all`
   and reconstructs `NotebookEdit`, which neither gate does today.
2. **Directive-depth fix** (`directive.sh` + its test): fix the
   `CLAUDE_PLUGIN_ROOT_CORE` fallback resolution so the test harness can
   exercise it deterministically (set the env var in
   `directive-depth-test.sh` to a real core checkout path or a fixture
   `core/` the test provisions, rather than relying on an ambient sibling
   directory that may not exist), and drop the local kill-switch case
   statement per C2 in favor of `core_role_directive`'s own
   `<ROLE>_CYCLE_OFF` handling — the test then asserts against
   `<ROLE>_CYCLE_OFF`, not a bespoke `VERIFY_DIRECTIVE_DEPTH_OFF`. Delete
   `tests/parse-check.sh` outright (C2).
3. **Finding-window two-sided bound** (`finding-gate.sh:window_for`): extend
   `section_bounds` scanning to also record the nearest boundary **before**
   each `outcome:` match (not just after), so `verdict:`/`addressed_to:`/
   `severity:` fields preceding `outcome: reproduced` within the same
   attempt block are visible to the check, per C3. Add fixtures for
   fields-before-outcome and fields-interleaved-via-MultiEdit orderings —
   this is exactly the case the current 8/8-green suite never exercises
   (survey §2), so a green suite alone would not have caught this class
   without the new cases.
4. **Semantic upgrade beyond finding-gate**
   (`closed-checks-gate.sh`): anchor the `code_sha`/`code_under_review`
   extraction to the same document-structure boundaries used by the
   finding window, rather than scanning the whole reconstructed body — a
   `closed_checks:` block's `code_sha:` lines are read only from within
   that block's own extent (from its `closed_checks:` line to the next
   top-level field or heading), so a `code_sha:`-shaped string elsewhere in
   the document (a quoted prior attempt, an example) is not mistaken for a
   live citation.
5. **Mandatory test cases** (issue's explicit list, mapped onto the
   gate-lib standard's own six-case shape from the scout brief):
   `Edit`+`replace_all: true` against a multiply-occurring `old_string`;
   `MultiEdit` mixing `replace_all: true`/`false` in one call; malformed
   JSON (truncated/non-object/empty); kill-switch set to an unrecognized
   value asserting the gate **stays active**; absolute `file_path` plus a
   `./`-prefixed variant matching the same relative-path fixture; a
   `Bash`-tool write reaching the same target a `Write` call would (via
   `gate_bash_write_targets`, currently unused by any gate here — adding
   Bash-surface coverage is itself part of "경로 매칭 완결" per the issue).
   Applied to both migrating gates' own suites plus the fixed
   `finding-gate.sh` window cases from point 3.
6. **README sync**: rebuilt from the actual plugin set confirmed by this
   survey (`verify`, `verify-finding-gate`, `verify-outcome-gate`,
   `verify-state-guard`, `verify-directive-depth`, root `tests/`), each
   with its real kill-switch env var name and hook path — a line-by-line
   diff against current `README.md` is phase-2 execution, not a design
   decision.
7. **Compliance close-out**: phase-2 ends by running core's
   `compliance-check.sh` against this repo's `hooks/` dirs and recording
   clean output as delivery evidence, per the gate-house standard's own
   per-repo migration checklist (step 4/5) — this is the closing
   verification the issue's precondition already prescribes, not new
   scope invented here.

## Non-goals

- Adding a kill switch to gates that have none today (C5).
- Fixing the pre-existing empty-record substance-probe gap (C7) — flagged
  as a follow-up candidate, not folded into this delivery.
- Any change to core's own repo — `gate-lib.sh`/`gate-lib.py` are consumed
  by reference only, never copied or modified here.

## Open question for the approver

None — the design is fully determined by (a) the issue's explicit defect
list, (b) the already-landed gate-house standard's function surface, and
(c) this repo's own `stub-check.sh`/`deny-only-check.sh` findings. No
judgment call requiring a human pick remains open.
