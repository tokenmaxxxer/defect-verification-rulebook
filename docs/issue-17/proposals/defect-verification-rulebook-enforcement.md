# issue-17 defect-verification enforcement maturation — proposal

files (phase 2 only, not touched by this PR): `verify/hooks/directive.sh`,
`verify/hooks/finding-fields-gate.sh` (new), `verify/hooks/verify-state.sh`
(new), `verify/hooks/state-guard.sh` (new), `verify/hooks/hooks.json`,
`tests/run-gate-tests.sh`

## Request (paraphrased intent)

Issue-11's phase-2 delivery (`128d518`) adopted six methodology elements
(fixed attempt shape, severity-vs-priority boundary, three-value outcome
set, repeat-run note, deterministic severity scoring, no root-cause
requirement) but landed all of them as directive/skill prose only. Issue
#17 asks that the adopted norm be pushed from prose into the same kind of
mechanical enforcement `implementation-rulebook`'s hook machine already
demonstrates for coding, and that the two facets (phase-1 proposal
discipline, phase-2 record discipline) each get concrete, checkable
step/criterion/prohibition text rather than a one-line `PRODUCES` summary.

## Constraints

- C1 (survey): exactly one gate exists today
  (`closed-checks-gate.sh`), and it enforces only §16 sha-matching — no
  field-presence check, no outcome-set check, no state-order check exists
  anywhere in this plugin (survey, "Gates" section).
- C2 (survey): `finding-record/SKILL.md` already states the full required
  field list (`attempt`/`outcome`/`evidence`/`steps`/conditional
  `expected`/`actual`, plus the finding block's contract-verbatim fields)
  and the refusal norm — this proposal's gate checks exactly that
  already-adopted list, inventing no new fields.
- C3 (survey): contract row 69 fixes the verify-record state list as
  `idle,reproducing,reproduced,cleared` and §~220-224 forbids `cleared`
  with an unresolved blocking finding — the only sequence constraint this
  role actually has, and the one this proposal's state guard targets.
- C4 (scout, adopt): every enforcement-carrying sibling plugin here layers
  a role-specific gate additionally on top of (never replacing) the generic
  gate, fails closed on unparseable/unreconstructable input, never emits an
  `allow` `permissionDecision`, and ships a matching subprocess test in
  `tests/run-gate-tests.sh`'s `run()` shape — this proposal reuses that
  shape exactly, per `pricing/hooks/methodology-gate.sh` and this repo's
  own `closed-checks-gate.sh`.
- C5 (scout, adopt): order constraints get a separate small state file +
  guard pair rather than being folded into the field gate, per
  `implementation-rulebook`'s `state.sh`/`hunt-guard.sh` split — keeps
  field-presence and state-order failures independently testable.
- C6 (scout, skip): severity-value *correctness* and "evidence is verify's
  own attempt" are not gated — both require re-deriving the reproduction
  itself, which no static-content check can do; only literal presence is
  checked, consistent with `methodology-gate.sh`'s own skip of verdict
  correctness.
- C7 (canon constraint, per issue): canon-owned mechanics (stub shape,
  `_gate-common.sh`'s `resolve_root`, the generic core `record-fields-gate.sh`
  minimum-content check, `trailer-gate.sh`, `handbook-trigger-gate.sh`) are
  referenced and reused, never copied or re-implemented in `verify/`.

## Revision note (this update)

The approver's FEEDBACK on this PR and the issue's "요구 정정" comment both
require the same restructuring, applied here: this is no longer a single
deepened gate/directive inside the existing `verify` plugin. Instead, each
adopted methodology element becomes its own **independent, self-contained
plugin** (own directive/gate/state/test content, `freelunch`-level
completeness, registered in `marketplace.json`), and the phase-1 and
phase-2 governance norms (기획서 규범 / 산출물 규범) are each defined as an
explicit **composition** of those plugins rather than as one monolithic
rulebook change. The design content below (C1-C7, the gate mechanics, the
out-of-scope boundary) is unchanged from the prior draft; only the
packaging is restructured into the plugin set.

## Plugin set (design; required section per issue #17 "요구 정정")

Four independent plugins, each owning exactly one adopted methodology
element and shipping self-contained (directive/gate/state/test as
applicable). None are implemented by this PR — phase 1 stops at design.

| Plugin name | Methodology owned | Components (self-contained) | Depends on |
|---|---|---|---|
| `verify-directive-depth` | Facet-structured step/criterion/prohibition text for both phase-1 attempt-forming and phase-2 record-writing (replacing the current one-line `PRODUCES`/`USE_WHEN`/`HAND_OFF` prose) | `hooks/directive.sh` heredoc rewrite only — fires on `SessionStart`, no gate of its own (a directive cannot gate a write that doesn't exist yet) | none (base directive plugin every other plugin's directive text assumes is active) |
| `verify-outcome-gate` | The three-value outcome set (`reproduced`/`not-reproduced`/`blocked: needs-repro-access`) plus the evidence-field-present requirement, per attempt block | new `hooks/outcome-gate.sh` (PreToolUse, `Write\|Edit\|MultiEdit\|NotebookEdit`, target `docs/issue-<n>/reports/verify.md`), reusing canon's `_gate-common.sh` `resolve_root` + fail-closed trap; own allow/deny pairs in `tests/run-gate-tests.sh` | canon generic field gate (referenced, never copied, per C7) |
| `verify-finding-gate` | The finding block's required fields when `outcome: reproduced` (`verdict:`, `addressed_to: coding`, `severity: blocking\|advisory`) — deterministic severity band is asserted present, never re-derived (per C6) | new `hooks/finding-gate.sh` (same PreToolUse matcher/path as above, registered as an *additional* `hooks.json` entry, never replacing `verify-outcome-gate`'s); own test pairs (`reproduced` missing `verdict`/`addressed_to`/`severity`, each denied by name) | `verify-outcome-gate` (finding fields are only meaningful once an outcome value has already been validated) |
| `verify-state-guard` | The `idle < reproducing < reproduced < cleared` order constraint from contract §69/§~220-224 | new `hooks/verify-state.sh` (state writer, mirrors `hunt-state.sh`'s on-disk JSON convention) + `hooks/state-guard.sh` (PreToolUse guard, mirrors `hunt-guard.sh`); denies `cleared`/`reproduced` with no prior recorded `reproducing`, and denies `cleared` with an unresolved `severity: blocking` finding; own test pairs (skip-ahead, unresolved-blocking-at-cleared) | `verify-finding-gate` (needs to know a finding's severity/resolution to gate `cleared`) |

