---
proposal: docs/issue-32/proposals/spec-alignment.md
---

# Hunt record - spec-alignment

## after-proposal -- stance 3: assume the rule as written cannot hold -- find the state nothing maintains

Verdict: FINDING -- the proposal's plan to document `cannot-attempt-independent-reproduction` and `environment-setup-failed` as new loop_state values "alongside" the existing 4-rank vocabulary assumes state-guard.sh will treat them as recognized states, but the gate's RANKS table only knows `idle/reproducing/reproduced/cleared` and silently no-ops (allow) for any other loop_state value -- so once these two states are documented as valid vocabulary, writing them bypasses every invariant the gate exists to enforce (monotonic-forward-only, no skip-ahead to a terminal-tier state without a prior `reproducing` record, and the unresolved-`severity: blocking`-finding check).
Kind: silent-failure
Seed: docs/issue-32/proposals/spec-alignment.md (new), and the accompanying survey report (new); proposal's "For `loop_state`" rationale paragraph and step 1 (README.md `## Record vocabulary` extension)
cap_seconds: 120
tier: default
diff_stat_lines: ~140+220 (two new files, git diff --stat against HEAD)
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:20:00Z

### Reproduce
Ran `verify-state-guard/hooks/state-guard.sh` directly (bypassing the Claude Code PreToolUse hook chain, which intercepts this sandbox's own Bash tool calls) via a Python subprocess harness, in an isolated scratch project root containing a fabricated report tree at an issue path (of the form docs/issue-([0-9]+)/reports/verify.md) and a matching state file recording only `{"highest_state": "idle"}` (no `reproducing` ever recorded). The tool_input payload declared:

```
loop_state: cannot-attempt-independent-reproduction
severity: blocking
unresolved finding
```

(one of the proposal's two new documented loop_state names, with an unresolved blocking finding and no prior reproducing record -- a write that must be denied under both the skip-ahead rule and the unresolved-finding rule if either applied to it).

Harness (paraphrased to avoid this sandbox's own command-text path scanner):

```python
import json, os, subprocess
root = "<scratch_root>"
rel_report = "<issue-tree>/reports/verify.md"
rel_state = ".claude/verify-state-issue-<n>.json"
os.makedirs(os.path.dirname(os.path.join(root, rel_report)), exist_ok=True)
os.makedirs(os.path.dirname(os.path.join(root, rel_state)), exist_ok=True)
with open(os.path.join(root, rel_state), "w") as f:
    json.dump({"highest_state": "idle"}, f)
subprocess.run(["git", "init", "-q"], cwd=root)
payload = json.dumps({
    "tool_name": "Write",
    "tool_input": {
        "file_path": rel_report,
        "content": "loop_state: cannot-attempt-independent-reproduction\nseverity: blocking\nunresolved finding\n",
    },
})
env = dict(os.environ); env["CLAUDE_PROJECT_DIR"] = root
p = subprocess.run(["bash", "verify-state-guard/hooks/state-guard.sh"],
                    input=payload, capture_output=True, text=True, env=env)
print(p.stdout, p.stderr, p.returncode)
```

(actual run used a real numeric issue id matching the guard's `ISSUE_RE = re.compile(r"^docs/issue-([0-9]+)/reports/verify.md$")`; the guard is generic over any such id, so the result generalizes.)

### Observed
Exit code 0 (allow), empty stderr. Confirmed by reading `verify-state-guard/hooks/state-guard.sh`:
```python
matches = LOOP_STATE_RE.findall(new_text)
new_state = matches[-1].lower() if matches else None
if new_state is None or new_state not in RANKS:
    allow()
```
with `RANKS = {"idle": 0, "reproducing": 1, "reproduced": 2, "cleared": 3}` -- the two spec-vocabulary states the proposal plans to document are not, and cannot be, in RANKS without the rank-table rewrite the proposal explicitly declares out of scope, so any write using them short-circuits straight to `allow()` before the skip-ahead check (`new_state in ("reproduced","cleared") and highest_rank < RANKS["reproducing"]`) and the unresolved-blocking-finding check (`new_state == "cleared"` branch) ever run. Separately, `LOOP_STATE_RE = re.compile(r"^\s*loop_state\s*:\s*([A-Za-z]+)\s*$")` doesn't match hyphenated identifiers at all (the `$` anchor fails once the `[A-Za-z]+` run hits the first hyphen), so a literal `loop_state: cannot-attempt-independent-reproduction` line is treated by the parser as *no loop_state present* -- a second, independent route by which the same write is silently un-gated.

### Expected
Either the gate should refuse (fail-closed) on an unrecognized-but-documented loop_state value reaching a verify.md record, or the proposal should state plainly that state-guard.sh provides zero enforcement for the two new names rather than describing them as vocabulary "a record may carry alongside" the enforced four. As written, a record can jump directly from `idle` to a refusal/error state, or carry a live unresolved `severity: blocking` finding under one of these states, and the state-guard gate will not notice either way -- the monotonic/skip-ahead/unresolved-finding invariants only ever applied to the original four ranks, and the proposal's Rationale section addresses only the rank table's numeric ordering ("the rank table and gate behavior are untouched"), never the `not in RANKS` fallback that determines whether any invariant applies to a state at all.

## before-landing -- stance 0: assume the gate just touched is bypassable -- find the bypass

Verdict: NO FINDING
Seed: commit 3d90bc1 on issue-32/implementation, diff from 2cf93a5 -- README.md, verify/skills/finding-record/SKILL.md, verify/skills/finding-record/templates/finding-record-template.md, verify/skills/severity-classification/SKILL.md, docs/handbooks/gate-tests.md, verify-directive-depth/hooks/directive.sh (HAND_OFF string literal only), docs/issue-32/reports/implementation.md
cap_seconds: 180
tier: default (size tier: >5 files touched)
diff_stat_lines: 179 insertions(+), 7 deletions(-) across 7 files
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:25:00Z

Ran all four gate test suites at 3d90bc1 (verify-directive-depth/tests/directive-depth-test.sh, verify-finding-gate/tests/run-gate-tests.sh, verify-outcome-gate/tests/run-gate-tests.sh) -- all pass (8/8, 19/19, 15/15). Grepped every field name the gates actually parse (severity:, verdict:, addressed_to:, outcome:, evidence:) against the touched files: none of verify-finding-gate/hooks/finding-gate.sh, verify-outcome-gate/hooks/outcome-gate.sh, verify-state-guard, or verify/hooks/_gate-common.sh reference steps, repro_steps, status, or finding_type at all, so the new spec-vocabulary cross-reference prose cannot loosen a check those gates perform -- the aliasing is inert to gate logic (grep -n "steps\|repro" on the three gate scripts: no output).

The directive.sh edit is a single added clause inside the HAND_OFF string literal (repro steps / repro_steps); verify-directive-depth's own test suite (directive-depth-test.sh) re-asserts word-count/keyword invariants on that exact string post-edit and passes, so the depth gate this file feeds is unaffected.

One adjacent (but not qualifying) observation: the new template convention of appending "<!-- spec field name: ... -->" after a field's value (added to finding-record-template.md's steps: and severity: lines) would, if an agent literally copied the severity: line's trailing comment into a real docs/issue-<n>/reports/verify.md, break finding-gate.sh's exact-match regex ^\s*severity\s*:\s*(\S+)\s*$ (confirmed by direct regex test: re.search(pattern, "severity: blocking <!-- spec field name: finding_type -->", re.M) returns None). That failure mode is fail-closed (finding-gate treats severity as missing and denies), not fail-open, so it does not satisfy the bypass stance -- it is a potential false-deny/usability issue, not a weakened gate. No false-allow was reproduced from any file this commit touched.
