# issue-23 current-state survey (defect-verification, re-audit grade C)

Scope: every gate/directive/test/install/manifest file across `verify/`,
`verify-finding-gate/`, `verify-outcome-gate/`, `verify-state-guard/`,
`verify-directive-depth/`, `tests/`, `install.sh`, `README.md`,
`.claude-plugin/marketplace.json`. Findings below are read directly from
this checkout, not inferred from the issue text. Where the 2026-08-01
re-audit's claim does not match what is actually on disk, it is called out
as stale rather than carried forward uncritically — issue-20's phase-2
delivery (commit `7ee99a4`) already landed real fixes to three of the five
plugins, so a re-audit can legitimately be partly out of date.

## Precondition check (core #75, on-the-record #182)

This repo has no `.gitmodules`, no vendored `core/` directory, and no
network access to `tokenmaxxxer/tokenmaxxxer-core` or
`tokenmaxxxer/on-the-record` from this checkout. The only local evidence of
core's gate-house standard is:

- `tests/fixtures/core/hooks/lib/{gate-lib.sh,gate-lib.py,role-directive.sh}` —
  a **pinned fixture copy**, checked in for deterministic offline testing
  (per this repo's own README: "pinned core gate-lib.sh/gate-lib.py/
  role-directive.sh ... so the suite runs deterministically without a live
  core plugin install").
- Every production gate that already migrated
  (`verify/hooks/closed-checks-gate.sh`, `verify-finding-gate/hooks/finding-gate.sh`,
  `verify-outcome-gate/hooks/outcome-gate.sh`, `verify-directive-depth/hooks/directive.sh`)
  sources `${CLAUDE_PLUGIN_ROOT_CORE:-<plugin>/../../core}/hooks/lib/{gate-lib.sh,role-directive.sh}`
  — a real plugin-relative reference, not a copy — confirming the *shape*
  of core's expected layout (`hooks/lib/gate-lib.sh`, `hooks/lib/gate-lib.py`,
  `hooks/lib/role-directive.sh`) that issue-20's proposal already
  documented from core issue #72.

**Conclusion**: the exact function surface of core #75 (a stricter source
guard, `compliance-check.sh` detection of it, a missing-core mandatory test,
and a `gate_bash_write_targets` Python port) cannot be directly inspected in
this filesystem — core #75 and on-the-record #182 are outside this repo's
tree and this survey has no network access to them. This is treated as a
**documented assumption**: the proposal below applies core's *already-visible*
local pattern (`CLAUDE_PLUGIN_ROOT_CORE`-defaulted sourcing,
`gate_bash_write_targets` used by `closed-checks-gate.sh` today) and does not
invent unverified function names for the #75-only additions. Phase-2 must
re-confirm core #75's landed shape directly against the installed core
plugin before writing code, not from this survey alone.

## 1. Production core reference cannot actually be exercised (CONFIRMED)

Every test harness in this repo — `tests/run-gate-tests.sh`,
`verify-outcome-gate/tests/run-gate-tests.sh`,
`verify-finding-gate/tests/run-gate-tests.sh`,
`verify-directive-depth/tests/directive-depth-test.sh` — unconditionally
sets `CLAUDE_PLUGIN_ROOT_CORE="$CORE_FIXTURE"` (the pinned fixture under
`tests/fixtures/core`) before invoking every gate/directive subprocess.
`verify-state-guard/tests/run-gate-tests.sh` never references
`CLAUDE_PLUGIN_ROOT_CORE`/`CORE_FIXTURE` at all (consistent with §2: it
never sources gate-lib to begin with).

No test in this repo ever runs a gate/directive against a real installed
`core` plugin, and no test ever leaves `CLAUDE_PLUGIN_ROOT_CORE` unset while
also removing the fixture to exercise the documented fallback path
(`<plugin>/../../core`) or its absence. The suite is green only against a
fixture that is asserted to match core's landed shape, never verified to
match it. This is exactly the "fixture로만 green" defect the issue names.

## 2. state-guard not migrated at all (CONFIRMED, four sub-defects)

`verify-state-guard/hooks/state-guard.sh` is the one gate in this repo's
five plugins that issue-20 never touched (its proposal's file list at the
top names `closed-checks-gate.sh`, `finding-gate.sh`, `directive.sh`,
`tests/*`, `README.md` — `state-guard.sh` is absent from that list). It
still stands exactly where the original grade-B audit found the other three
gates before remediation:

