# issue-11 defect-verification rulebook maturation — proposal

files (phase 2 only, not touched by this PR): `verify/hooks/directive.sh`,
`verify/skills/finding-record/SKILL.md`,
`verify/skills/finding-record/templates/finding-record-template.md`,
`docs/proposals/README.md` (norm statement only, no new proposal content)

## Request (paraphrased intent)

Fix, by domain survey rather than by intuition, what methodology and what
required components this role's phase-1 proposals and phase-2
verify-record deliverables must follow, document the adoption rationale
against the survey, and lay out how the adopted norms get encoded as
directive text / record fields / gates in a later, separately-approved
phase-2 PR. This PR is phase 1 only: survey + proposal, no rulebook edits.

## (a) Phase-1 proposal norms — what this and future defect-verification proposals must follow

**Required shape** (already de facto used by `docs/issue-6/proposals/
coding.md`, `docs/issue-8/proposals/coding.md`,
`docs/issue-12/proposals/implementation.md` — this proposal formalizes it
as the named norm rather than leaving it as unstated convention):

1. `files:` header naming every file the described phase-2 work would
   touch (empty/N/A when, as here, phase 2 has not been designed yet
   beyond a plan).
2. `Request` — paraphrased intent, one paragraph.
3. `Constraints` — facts pinned down by the survey/scout brief, each one
   traceable to a specific finding.
4. `What will be done` — numbered, concrete steps.
5. `Out of scope` — explicit exclusions, including always stating that
   phase 2 execution itself is out of scope for a phase-1 PR.
6. `How it'll be known to work` — objective, re-runnable checks (a grep, a
   parse check, a test invocation), not subjective sign-off language.

**Required evidence format**: a scout-brief (this PR's
`docs/issue-11/reports/defect-verification/scout-brief.md`) with an
explicit `Sources:` list of URLs actually consulted, and explicit
statement of sweep mode (parallel/sequential/knowledge-fallback) — never a
proposal whose "why" section cites unsourced claims about external
practice. A current-state survey precedes it so constraints are
diffed against what already exists, not re-derived from nothing.

**Rationale**: this is exactly the same evidentiary posture the survey
found this repo's own `finding-record`/`severity-classification` skills
already hold verify to for its phase-2 output (evidence-or-refused,
sourced severity scale, no unsourced subjective scoring) — a
defect-verification proposal that asked a *lower* evidentiary bar of
itself than it demands of its own phase-2 deliverable would be internally
inconsistent. Formalizing the already-converged shape also prevents drift
across future issues' proposals for this role.

## (b) Phase-2 deliverable norms — what verify-record.md / findings must contain

Adopted, each tied to a scout-brief line:

1. **Fixed attempt shape**: extend `finding-record`'s attempt fields
   beyond the current `attempt / outcome / evidence` triple with an
   explicit `steps` (what was actually run/checked) and, where the claim
   under test states an expectation, `expected` / `actual` — mirroring the
   IEEE 829 Test Incident Report's incident-description /
   steps-to-reproduce / expected-vs-actual-result shape (scout-brief
   "Adopt: IEEE 829/29119-3-style fixed attempt shape"). Rationale: a bare
   `evidence` pointer answers "is there a pointer" but not "does the
   pointer show what was expected vs. what happened," which is the actual
   basis a `reproduced` verdict needs to be checkable by someone who was
   not the one running the attempt.
2. **Explicit severity-vs-priority boundary**: state in `directive.sh`'s
   `HAND_OFF` that verify sets `severity` only, never a fix-urgency/
   priority ranking — that is coding's or a human's call once the finding
   lands (scout-brief "must-be: severity ≠ priority (ISTQB)"). Rationale:
   this role's mandate is already "never a fix"; leaving priority-setting
   implicitly out is weaker than saying so, and an unstated boundary is
   exactly the kind of scope creep a later session could drift into
   without a line to point at.
3. **A first-class inconclusive/needs-repro-info outcome**: add a third
   value to the outcome set — `not-reproduced` stays "attempted, did not
   reproduce"; a new `blocked: needs-repro-access` (exact field name is a
   phase-2 wording call) captures "could not be attempted at all from what
   is available," which today only exists as unstructured prose in
   `finding-record`'s "what it asks the user for" section (scout-brief
   "must-be: Mozilla Bugzilla triage bounces a bug lacking repro steps
   back before triage continues, rather than closing it and rather than
   silently treating it as done"). Rationale: folding "couldn't even try"
   into `not-reproduced` makes an unattempted attempt indistinguishable
   from a genuinely-tried-and-clean one — the exact failure mode
   `finding-record`'s own existing "never skip recording an attempt that
   came up empty" line already guards against for the two-value case; a
   third value closes the same gap for the blocked case.
4. **Repeat-run note for suspected-nondeterministic defects**: when an
   attempt's claim concerns intermittent/nondeterministic behavior, the
   attempt's `evidence` must record how many times it was run and how many
   times it reproduced (not a single pass/fail), per the scout-brief's
   Google flaky-test finding. Rationale: a single run is not evidence
   either way for a nondeterministic claim; a repeat count is the
   difference between "checked once" and "checked enough to trust the
   outcome."