`closed-checks-gate.sh` (existing, §16 sha-matching) is left as-is and is
not restructured — it already is a single-methodology, self-contained gate
and satisfies the "1 methodology = 1 gate" bar this issue asks for; the four
plugins above are the *new* ones this proposal adds.

### Composition: which plugins make up each规범 (norm)

- **기획서(phase 1) 규범** = `verify-directive-depth` (its phase-1/`USE_WHEN`
  facet only) — phase 1 has no on-disk write surface to gate yet (no
  `docs/issue-<n>/reports/verify.md` exists before phase 2 begins), so the
  norm is necessarily directive-only; no gate plugin composes into it.
- **산출물(phase 2) 규범** = `verify-directive-depth` (its phase-2/`HAND_OFF`
  facet) **+** `verify-outcome-gate` **+** `verify-finding-gate` **+**
  `verify-state-guard`, applied in that dependency order (each later plugin
  in the chain assumes the earlier ones already validated their slice of
  the same write). This four-plugin composition is what "enforcement" means
  for phase 2 under this proposal — no single plugin claims to cover the
  whole record-writing norm by itself.

## What will be done (phase 2 design; not executed by this PR)

1. **`verify-directive-depth`** — replace `directive.sh`'s single-line
   `PRODUCES` string with a facet-structured heredoc (phase 1 / phase 2
   each get their own numbered steps, a judgment-criteria line, and a
   "never" line), mirroring the depth `no-footgun/hooks/directive.sh`
   already carries for its own facet gate:
   - Phase 1 (`USE_WHEN`, already scout-protocol shaped from issue-11 —
     extend, don't replace): steps = read coding/qa/review records ->
     enumerate candidate attempts naming their source (qa report / review
     Present verdict / self-devised) -> name `code_under_review:` and which
     `closed_checks` will be cited vs re-derived. Criterion: an attempt list
     with no named source per item is rejected as too vague to act on.
     Never: proposing a fix, re-litigating review's verdict as the attempt
     itself.
   - Phase 2 (`HAND_OFF`): steps = attempt -> record outcome (one of the
     three values, always) -> on `reproduced`, write the finding block ->
     assign severity by the deterministic band, never freehand -> check
     `cleared` eligibility (no unresolved blocking finding). Criterion:
     every attempt taken has a recorded outcome, no exceptions, including
     empty ones. Never: skipping an attempt's outcome, merging the
     three-value set into pass/fail, setting a priority/fix-urgency value,
     citing a `closed_checks` entry against a stale sha.
2. **`verify-outcome-gate`'s `outcome-gate.sh`** (new, PreToolUse,
   registered alongside `closed-checks-gate.sh` in `hooks.json`, same
   matcher and target path `docs/issue-<n>/reports/verify.md`): on a write
   reconstructable per the existing `closed-checks-gate.sh`
   content-reconstruction logic, requires the resulting content to carry,
   per attempt block, an `outcome:` value that is exactly one of
   `reproduced`, `not-reproduced`, or `blocked: needs-repro-access`
   (anything else denied by name) and an `evidence:` field (any outcome).
