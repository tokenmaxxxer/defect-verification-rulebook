# gate-tests

Current state of `tests/run-gate-tests.sh`.

Exercises the review gates this rulebook still owns locally, as real
subprocesses against `verify/hooks/`:

- `closed-checks-gate.sh` — verify-specific `closed_checks:`-vs-
  `code_under_review:` sha matching. No core counterpart; stays local.
  As of issue-20, sources core's `gate-lib.sh`/`gate-lib.py` (issue #72)
  instead of hand-rolling trap/JSON-parse/path-normalize/reconstruct; the
  harness passes `CLAUDE_PLUGIN_ROOT_CORE` pointing at
  `tests/fixtures/core/` (a pinned copy of the gate-house standard) so this
  runs deterministically without a live core plugin install.

Since issue-17's phase-2 delivery, it also runs each of the four sibling
`verify-*` plugins' own self-contained test suite as a subprocess
(`verify-outcome-gate/tests/run-gate-tests.sh`,
`verify-finding-gate/tests/run-gate-tests.sh`,
`verify-state-guard/tests/run-gate-tests.sh`,
`verify-directive-depth/tests/directive-depth-test.sh`) and exits non-zero
if any suite fails — each plugin's tests stay independently runnable, this
is aggregation only, never shared test code between plugins. As of
issue-20, `verify-outcome-gate` and `verify-finding-gate`'s own suites also
migrated onto the same `gate-lib` fixture and set
`CLAUDE_PLUGIN_ROOT_CORE`/`CLAUDE_ROLE` the same way; `verify-directive-depth`'s
`directive-depth-test.sh` does the same for `core_role_directive`.

Mandatory cases as of issue-20 (added to the top-level harness and to
`verify-outcome-gate`'s and `verify-finding-gate`'s own suites):
Edit+`replace_all: true` against a multiply-occurring `old_string`,
MultiEdit mixing `replace_all` true/false in one call, malformed/empty
JSON, kill-switch set to an unrecognized value (asserts the gate stays
active — `gate_kill_switch_active`'s contract), absolute and
`./`-prefixed path variants matching the same fixture, and a Bash-tool
write reaching the guarded path (`gate_bash_write_targets`, denied
fail-closed since the gate cannot inspect a shell command's effect on
file content).

The three role-agnostic gates this harness used to exercise directly
(`trailer-gate.sh`, `record-fields-gate.sh`, `handbook-trigger-gate.sh`)
were dropped from `verify/hooks/` (issue-12): core's own `hooks.json`
(`PreToolUse` matcher `.*`) fires its canon copies of these for every
plugin install, and core's issue-66 landing added its own test coverage
for them. This harness no longer duplicates that coverage.

As of issue-23, every suite also carries one missing-core mandatory case:
`CLAUDE_PLUGIN_ROOT_CORE` unset and no fallback `core/` directory present
(this checkout has none at its root), asserting the `||`-guarded gate-lib
source (core issue #75) fails closed — deny or a non-zero, informative
exit — rather than crash-uninformatively or silently allow. `verify-state-guard`'s
own suite gained the full mandatory-case set the other three already had
(malformed/empty JSON, kill-switch, path variants, replace_all,
Bash-write-target) now that `state-guard.sh` sources `gate-lib.sh` too
(issue-23 D2), plus a `loop_state` regression case (`cleared` then
`reproducing` again, asserting deny — issue-23 D3).

`tests/stub-check.sh` (vendored verbatim from core) covers the rest of
`verify/hooks/`'s post-transition shape: no reintroduced vendored copies of
canon gates, and every remaining hook file parses under bash 3.2.
`tests/parse-check.sh` was itself flagged by `stub-check.sh` as vendored
drift of a now-core-owned hook and was deleted outright (issue-20 C2) —
`tests/fixtures/core-compliance-check.sh` (a pinned copy of core's
`compliance-check.sh`, issue #72) is run manually against each plugin's
`hooks/` dir as delivery evidence instead, not wired into this harness (it
is not a pass/fail assertion suite the way the others are).
