# issue-26 A+ 인증 마감 — phase-2 delivery record

## What was done

Delivered the approved proposal
(`docs/issue-26/proposals/defect-verification-plan.md`) in full: all three
self-devised attempts reproduced against the current checkout, each fixed,
each re-confirmed green.

### Attempt 1 — closed-checks-gate empty-record allow

**Claim tested:** "closed-checks가 빈 record 허용(계약 s20 미강제) 수정 —
deny-only-check green 되게."

**outcome: reproduced**

**evidence:**
```
$ bash tests/deny-only-check.sh verify/hooks
deny-only-check: ok — no permissionDecision allow under verify/hooks
deny-only-check: FAIL — no gate refuses an empty verify record at docs/issue-999/reports/verify.md (contract s20)
```
Direct inspection found the actual gap in
`verify-outcome-gate/hooks/outcome-gate.sh`, not
`verify/hooks/closed-checks-gate.sh`: closed-checks-gate.sh's own
`if not cited: allow()` branch is correct within its own §16
sha-equality scope (nothing cited yet is not a §16 violation). The s20
minimum-record-content gap was outcome-gate.sh's parallel
`if not outcomes: allow()` branch, which let a write with no `outcome:`
field through untouched.

**Fix:** `verify-outcome-gate/hooks/outcome-gate.sh` — `if not outcomes:`
now denies ("record has no outcome: field; contract s20 requires minimum
record content...") instead of allowing.
`verify-outcome-gate/tests/run-gate-tests.sh`'s `no-outcome-field` case
asserted the old (defective) behavior (`run allow no-outcome-field`); it
was pinning the bug, not a correct wanted behavior, so its expectation was
corrected to `run deny no-outcome-field`.

**Re-confirmation (post-fix):**
```
$ bash tests/deny-only-check.sh .
deny-only-check: ok — no permissionDecision allow under .
deny-only-check: ok — outcome-gate.sh refuses the empty record
```

### Attempt 2 — README/install.sh repo-name string

**Claim tested:** "README 1행·install.sh:15의 verify-agent-rulebook 레포명
정정."

**outcome: reproduced**

**evidence:**
```
$ git remote -v
origin  https://github.com/tokenmaxxxer/defect-verification-rulebook.git (fetch)
$ sed -n '1p;79p' README.md
# tokenmaxxxer / verify-agent-rulebook
    claude plugin marketplace add tokenmaxxxer/verify-agent-rulebook
$ sed -n '2p;15p' install.sh
# One-shot installer for the tokenmaxxxer verify-agent-rulebook stack.
GITHUB_REPO="tokenmaxxxer/verify-agent-rulebook"
```
Repo-wide grep confirmed `.claude-plugin/marketplace.json` and all five
`plugin.json` files carry no `verify-agent-rulebook` string (already
correct, per issue-23's prior finding — not re-broken here).

**Fix:** all four locations (`README.md:1`, `README.md:79`,
`install.sh:2`, `install.sh:15`) changed
`tokenmaxxxer/verify-agent-rulebook` → `tokenmaxxxer/defect-verification-rulebook`
(and the install.sh:2 comment's bare `verify-agent-rulebook` →
`defect-verification-rulebook`), matching `git remote -v`.

**Re-confirmation (post-fix):**
```
$ grep -rn "verify-agent-rulebook" README.md install.sh .claude-plugin/marketplace.json */.claude-plugin/plugin.json
(no output — clean)
```

### Attempt 3 — old verify/qa/coding/review naming sweep

**Claim tested:** "marketplace/plugin.json·README의 verify/qa/coding/review
옛 명칭 일괄 정정."

**outcome: reproduced**

**evidence:**
```
$ grep -rnE '[a-z]+-agent-rulebook' --include="*.json" --include="*.md" --include="*.sh" .
docs/README.md:4:following the `doctrine` convention from `coding-agent-rulebook`.
verify/skills/severity-classification/SKILL.md:27:the practice research review-agent-rulebook already established for this
```
(plus the four attempt-2 hits, and this issue's own reports/proposal docs
quoting them — excluded as quotations, not live defects.) A full
repo-wide sweep (not the survey's targeted read) found no
`qa-agent-rulebook` string anywhere, and confirmed
`.claude-plugin/marketplace.json` and every `plugin.json`'s "coding, qa,
and review" mentions are role-descriptive prose (describing which roles'
missed defects `verify` reproduces), not a stale sibling-repo name — those
files needed no change. The two hits above are the entire "옛 명칭"
surface, matching the paired survey's finding C, now confirmed
exhaustively rather than by spot-check.

**Fix:** dropped the stale `-agent-` segment, consistent with this repo's
own rename (`verify-agent-rulebook` → `defect-verification-rulebook` drops
the same segment): `coding-agent-rulebook` → `coding-rulebook`
(`docs/README.md:4`), `review-agent-rulebook` → `review-rulebook`
(`verify/skills/severity-classification/SKILL.md:27`).

**Re-confirmation (post-fix):**
```
$ grep -rEn '[a-z]+-agent-rulebook' docs/README.md verify/skills/severity-classification/SKILL.md
(no output — clean)
```

### Full-suite regression check (all three fixes together)

```
$ bash tests/run-gate-tests.sh
-- verify --                    == verify: 11 passed, 0 failed ==
-- verify-outcome-gate --        == 14 passed, 0 failed ==
-- verify-finding-gate --        == 18 passed, 0 failed ==
-- verify-state-guard --         == 21 passed, 0 failed ==
-- verify-directive-depth --     == 8 passed, 0 failed ==
(72 passed, 0 failed across all five suites)

$ bash tests/deny-only-check.sh .
deny-only-check: ok — no permissionDecision allow under .
deny-only-check: ok — outcome-gate.sh refuses the empty record
```

## Why

Issue #26 names exactly three A+ certification blockers and requires all
three resolved with test/probe evidence recorded before certification can
close: the closed-checks stack's deny-only-check must go green (contract
s20 substance enforcement), the installer/README must name this repo's
real GitHub location instead of its pre-rename name, and stale
`<role>-agent-rulebook` sibling-repo naming must be swept from
docs/skills. All three were independently reproduced against the current
checkout in phase-2 (not re-litigated from any prior review verdict — none
existed to cite, per the phase-1 proposal's `closed_checks` disposition),
then fixed and re-confirmed with the command output quoted above.

## Upstream basis

- Issue #26 body, 2026-08-01 comment (the sole upstream claim source for
  this issue) — quoted verbatim per attempt above.
- `docs/issue-26/reports/defect-verification/current-state-survey.md`
  (this session's own phase-1 survey) and
  `docs/issue-26/proposals/defect-verification-plan.md` (this session's own
  approved phase-1 proposal) — no qa/review record exists for this issue
  to cite; both upstream documents are this role's own phase-1 output,
  human-approved via `APPROVE issue-26/defect-verification`
  (issue #26 comment) before this phase-2 record was written.

loop_state: landed

## Open findings

None. All three attempts reproduced and were resolved in this same pass;
no unresolved `severity: blocking` finding remains open against this
record.

## Next steps / resolution path

N/A — `loop_state: landed` is terminal for this record; no next steps or
resolution path is open. Issue #26 requirement 2 ("sales만 해당: core #78
랜딩 후 착수") does not gate this `defect-verification` subject.
