# issue-20 current-state survey (defect-verification, grade B audit)

Scope: every gate/directive/test file across `verify/`, `verify-finding-gate/`,
`verify-outcome-gate/`, `verify-state-guard/`, `verify-directive-depth/`,
`tests/`. Findings below are reproduced directly (commands run against this
checkout), not inferred from the issue text.

## 1. Shipped suite is 1/7 on main (confirmed, root cause identified)

`bash tests/run-gate-tests.sh` on this checkout: 3+7+8+9 pass across
`verify`/`verify-outcome-gate`/`verify-finding-gate`/`verify-state-guard`, then
`verify-directive-depth`: **1 passed, 6 failed**. Root cause, reproduced
directly:

```
$ CLAUDE_ROLE=defect-verification bash verify-directive-depth/hooks/directive.sh
.../directive.sh: line 3: cd: verify-directive-depth/hooks/../../core: No such file or directory
.../directive.sh: line 3: /hooks/lib/role-directive.sh: No such file or directory
.../directive.sh: line 8: core_role_directive: command not found
```

`verify-directive-depth/hooks/directive.sh` line 3 sources
`${CLAUDE_PLUGIN_ROOT_CORE:-<plugin>/../../core}/hooks/lib/role-directive.sh`.
This repo does not vendor `core/` (it is a separate installed plugin at
runtime); the test harness never sets `CLAUDE_PLUGIN_ROOT_CORE`, so the
fallback path resolves to a sibling `core/` directory that does not exist in
this checkout, the source fails, `core_role_directive` is undefined, and the
script errors before producing any of the 6 substring markers the test
greps for. Only `kill-switch:empty-output` passes, and only because the
kill-switch branch (line 2) returns before the broken `source` line ever
runs — it is testing the early-exit, not the fix. This is the "삭제된 core
의존 참조" the issue names: not a deleted file, but a source path with no
test-environment fallback and a test harness that exercises the script
without ever providing one.

`tests/stub-check.sh` (run separately) independently flags the same file:
`directive.sh`'s own `case "${VERIFY_DIRECTIVE_DEPTH_OFF:-}" in ...` kill
switch line is reported as "regrown boilerplate" — `core_role_directive`
(core/hooks/lib/role-directive.sh, fetched from tokenmaxxxer-core@main) has
already absorbed an equivalent per-role kill switch
(`<ROLE>_CYCLE_OFF`), so this repo's own copy is drift on top of drift.

`stub-check.sh` also flags a second, unrelated defect: `tests/parse-check.sh`
is a vendored copy of a file core now ships as its own hook
(`core/hooks/hooks.json`), i.e. this repo's copy is stale drift per
`canon-scripts.md`'s reference-not-copy rule — same defect class the issue's
precondition (core issue #72) exists to stop, just against a different core
canon file (`parse-check.sh` rather than `gate-lib.sh`).

## 2. Finding window is forward-only (confirmed, matches comment's own stated intent)

`verify-finding-gate/hooks/finding-gate.sh`, `window_for()`: the docstring
above it says the search window includes "a small lookback to the previous
heading, since `finding:` blocks ... are written adjacent to (immediately
after) the `outcome:` line" — but the implementation only computes a forward
bound (`start = outcomes[idx].start()`; `end` = next section boundary or next
`outcome:`). There is no lookback at all; the comment describes behavior the
code does not have. Net effect: `verdict:`/`addressed_to:`/`severity:` fields
placed **before** the `outcome: reproduced` line inside the same logical
attempt block (a natural template ordering — `finding:` fields first, then a
trailing `outcome:` note, or fields interleaved by a MultiEdit) are invisible
to the check and the gate allows the write regardless of whether they exist.
The plugin's own 8/8 green test suite does not catch this because every
fixture places the finding fields strictly after `outcome:` — the suite
never covers the ordering the code's own comment claims to handle.

## 3. Semantic checks are substring-only, not section/adjacency-aware

Three field checks across `closed-checks-gate.sh` and `finding-gate.sh` use
un-anchored regex extraction over the *entire* reconstructed document body,
not any section or attempt boundary:

- `closed-checks-gate.sh`: `re.findall(r'^\s*-?\s*code_sha\s*:\s*...', new_text, re.M)`
  and the `code_under_review`/`upstream_code_sha` extraction both scan the
  whole file. A `code_sha:` line anywhere in the document (e.g. quoted
  inside an unrelated prior attempt, a comment, or copy-pasted example text)
  is treated as a live `closed_checks` citation.
- `finding-gate.sh`'s per-attempt window (bug #2 above) is the *only* place
  in this codebase that even attempts section/adjacency scoping; the other
  three field regexes inside that same window (`verdict`, `addressed_to`,
  `severity`) are correct once the window is fixed, but the window itself is
  broken.
- No gate distinguishes "the word `blocking` appears somewhere in the
  document" from "the word `blocking` is the value of *this* attempt's
  `severity:` field" beyond the (currently forward-only) window — i.e. the
  adopted methodology's fields can be satisfied by mentioning the right
  words anywhere near, rather than inside, the record structure that
  contract v3 s19/finding-record actually defines.
- `tests/deny-only-check.sh`'s "substance probe" (an empty `verify.md`
  record with content `"nothing here"`, a synthetic `docs/issue-999/reports/`
  path) is run against every `*-gate.sh` in `verify/hooks/`; on this
  checkout it reports **FAIL — no gate refuses an empty verify record**.
  None of the three plugins' gates require that a record contain *any*
  structural content at all when no `outcome:`/`closed_checks:` field is
  present yet — an empty or field-free write is allowed through by every
  gate uniformly, which is a defensible early-lifecycle allow but is also
  exactly the gap a "mention passes" bypass would exploit before ever
  writing a real `outcome:` line.