3. **`verify-finding-gate`'s `finding-gate.sh`** (new, PreToolUse, an
   *additional* `hooks.json` entry layered beside — never replacing —
   `outcome-gate.sh`): when `outcome: reproduced` appears, requires a paired
   `finding` block carrying `verdict:`, `addressed_to: coding`, and
   `severity: blocking` or `severity: advisory` (missing any one denied by
   name, per-field, mirroring `methodology-gate.sh`'s per-element `missing`
   list rather than one generic denial).
4. **`verify-state-guard`'s `verify-state.sh` + `state-guard.sh`** (new
   pair, mirroring `state.sh`/`hunt-guard.sh`): a small state file
   (`.claude/verify-state-issue-<n>.json`, same on-disk convention as
   `hunt-state.sh`) records the highest state reached
   (`idle < reproducing < reproduced < cleared`); `state-guard.sh`, a
   third PreToolUse hook on the same write surface, denies a write whose
   resulting content declares `cleared` or `reproduced` with no prior
   `reproducing`-state write ever recorded for that issue, and denies a
   `cleared` write whose resulting content still shows an unresolved
   `severity: blocking` finding with no paired resolution note.
5. **Gate tests**: extend `tests/run-gate-tests.sh` with allow/deny pairs
   for all three new gates (valid three-value outcome / invalid outcome
   string / `reproduced` missing evidence / `reproduced` missing finding
   fields / `cleared` skipping `reproducing` / `cleared` with unresolved
   blocking finding), using the file's existing `run()` helper unchanged;
   each new plugin's tests stay independently runnable (per-plugin
   allow/deny pairs), matching the "self-contained plugin" bar.
6. **`marketplace.json` registration**: each of the three new plugins
   (`verify-outcome-gate`, `verify-finding-gate`, `verify-state-guard`) and
   the restructured `verify-directive-depth` gets its own entry in
   `.claude-plugin/marketplace.json`, alongside the existing `verify` entry
   (which continues to own `closed-checks-gate.sh` and the shared
   `finding-record` skill) — one entry per methodology, per issue #17's
   "요구 정정".
7. **No new agents/checklist**: per scout-brief skip — the role's one
   repeating procedure (`finding-record`) is already a single skill; issue
   #17's "if needed" branch does not trigger here.

## Out of scope

- Any edit to `verify/hooks/*.sh`, `verify/hooks/hooks.json`,
  `.claude-plugin/marketplace.json`, `tests/run-gate-tests.sh`, or
  `docs/issue-17/reports/verify.md` (the phase-2 record), and no creation of
  any new plugin directory (`verify-directive-depth`, `verify-outcome-gate`,
  `verify-finding-gate`, `verify-state-guard`) — none touched by this PR;
  this document is design only.
- Any change to core (`tokenmaxxxer-core`) or copying canon gate logic into
  any of the four plugins — `verify-finding-gate`'s `finding-gate.sh` and
  `verify-state-guard`'s `state-guard.sh` are role-unique additions layered
  beside canon's generic gates, per C7.
- Gating severity-value correctness or attempt-authorship (evidence is
  genuinely verify's own) — C6.
- Phase 2 execution itself — this PR stops after the phase-1 proposal, no
  APPROVE, no implementation, pending a human approver in
  `docs/specs/approvers.md`.
- Exact on-disk state-file schema and path for `verify-state-guard` — left
  as a phase-2 implementation detail within the frozen
  `idle<reproducing<reproduced<cleared` order this proposal fixes.
- Merging the four plugins into one, or folding any of them back into the
  existing `verify` plugin entry — the "1 methodology = 1 plugin" split is
  itself part of what this revision fixes, not an implementation detail
  left open.

## How it'll be known to work (phase 1 acceptance)

- `docs/issue-17/reports/defect-verification/current-state-survey.md` and
  `scout-brief.md` exist; the brief states its sweep mode explicitly and
  carries a non-empty `Sources:` list.
- Every Constraint (C1-C7) above traces to a named survey section or a
  scout-brief adopt/skip line.
- `git diff --stat main...HEAD -- verify/ tests/` is empty (no phase-2 file
  touched by this PR).
- `git grep -n "idle,reproducing,reproduced,cleared\|methodology-gate.sh\|hunt-guard.sh" docs/issue-17/` finds the design's cited exemplars and contract anchor.
- The "Plugin set" table above names all four plugins (`verify-directive-depth`,
  `verify-outcome-gate`, `verify-finding-gate`, `verify-state-guard`) with
  methodology owned, components, and dependency, and the "Composition"
  subsection states explicitly which plugins compose the phase-1 규범 and
  which compose the phase-2 규범 — satisfying both the issue's "요구 정정"
  comment and the PR's FEEDBACK review requiring the same structure.
