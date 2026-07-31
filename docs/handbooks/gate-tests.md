# gate-tests

Current state of `tests/run-gate-tests.sh`.

Exercises the review gates this rulebook still owns locally, as real
subprocesses against `verify/hooks/`:

- `closed-checks-gate.sh` — verify-specific `closed_checks:`-vs-
  `code_under_review:` sha matching. No core counterpart; stays local.

Since issue-17's phase-2 delivery, it also runs each of the four sibling
`verify-*` plugins' own self-contained test suite as a subprocess
(`verify-outcome-gate/tests/run-gate-tests.sh`,
`verify-finding-gate/tests/run-gate-tests.sh`,
`verify-state-guard/tests/run-gate-tests.sh`,
`verify-directive-depth/tests/directive-depth-test.sh`) and exits non-zero
if any suite fails — each plugin's tests stay independently runnable, this
is aggregation only, never shared test code between plugins.

The three role-agnostic gates this harness used to exercise directly
(`trailer-gate.sh`, `record-fields-gate.sh`, `handbook-trigger-gate.sh`)
were dropped from `verify/hooks/` (issue-12): core's own `hooks.json`
(`PreToolUse` matcher `.*`) fires its canon copies of these for every
plugin install, and core's issue-66 landing added its own test coverage
for them. This harness no longer duplicates that coverage.

`tests/stub-check.sh` (vendored verbatim from core) and `tests/
parse-check.sh` cover the rest of `verify/hooks/`'s post-transition shape:
no reintroduced vendored copies of canon gates, and every remaining hook
file parses under bash 3.2.