5. **No change to severity scoring**: `severity-classification`'s
   Chromium/Microsoft deterministic-lookup shape stays as-is — the sweep
   confirms, it does not revise, that choice (scout-brief "skip: DREAD,
   already correctly rejected here").
6. **No root-cause-analysis requirement added to verify's own record**:
   5 Whys/Ishikawa-style causal drilling is explicitly out of scope for
   the `rationale` field, which stays "one line connecting evidence to
   verdict," not a causal chain (scout-brief "skip: root-cause methodology
   ... belongs to coding's fix, not verify's finding"). Rationale: adding
   it would blur "whether a defect exists" into "why," which the
   directive's own `YOU_DECIDE` line already excludes.

## (c) Rationale index

Every (b) item above states its scout-brief tie explicitly inline; no item
was adopted without one. Items adopted where the survey found the current
rulebook already correct (severity scoring, DREAD rejection, no root-cause
requirement) are recorded as confirmations, not regressions — the proposal
does not invent a change where the sweep found none warranted.

## (d) Plugin reflection plan (phase 2, not executed by this PR)

Per "core canon scripts are reference-only, never copy" and the pattern
`a057481` already established for this repo (`directive.sh` is a stub
calling `core_role_directive`, not a role-specific copy of shared
boilerplate): none of (b)'s four adopted changes touch core-canon-owned
gates (`record-fields-gate.sh`'s minimum-content check,
`closed-checks-gate.sh`'s sha-matching, `trailer-gate.sh`,
`handbook-trigger-gate.sh` — all either already canon-referenced or
verify-specific and untouched by this sweep). All four are role-unique
judgment content, so they land the same way `directive.sh`'s existing
`HAND_OFF` string already carries verify's judgment content — as text
inside this role's own tree, not as new canon:

1. Item 1 (fixed attempt shape) → edit
   `verify/skills/finding-record/SKILL.md`'s field list (add `steps`,
   conditionally `expected`/`actual`) and the paired template at
   `verify/skills/finding-record/templates/finding-record-template.md`.
   No gate change needed unless a phase-2 decision is made to have
   `record-fields-gate.sh` structurally require the new fields — if so,
   that is a verify-specific addition to the existing local gate, not a
   canon file, since the shape is role-unique.
2. Item 2 (severity-vs-priority line) → one added sentence in
   `directive.sh`'s `HAND_OFF` heredoc string, passed as-is into
   `core_role_directive`'s fourth argument — no core file touched, no
   stub-shape violation (`stub-check.sh`'s structural rule only bars
   *regrown boilerplate* lines outside the four-argument call, not content
   inside the argument strings).
3. Item 3 (blocked/needs-repro-info outcome) → edit `finding-record`'s
   "the outcome set" section to add the third value and its own required
   field (what access/info is missing), plus the template.
4. Item 4 (repeat-run note) → edit `finding-record`'s "evidence" field
   description to require a run-count note specifically for attempts
   flagged as targeting suspected nondeterminism; no new field, an
   addition to what the existing `evidence` field must contain in that
   case.

None of the four requires a new file under `verify/`, a new gate script,
or a change to `verify/hooks/hooks.json`'s registered hook set — all land
as text/field-list edits to already-existing role-owned files, consistent
with keeping core-canon-covered mechanics (stub shape, minimum-content
gate mechanics, sha-matching mechanics) untouched.

## Out of scope

- Any edit to `verify/hooks/*.sh`, `verify/skills/**`, `hooks.json`, or
  `docs/issue-11/reports/defect-verification.md` (the phase-2 record) —
  none touched by this PR.
- Any change to core (`tokenmaxxxer-core`) — none of (d)'s changes are
  canon-owned.
- Phase 2 execution itself — this PR stops after the phase-1 proposal, per
  contract v3 s19: no APPROVE, no implementation, pending a human approver
  in `docs/specs/approvers.md`.
- Exact final field names for items 1 and 3 (`steps`/`expected`/`actual`,
  the blocked-outcome's literal value string) — left as a phase-2 wording
  decision within the frozen shape this proposal fixes; the shape and its
  rationale are what phase 1 commits to, not the literal string.

## How it'll be known to work (phase 1 acceptance)

- `docs/issue-11/reports/defect-verification/current-state-survey.md` and
  `scout-brief.md` exist, the brief has a non-empty `Sources:` list, and
  states its sweep mode explicitly.
- This proposal's every (b) item cites a specific scout-brief line by
  quoting its adopt/skip label.
- `git grep -rIn "IEEE 829\|ISTQB\|DREAD\|Ishikawa" docs/issue-11/` finds
  the survey/brief/proposal trail, and no phase-2 file is modified by this
  PR (`git diff --stat main...HEAD -- verify/` is empty).
