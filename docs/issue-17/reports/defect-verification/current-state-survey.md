# issue-17 current-state survey — what verify's plugin enforces today

## Directive (`verify/hooks/directive.sh`)

Already carries, as plain text inside `HAND_OFF`/`USE_WHEN`/`PRODUCES` (all
adopted in issue-11's phase-2 delivery, commit `128d518`): the
`reproduced|not-reproduced` outcome pair (but not the third
`blocked: needs-repro-access` value — that exists only in
`finding-record/SKILL.md`, not in the directive text itself), the
evidence-before-write requirement (prose only), the deterministic
severity-band lookup (Critical/High -> blocking, Medium/Low/Unknown ->
advisory), the severity-never-priority line, and the closed_checks
sha-matching rule. None of this is machine-checked at the directive layer —
`directive.sh` only ever *emits* text via `core_role_directive`; it has no
gate of its own and cannot have one (it fires on `SessionStart`, before any
write exists to check).

## Gates (`verify/hooks/hooks.json`)

Exactly one PreToolUse hook is registered: `closed-checks-gate.sh`, matched
on `Write|Edit|MultiEdit|NotebookEdit`. It enforces exactly one thing:
contract §16's closed_checks `code_sha` must equal the record's declared
`code_under_review:` sha, on writes to `docs/issue-<n>/reports/verify.md`.
It does not touch:

- required per-attempt fields (`attempt`, `outcome`, `evidence`, `steps`,
  conditional `expected`/`actual`) — `finding-record/SKILL.md` states them
  as a norm, nothing enforces their presence on write.
- the three-value outcome set — a write with `outcome: reproduced` and no
  `evidence`, or an `outcome:` value outside
  `reproduced|not-reproduced|blocked: needs-repro-access`, is not rejected
  by any gate.
- the finding block's required fields when `outcome: reproduced`
  (`requirement`, `verdict`, `evidence`, `rationale`, conditional
  `spec_vs_built`, `addressed_to: coding`, `severity: blocking|advisory`).
- severity assignment correctness (that `severity` actually matches the
  deterministic band given the stated defect class) — this is a judgment
  call the survey does not propose gating (see scout-brief skip line).
- the `idle -> reproducing -> reproduced -> cleared` state order from
  contract §69's row (`verify-record` state list) — nothing in this repo
  tracks or enforces that a record cannot jump straight to `cleared` with
  no prior `reproducing` block, or that a `cleared` write co-occurs with an
  unresolved blocking finding (contract's "verify↔coding cycle
  termination" clause, §~220-224).
- `docs/specs/approvers.md`-only reproduction sourcing (evidence must be
  verify's own attempt, never a restatement) — currently prose-only in
  `HAND_OFF`'s first bullet, unenforceable mechanically without re-running
  the reproduction itself, so this survey does not propose a gate for it
  (see scout-brief skip line).

`verify/skills/finding-record/SKILL.md` states the required-fields norm and
the refusal norm ("reproduced with no evidence... refused... before it is
written") as *skill-level self-discipline* — a plugin skill's own prose can
ask the model to refuse, but nothing forces it; a PreToolUse gate is the
only mechanical enforcement point available to this plugin.

## Reference implementations (local, already in the working environment)

- `pricing/hooks/methodology-gate.sh` (pricing-rulebook, 230 lines): a
  second PreToolUse gate, layered on top of (never replacing) a generic
  core canon field gate, that checks a fixed list of methodology elements
  are present in the resulting write content by string/regex presence —
  fails closed on unparseable payload, unreconstructable resulting content,
  or a missing required element. Registered as an additional `hooks.json`
  entry alongside the generic gate, same matcher (`Write|Edit|MultiEdit`).
- `implementation-rulebook/coding/hooks/{state.sh,hunt-state.sh,coding-progress-gate.sh,hunt-guard.sh}`:
  the state-tracking + progress-gate pattern issue #17 names as the bar —
  a small `state.sh` persists a JSON state file, `*-guard.sh` reads it to
  refuse a tool call that violates the required step order (a gate can
  refuse "reproduced-with-finding before any reproducing attempt was ever
  recorded" the same way `hunt-guard.sh` refuses skipping ahead in coding's
  hunt sequence).
- `verify/hooks/closed-checks-gate.sh` and `tests/run-gate-tests.sh`
  (this repo): the existing local pattern for a fail-closed Python-in-bash
  gate and its matching subprocess test harness — the new gate(s) proposed
  here reuse this exact shape (same `_gate-common.sh` `resolve_root`
  helper, same `__fc` fail-closed trap, same `tests/run-gate-tests.sh`
  `run()` test helper) rather than inventing a new one.

## Gap this issue closes

Every methodology element issue-11 adopted is fully specified in prose
(directive + skill) but zero of it is mechanically enforced on write,
except the one narrow closed_checks-sha check. Issue #17 asks for the rest
of the adopted norm — required attempt/finding fields, the three-value
outcome set, and the `idle→reproducing→reproduced→cleared` order — to move
from prose-only to gate-enforced, at the same rigor `closed-checks-gate.sh`
and the pricing/implementation rulebooks already demonstrate is achievable
within this plugin shape.
