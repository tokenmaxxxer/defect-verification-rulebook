# gate-tests

Current state of `tests/run-gate-tests.sh`.

Exercises the review gates this rulebook still owns locally, as real
subprocesses against `verify/hooks/`:

- `closed-checks-gate.sh` — verify-specific `closed_checks:`-vs-
  `code_under_review:` sha matching. No core counterpart; stays local.

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
