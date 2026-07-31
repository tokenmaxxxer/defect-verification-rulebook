# issue-11 scout brief — defect-verification domain norms

Mode: **live web search** (WebSearch tool available and used this session;
all queries and consulted sources listed below — not a knowledge-only
fallback).

## Must-bes (findings a viable proposal cannot ignore)

- **Severity ≠ priority** (ISTQB): severity is the technical/impact rating
  of the defect (objective-ish, testable-position), priority is fix
  urgency (a business call, not tester's to set). This role only ever
  emits `severity`, never `priority` — priority is coding's/PM's call once
  a finding lands, and the rulebook must not blur the two.
- **A reproduction/incident report needs a fixed evidentiary shape**
  (IEEE 829 Test Incident Report / its ISO/IEC/IEEE 29119-3 successor):
  incident description, steps to reproduce, expected vs. actual result,
  severity, and an impact assessment — a free-text "evidence" pointer
  without a fixed steps/expected/actual shape under-specifies what a
  reproduction attempt must contain to be judged.
- **Severity scoring must be deterministic, not averaged** (Microsoft SDL
  replaced DREAD's averaged score for being "too subjective and
  inconsistently scored" — same critique this repo's own
  `severity-classification` skill already cites). Any new severity content
  must preserve, not regress, that already-adopted deterministic-lookup
  discipline.
- **Root-cause tools (5 Whys, Ishikawa) drill into *why*, not *whether***:
  Fishbone organizes candidate causes, 5 Whys drills to a root cause,
  verification audits then confirm the fix worked — these are causal/fix
  methodologies. This role's mandate ("whether a defect exists... never a
  fix") means root-cause analysis is out of scope for verify's own attempt
  record; the finding's `rationale` field connects evidence to a verdict,
  not to a causal chain.
- **Reproduction attempts need a repeat/isolation discipline for
  nondeterministic defects** (Google's flaky-test practice): a single
  failing run is not conclusive either way for a suspected-flaky defect;
  best practice is a repeated-run count (their guidance: dozens of runs
  for common flakes, hundreds for rare ones) plus captured failure
  artifacts, not one-shot pass/fail.
- **Triage requires steps-to-reproduce before proceeding, not after**
  (Mozilla Bugzilla triage: an incoming bug lacking repro steps is bounced
  back with a needinfo before triage continues) — an attempt with no
  reproducible path is a state to flag explicitly, not silently drop or
  silently mark not-reproduced.

## Performance axes (what a good defect-verification deliverable optimizes for)

1. Evidentiary traceability (verdict must point at a concrete artifact).
2. Deterministic, auditable severity (same inputs → same band, always).
3. Clear separation of "does it reproduce" from "how bad" from "how urgent."
4. No silent gaps (every attempt taken up gets a recorded outcome, even
   an inconclusive/needs-repro-info one).

## Adopt / skip

- **Adopt**: IEEE 829/29119-3-style fixed attempt shape (precondition /
  steps / expected / actual, in addition to the current single `evidence`
  pointer field) for phase-2 finding-record.
- **Adopt**: explicit severity-vs-priority boundary statement (verify sets
  severity only) as a phase-2 directive line — currently implicit, not
  explicit, in `directive.sh`.
- **Adopt**: a named "inconclusive / needs-repro-info" outcome distinct
  from `not-reproduced`, so an attempt blocked on missing repro access
  (already described in prose in `finding-record`'s SKILL.md "what it asks
  the user for" section) gets a first-class recorded state rather than
  being folded into a binary outcome set.
- **Adopt**: a repeat-run/isolation note for any attempt suspected of
  nondeterminism, recorded as part of that attempt's evidence.
- **Adopt**, for phase 1 itself: a fixed proposal shape (request/
  constraints/plan/out-of-scope/how-it'll-be-known-to-work, the shape this
  repo's own issue-6/8/12 proposals already converged on) plus a mandatory
  scout-brief with a Sources: list, formalized as the norm rather than
  left as convention.
- **Skip**: DREAD (averaged score) — already rejected by this repo's
  existing `severity-classification` skill, confirmed still correct by
  this sweep.
- **Skip**: root-cause methodology (5 Whys/Ishikawa) as verify's own
  required deliverable content — out of role scope, belongs to coding's
  fix, not verify's finding.
- **Skip**: full IEEE 829 test-plan-level document set (test plan, test
  design spec, test case spec, etc.) — over-scoped; only the Test
  Incident Report's fixed-shape idea is relevant to this role's per-attempt
  record, not the whole standard's document suite.

## Gap vs. current state

Current state (per `current-state-survey.md`) already has: deterministic
severity lookup, evidence-or-refused, own-reproduction basis, two-value
outcome set, `finding` schema with verdict/rationale. Missing relative to
this sweep: fixed steps/expected-actual attempt shape, an explicit
severity-vs-priority scope statement, a first-class inconclusive/needs-info
outcome, and a repeat-run discipline for suspected-nondeterministic
defects. None of these require touching `severity-classification`'s
already-sourced band logic.

## Sweep mode note

Ran as four sequential WebSearch calls (not parallel tool calls) — topics:
IEEE 829/incident-report structure, ISTQB defect life-cycle & severity vs.
priority, 5 Whys/Ishikawa root-cause tooling, Google/Mozilla practitioner
triage and flaky-test reproduction practice. Each returned multiple
consistent secondary sources; no primary IEEE/ISO standard text itself was
fetched (paywalled), so IEEE 829 claims above rest on secondary summaries
of it, flagged as such.

## Sources

- https://en.wikipedia.org/wiki/Software_test_documentation
- https://www.stickyminds.com/article/software-test-incident-report-ieee-829-1998-format-template
- https://www.professionalqa.com/ieee-standard-829-1998
- https://www.toolsqa.com/software-testing/severity-vs-priority/
- http://istqbrm.blogspot.com/2014/07/defect-priority-and-severity.html
- http://istqbrm.blogspot.com/2014/07/defect-life-cycle.html
- https://www.isixsigma.com/cause-effect/root-cause-analysis-ishikawa-diagrams-and-the-5-whys/
- https://easyrca.com/blog/root-cause-and-effect-analysis-5-whys-vs-fishbone/
- https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html
- https://testing.googleblog.com/2020/12/test-flakiness-one-of-main-challenges.html
- https://firefox-source-docs.mozilla.org/bug-mgmt/policies/triage-bugzilla.html