- **gate-lib not adopted**: no `. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh"`
  line anywhere in the file; it hand-rolls its own `__fc`/`trap ... EXIT`
  fail-closed trap, its own inline `json.loads` parse, and its own path
  normalization — the same defect class core issue #72 (and this repo's own
  `verify/hooks/closed-checks-gate.sh`, already migrated) fixed everywhere
  else.
- **kill-switch fail-open**: lines 5-7 —
  `case "${VERIFY_STATE_GUARD_OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac`
  — the pre-issue-72 idiom `gate_kill_switch_active` exists to replace: any
  unrecognized value (a typo, an unexpected string) takes the `*)` branch
  and disables the gate rather than staying active. Identical to the bug
  issue-20 fixed in `finding-gate.sh`, left unfixed here.
- **`replace_all` bug**: the embedded Python's `Edit` branch calls
  `current.replace(o, nn, 1)` unconditionally (first occurrence only,
  `tool_input.get("replace_all")` never read); the `MultiEdit` branch does
  the same per-edit (`t.replace(o, nn, 1)`, no `replace_all` check). Same
  defect issue-20 fixed via `gate_reconstruct_write` in the other two gates,
  left unfixed here. `NotebookEdit` is not reconstructed at all (falls
  through to `new_text is None` → deny, same gap the other gates had before
  migration).
- **`resolve_root` copied, not referenced**: `state-guard.sh` defines its
  own `_gate_plausible_root`/`resolve_root` functions inline (lines ~40-58),
  byte-for-byte structurally identical to `verify/hooks/_gate-common.sh`'s
  `resolve_root` (which `closed-checks-gate.sh` sources via
  `. "$HERE/_gate-common.sh"`). This is drift-by-copy of a shared helper
  that already lives in a sourceable file in this same repo — a smaller
  instance of the same "reference, never copy" violation core issue #72 and
  `docs/handbooks/canon-scripts.md` target.

## 3. Window/clamp logic only clamps on "reproduced"/"cleared" (CONFIRMED, false-allow demonstrated)

`state-guard.sh`'s only ordering check is:

```python
if new_state in ("reproduced", "cleared") and highest_rank < RANKS["reproducing"]:
    deny(...)
```

This clamps exactly two transitions (declaring `reproduced` or `cleared`
with no recorded prior `reproducing`) and nothing else. It does not enforce
general monotonic, forward-only ordering against the recorded
`highest_state`: a write declaring `loop_state: reproducing` is `allow()`d
unconditionally regardless of `highest_state` (no check against `highest_rank`
at all for that value), so a record already at `highest_state: cleared` can
freely write `loop_state: reproducing` again with no denial — a regression
the state-order contract ("idle < reproducing < reproduced < cleared,
forward-only") is supposed to forbid. This is the "창 로직이 reproduced만
클램프" defect: only the two named target states are checked; `reproducing`
itself is a clamp-free pass-through, so the false-allow is real and
reproducible by inspection of the code (not merely by claim).

## 4. install.sh installs 1/5 (CONFIRMED)

`install.sh`: `PLUGINS=(verify)` — the loop `for plugin in "${PLUGINS[@]}"`
installs only `verify@tokenmaxxxer-verify`, then separately installs
`$BUNDLE@$MARKET` (`verify@tokenmaxxxer-verify` again — `BUNDLE="verify"`,
same plugin). `verify-finding-gate`, `verify-outcome-gate`,
`verify-state-guard`, `verify-directive-depth` are never named anywhere in
`install.sh`. Of the marketplace's five listed plugins
(`.claude-plugin/marketplace.json`), the script installs exactly one —
1/5, matching the issue's claim exactly. (README's own manual `Install`
section, by contrast, already lists all five `claude plugin install`
commands correctly — the drift is `install.sh`-only.)

## 5. README references an old repo name (NOT CONFIRMED — appears already fixed, STALE)

