# issue-26 current-state survey (defect-verification, A+ audit closure)

`code_under_review: b0ed3fd6e8ee4c3758b5cd0a7b955c747f43f80b` (`HEAD` of
`main` at survey time, tip of `deliver(defect-verification): phase-2 gate A+
final remediation (issue #23) (#25)`).

Scope: the three blocking reasons named in issue #26's 2026-08-01 comment
only —

1. `closed-checks-gate.sh` allows an empty/no-`closed_checks` record write
   (contract s20 not enforced), stated as needed so a "deny-only-check"
   probe goes green.
2. README's line 1 and `install.sh:15` repo-name string.
3. Old `verify/qa/coding/review` naming in `marketplace.json`/README (and,
   read literally, any plugin manifest/skill doc carrying it).

No qa or review record exists for this repo scoped to issue #26 or issue #23
to cite from — `find docs -iname '*qa*' -o -iname '*coding*' -o -iname
'*review*'` (repo-root, this checkout) returns only `docs/issue-6/**` and
`docs/issue-8/**`, both unrelated precedent proposals from a different role
line, not qa/review verdicts about the current gate-house state. This
repo's own convention for the `verify`/`defect-verification` role is
`docs/issue-<n>/reports/defect-verification.md` (this role's own record),
not a separate qa/review artifact — see `docs/issue-23/reports/
defect-verification.md`'s "Upstream basis" section, which cites only an
issue-comment `APPROVE` and its own paired proposal/survey, no qa/review
file. Issue #26's own body is therefore the only upstream source naming
these three defects; all three attempts below are self-devised, built from
directly reading the current checkout, not cited from a prior qa/review
verdict.

## closed_checks entries: none available to cite

`docs/issue-23/reports/defect-verification.md` (`loop_state: landed`) lists
`## Open findings` → "None." — it closes no `closed_checks:` entries at all
(the record schema's `closed_checks:` field belongs to `verify`'s own
record file, `docs/issue-<n>/reports/verify.md` per `closed-checks-gate.sh`'s
own `REC_PATTERN`; issue-23's phase-2 delivery record is a different,
role-specific `defect-verification.md` shape carrying no such block). There
is nothing to cite-and-skip for issue #26: every attempt below will be
freshly derived by inspection/execution against the current checkout, none
carried over uninspected from a prior record.

## Direct-inspection findings (self-devised, read from disk this session)

### A. `closed-checks-gate.sh` empty-`closed_checks` allow

`verify/hooks/closed-checks-gate.sh` (embedded Python judge): after
extracting every `code_sha` token inside each `closed_checks:` block via
`block_re`/`boundary_re`, the code reads:

```python
if not cited:
    allow()
```

i.e. a record write reconstructing to content with no `closed_checks:`
block at all, or a `closed_checks:` block present but containing zero
`code_sha:` lines, is allowed unconditionally — no check that the record
otherwise satisfies contract s20's minimum-content requirement (per
`docs/issue-11/reports/defect-verification/current-state-survey.md` item 4,
s20 is "enforces minimum record content"; terminal state `cleared` reachable
only with no unresolved blocking finding or an explicit waiver). This gate
never inspects `loop_state` or minimum-field presence at all — its whole
mandate per its own header comment is the closed_checks/code_under_review
sha-equality rule (s16), not s20. Whether an s20-shaped "deny-only-check"
probe is expected to fail here, and whether s20 enforcement belongs in this
gate or a sibling one, is exactly what phase-2 attempt 1 (below) will
determine — not assumed here.

### B. Repo-name string mismatch

`git remote -v` (this checkout): `origin` →
`https://github.com/tokenmaxxxer/defect-verification-rulebook.git`. But:

- `README.md:1` — `# tokenmaxxxer / verify-agent-rulebook`
- `README.md:79` — `claude plugin marketplace add tokenmaxxxer/verify-agent-rulebook`
- `install.sh:2` — `# One-shot installer for the tokenmaxxxer verify-agent-rulebook stack.`
- `install.sh:15` — `GITHUB_REPO="tokenmaxxxer/verify-agent-rulebook"`

All four read `verify-agent-rulebook`; the actual repo is
`defect-verification-rulebook`. `docs/issue-23/reports/defect-verification/
current-state-survey.md` (§5, "NOT CONFIRMED — appears already fixed,
STALE") had checked this string only for *internal consistency*
(README/install.sh/marketplace.json agreeing with each other), not against
`git remote -v` — so issue-23's "stale" verdict on the repo-name defect
did not catch this mismatch; it is a live, reproducible-by-inspection
defect, distinct from what issue-23 checked.

### C. Old `verify/qa/coding/review` naming

Direct grep of this checkout for old sibling-repo naming convention
(`<role>-agent-rulebook`, the same pattern as defect B above, extended to
the other three roles):

- `docs/README.md:4` — "following the `doctrine` convention from
  `coding-agent-rulebook`."
- `verify/skills/severity-classification/SKILL.md:27` — "mirroring the
  practice research review-agent-rulebook already established for this
  org's use of severity"

No `qa-agent-rulebook` string was found in this checkout
(`.claude-plugin/marketplace.json`, `README.md`, all five `plugin.json`
files, `docs/README.md`, and the skills tree were the files read this
session). `.claude-plugin/marketplace.json` and every `plugin.json`'s
`description` field mention "coding, qa, and review" only as prose
describing the *roles* whose missed defects `verify` reproduces (e.g.
`verify/.claude-plugin/plugin.json`: "adversarial reproduction of defects
that coding, qa, and review all missed") — that phrasing names roles, not
a stale sibling-repo string, and is not itself a defect under this reading.
Whether a `qa-agent-rulebook`-shaped string exists somewhere this survey's
targeted read did not cover, and what the corrected name for each sibling
repo should be, is left to phase-2 attempt 3's own repo-wide sweep — not
assumed here.

## Scouting — skip record

Skipped: this is a verification-attempt enumeration task tracing an
issue-body's named blocking reasons against the current checkout (a
closed_checks/record-shape gate defect, a repo-name string defect, and an
old-naming string defect), not a product design decision with an open
field for a scout to survey design-space alternatives on. There is no
design choice being scouted here — phase-1's only output is a promise of
which attempts phase-2 will run and against which sources, per contract
v3 s19's defect-verification phase-1 shape.

## Write set for this PR (phase 1 only)

- `docs/issue-26/reports/defect-verification/current-state-survey.md` (this file).
- `docs/issue-26/proposals/defect-verification-plan.md`.

No file under `verify*/`, `docs/decisions/`, `docs/handbooks/`, or
`docs/issue-26/reports/defect-verification.md` (the phase-2 record) is
touched by this PR.
