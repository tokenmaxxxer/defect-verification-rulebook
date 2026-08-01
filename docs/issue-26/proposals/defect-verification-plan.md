# issue-26 defect-verification — phase-1 attempt-list promise

**Phase-1 proposal only. No gate script, `hooks.json`, `install.sh`,
`README.md`, manifest, or `docs/issue-26/reports/defect-verification.md`
(the phase-2 record) is touched by this PR. Phase-2 opens only after a
human `APPROVE issue-26/defect-verification` per contract v3 s19.**

`code_under_review: b0ed3fd6e8ee4c3758b5cd0a7b955c747f43f80b`.

`closed_checks` disposition: none available to cite — see the paired
survey's "closed_checks entries: none available to cite" section. Every
attempt below will be freshly derived against the current checkout in
phase 2; nothing is cited-and-skipped.

## Sources for this attempt list

- Issue #26 body (`gh issue view 26`), 2026-08-01 comment, the only
  upstream claim source for this issue — quoted verbatim per attempt below.
- Direct code inspection performed in phase-1 survey (self-devised paths,
  labeled as such — no qa/review record exists to cite from, per survey).

## Attempt list (the promise — not executed here)

### Attempt 1 — closed-checks-gate empty-record allow (self-devised path)

**Claim tested (issue #26 verbatim):** "closed-checks가 빈 record 허용(계약
s20 미강제) 수정 — deny-only-check green 되게" ("closed-checks allows an
empty record [contract s20 not enforced] — fix so the deny-only-check goes
green").

**Basis:** self-devised, from direct inspection of
`verify/hooks/closed-checks-gate.sh`'s `if not cited: allow()` branch
(quoted in the paired survey, finding A) — no qa/review report names this
line number; the issue names the behavior class, this attempt traces it to
the exact code path.

**Phase-2 shape (not run here):** locate or construct the repo's
"deny-only-check" probe/test this issue refers to (search
`tests/`/`verify*/tests/` for an existing case name matching
"deny-only"/"empty"/"s20"; if none exists, that absence is itself part of
the reproduction finding, not something phase-2 invents a fix for), run it
against the current gate, and record reproduced/not-reproduced with the
actual command output as evidence — never a re-derivation of review's
verdict, since no review verdict on this line exists to re-litigate.

### Attempt 2 — README/install.sh repo-name string (self-devised path)

**Claim tested (issue #26 verbatim):** "README 1행·install.sh:15의
verify-agent-rulebook 레포명 정정" ("correct the verify-agent-rulebook repo
name at README line 1 and install.sh:15").

**Basis:** self-devised, from direct inspection this session: `git remote
-v` on this checkout resolves `origin` to
`tokenmaxxxer/defect-verification-rulebook`, while `README.md:1`,
`README.md:79`, `install.sh:2`, and `install.sh:15` all read
`tokenmaxxxer/verify-agent-rulebook` (quoted in the paired survey, finding
B). No qa/review record names these four line numbers; this attempt
re-derives the mismatch directly.

**Phase-2 shape (not run here):** confirm the four locations verbatim
against the live checkout at `code_under_review`, confirm no other file
(`.claude-plugin/marketplace.json`, five `plugin.json` files) carries the
same stale string (this survey already checked those and found them
`tokenmaxxxer-verify`-named, not repo-name strings — to be re-confirmed,
not assumed, in phase 2), and record reproduced/not-reproduced with the
grep output as evidence.

### Attempt 3 — old verify/qa/coding/review naming sweep (self-devised path)

**Claim tested (issue #26 verbatim):** "marketplace/plugin.json·README의
verify/qa/coding/review 옛 명칭 일괄 정정" ("bulk-correct the old
verify/qa/coding/review names in marketplace/plugin.json/README").

**Basis:** self-devised, from a direct grep this session finding
`docs/README.md:4` ("`coding-agent-rulebook`") and
`verify/skills/severity-classification/SKILL.md:27`
("review-agent-rulebook") — old `<role>-agent-rulebook` sibling-repo names,
quoted in the paired survey, finding C. This survey's targeted read found
no `qa-agent-rulebook` string and found `marketplace.json`/`plugin.json`'s
"coding, qa, and review" mentions to be role-descriptive prose, not a stale
name — that reading itself is only a survey-time observation, to be
re-confirmed (not assumed) by phase-2's own repo-wide sweep, since a
targeted read is not a substitute for one, per this repo's own established
practice (issue-23 proposal C7 made the identical distinction for its
README sweep).

**Phase-2 shape (not run here):** one repo-wide grep across the full
checkout (not just the files this survey targeted) for
`<role>-agent-rulebook` and any other old-naming pattern the issue's
"일괄" ("bulk") wording implies must be swept rather than spot-checked;
record every hit found (or the clean-sweep result if none beyond B/C above)
as reproduced/not-reproduced with the grep output as evidence.

## code_under_review and closed_checks disposition (summary)

- `code_under_review: b0ed3fd6e8ee4c3758b5cd0a7b955c747f43f80b`.
- `closed_checks` cited-and-skip: none.
- `closed_checks` to be re-derived: none exist to re-derive from (no prior
  `verify.md`/`defect-verification.md` record closes a check against this
  sha) — all three attempts above are fresh, self-devised reproduction
  paths against the current checkout, not re-litigations of any qa/review
  verdict (none exists) and not a holistic quality judgment.

## Non-goals (phase 1)

- No fix to `closed-checks-gate.sh`, `README.md`, `install.sh`,
  `marketplace.json`, or any `plugin.json`/`SKILL.md` file — that is
  phase-2, gated on human APPROVE.
- No reproduced/not-reproduced verdict recorded anywhere — that belongs in
  `docs/issue-26/reports/defect-verification.md`, a phase-2-only file not
  created by this PR.
- No re-litigation of any review or qa verdict — none exists for this
  issue to re-litigate; all three attempts are either issue-text-sourced
  claims or explicitly labeled self-devised paths.

## Open question for the approver

None on attempt scope or source — all three attempts trace verbatim to
issue #26's own named blocking reasons, each anchored to a specific,
already-located file/line this session read directly. The only genuinely
open item is whether an existing "deny-only-check" test/probe already
exists under this repo's test trees for attempt 1 to run against, or
whether phase-2 must first locate/name it before reproduction — not a
design choice for a human to pick between, a fact phase-2 confirms before
recording an outcome.