`README.md` line 1 reads `# tokenmaxxxer / verify-agent-rulebook`, and its
`Install` section (`git`/`claude plugin marketplace add
tokenmaxxxer/verify-agent-rulebook`) matches `install.sh`'s own
`GITHUB_REPO="tokenmaxxxer/verify-agent-rulebook"` and
`marketplace.json`'s `"name": "tokenmaxxxer-verify"` exactly. No occurrence
of an older repo/bundle name, no ghost-file reference (the file list under
"What is here" matches the five actual `verify*/` directories plus
`tests/`), and no `43`-taxonomy old-name string was found anywhere in
`README.md`, `.claude-plugin/marketplace.json`, or the five plugins'
`.claude-plugin/plugin.json` files. Issue-20's phase-2 delivery (item 6 of
its proposal, "README sync") appears to have already closed this
specifically for README. **Verdict: stale as far as README.md is
concerned** — carried into the proposal as skipped-because-stale, with a
note that the issue's broader "manifest" wording is still worth one more
pass (see Gaps below) since a repo-wide grep, not a targeted read, is the
only way to be fully certain no stray reference exists.

## 6. Bash matcher not registered in hooks.json (CONFIRMED)

`verify/hooks/hooks.json` and `verify-state-guard/hooks/hooks.json` both
declare `"matcher": "Write|Edit|MultiEdit|NotebookEdit"` for their
`PreToolUse` hook — `Bash` is absent from every `hooks.json` matcher in this
repo (also checked: `verify-finding-gate/hooks/hooks.json`,
`verify-outcome-gate/hooks/hooks.json`, both `Write|Edit|MultiEdit|NotebookEdit`
only). Yet `verify/hooks/closed-checks-gate.sh` contains a full `Bash`-tool
branch (`if tool == "Bash": ... gate_bash_write_targets(command) ...
deny(...)`), advertised in its own header comment ("PreToolUse hook
(Write|Edit|MultiEdit|NotebookEdit|**Bash**)") and exercised by
`tests/run-gate-tests.sh`'s `cc-bash-write-target` case — which invokes the
script directly, bypassing `hooks.json` entirely. In production, Claude
Code's PreToolUse dispatch never routes a `Bash` tool call to this hook at
all, because the matcher never lists `Bash`. The tested branch is
unreachable in the real gate-house: this is the exact "광고·테스트된 분기가
프로덕션에서 도달 가능해야 함" gap named in the issue's requirement #2.

## 7. Fixture canon drift undetected (CONFIRMED)

Consequence of §1: because every test always substitutes the pinned
`tests/fixtures/core` copy for the real core plugin, nothing in this repo's
suite would ever notice if that pinned copy fell out of sync with core's
actual landed `gate-lib.sh`/`gate-lib.py`/`role-directive.sh` (e.g. after
core issue #75 lands new guard behavior upstream). There is no checksum,
version pin, or `compliance-check.sh`-style structural check comparing the
fixture against a real core checkout — `tests/fixtures/core-compliance-check.sh`
is itself a **pinned copy** of core's `compliance-check.sh` detector (same
drift risk, one level up: the detector script itself could silently go
stale against core's real detector). No record in this repo currently shows
`compliance-check.sh` having been run against this repo's actual `hooks/`
dirs and its output kept as delivery evidence (issue-20's proposal item 7
flagged this as the closing step of *that* delivery; nothing here shows it
was executed and recorded).

## 8. Missing-core mandatory test case absent (CONFIRMED)

No test file in this repo (`tests/run-gate-tests.sh`,
`verify-outcome-gate/tests/run-gate-tests.sh`,
`verify-finding-gate/tests/run-gate-tests.sh`,
`verify-directive-depth/tests/directive-depth-test.sh`,
`verify-state-guard/tests/run-gate-tests.sh`) contains a case that unsets
`CLAUDE_PLUGIN_ROOT_CORE`, points it at a nonexistent path, or otherwise
simulates "core plugin not installed" to assert the gate/directive
fail-closed (deny/refuse) rather than crash uninformatively or silently
allow. Every invocation in every suite pins `CORE_FIXTURE`. This is the
same root gap as §1/§7 viewed from the test-authoring side, and is called
out separately because the issue names it as an explicit required case,
not just a byproduct of §1.

## Gaps this survey leaves for scout to aim at

- Core #75's and on-the-record #182's exact landed function/guard shape —
  outside this repo's tree, not independently confirmable here; phase-2
  must re-check against the actually-installed core plugin before coding.
- Whether any stray old-name/ghost-file reference exists outside the files
  this survey targeted (`README.md`, `marketplace.json`, `plugin.json`×5) —
  a full repo-wide grep for old bundle/role names is worth one more pass in
  phase-2 before closing requirement #4 (manifest cleanup), even though the
  targeted read here found nothing.
- The precise shape of core's missing-core mandatory test pattern (if core
  #75 ships one for its own gates) that this repo's phase-2 test additions
  should mirror, rather than invent independently.