## 4. Gate mechanics not yet on the gate-house standard (core issue #72, landed)

None of this repo's gates (`closed-checks-gate.sh`, `finding-gate.sh`,
`outcome-gate.sh`, `state-guard.sh`) source `core/hooks/lib/gate-lib.sh` or
load `gate-lib.py`. Each hand-rolls the same four shapes `gate-lib`
canonicalizes, with the same defect classes core's own audit (issue #72)
found and fixed in its own gates:

- **Fail-closed trap**: present in all four (`__fc`/`trap ... EXIT`), textually
  identical to `gate_trap_fail_closed`'s body — mechanically equivalent, not
  yet delegated.
- **Kill switch**: `finding-gate.sh` (`VERIFY_FINDING_GATE_OFF`) and
  `directive.sh` (`VERIFY_DIRECTIVE_DEPTH_OFF`) both use the *pre-issue-72*
  idiom — `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac` — the exact
  bug `gate_kill_switch_active` exists to fix: any unrecognized value
  (a typo, an unexpected string) takes the `*)` branch and **disables** the
  gate, rather than staying active. `closed-checks-gate.sh` and
  `outcome-gate.sh`/`state-guard.sh` carry no kill switch at all today
  (out of scope to add one where none exists; in scope to fix the two that
  do).
- **JSON parse**: `closed-checks-gate.sh` and `finding-gate.sh` each inline
  their own `try: json.loads(...) except ValueError: deny(...)` — equivalent
  to `gate_parse_json_or_deny`, not sourced from it.
- **Path normalize**: both gates inline `posixpath.normpath` +
  `os.path.realpath` + manual prefix-stripping against `root` — equivalent to
  `gate_normalize_path`, not sourced from it, and diverges from it in one
  respect: the local code additionally calls `os.path.realpath` (symlink
  resolution), which `gate_normalize_path` deliberately does not do (its
  docstring says callers needing that should realpath `root` themselves
  first). A straight swap-in needs to preserve that behavior at the call
  site, not silently drop it.
- **Write reconstruction — confirmed `replace_all` bug**: both gates'
  `Edit`/`MultiEdit` branches call `current.replace(old, new, 1)`
  unconditionally — **first occurrence only**, never reading
  `tool_input.get("replace_all")** at all. This is the identical defect
  `gate_reconstruct_write`/`_apply_replace` was written to fix in
  `record-fields-gate.sh` (core issue #72's own background section). A
  `replace_all: true` Edit against a multiply-occurring `old_string` (e.g.
  changing every `outcome: reproducing` to `outcome: reproduced` in one call)
  is reconstructed here as only the *first* instance changing — the gate
  then evaluates stale content for every subsequent occurrence.
  `MultiEdit`'s per-edit `replace_all` is equally ignored (also hardcoded to
  `1`). Neither gate reconstructs `NotebookEdit` at all (falls through to
  `new_text is None` → deny), where `gate_reconstruct_write` already handles
  the insert/replace cell-source case.
- **Deny protocol**: both gates already write to stderr and `exit 2`
  (`deny()` helper) — behaviorally equivalent to `gate_deny`, not yet
  sourced from it, but not a live defect (issue's "deny 사유 stderr 전달"
  requirement is already met in current code; the gap is duplication, not
  missing behavior).
- No `compliance-check.sh`-equivalent run exists against this repo's own
  hooks today (core ships it at
  `core/hooks/tests/compliance-check.sh`, invoked per-repo per the
  gate-house-standard migration checklist) — this repo has never been
  checked against it.

## 5. README drift (not yet inventoried in detail — phase-1 scope note)

Issue asks README be reconciled with the real plugin set (ghost files
removed, real plugins/paths/kill-switches documented). Full line-by-line
README diff is phase-2 work (a documentation-sync task, not a design
decision); this survey confirms the plugin set that must be the source of
truth: `verify`, `verify-finding-gate`, `verify-outcome-gate`,
`verify-state-guard`, `verify-directive-depth`, plus root-level `tests/`.
Phase-2 will diff `README.md` against this list and each plugin's actual
kill-switch env var name before editing it.

## Gaps this survey leaves for scout to aim at

- What does core's own `compliance-check.sh` actually flag when run against
  this repo's `verify*/hooks/`? (mechanical: run it, but core issue #72's
  landed shape/contract needs confirming first — scout target.)
- Whether any of the 43 sibling rulebooks already completed an equivalent
  gate-lib migration this repo can pattern-match against for call-site shape
  (scout target — precedent, not invention).
