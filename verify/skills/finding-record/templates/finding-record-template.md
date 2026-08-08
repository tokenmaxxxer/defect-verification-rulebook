<!--
Field skeleton for one reproduction-attempt block written by the
`finding-record` skill into verify-record.md, below the header block. One
block per attempt. See ../SKILL.md for the full field-by-field rationale.

outcome must be exactly one of: reproduced, not-reproduced,
blocked: needs-repro-access.

For attempts about suspected intermittent/nondeterministic behavior,
evidence must record how many times the attempt was run and how many
times it reproduced — not a single pass/fail.

expected/actual are required only when the claim under test states an
expectation; omit them otherwise.

When outcome is reproduced, also emit a separate finding block (see the
second skeleton below) addressed to coding.
-->
---
attempt: <what was being tested, verbatim reference to the claim under test>
outcome: <reproduced | not-reproduced | blocked: needs-repro-access>
evidence: <repro steps, commit sha, run output; for not-reproduced, what was attempted; for blocked, what access/info is missing; for nondeterministic claims, run count and reproduction count>
steps: <what was actually run/checked to attempt the reproduction> <!-- spec field name: repro_steps -->
expected: <required only when the claim under test states an expectation — what was expected; omit otherwise>
actual: <required only when the claim under test states an expectation — what actually happened; omit otherwise>
---
<!-- status (spec field name): incident-level disposition, derived from outcome/verdict above; not a separate written field. -->

<!--
Emit this second block only when outcome above is `reproduced`, per
docs/specs/role-handoff-contract.md §2's finding row.

verdict must be exactly one of: Present, Surface, Absent, Incorrect,
Unverifiable.

spec_vs_built is required only when verdict is Incorrect; omit it
otherwise. severity must be exactly one of: blocking, advisory.
-->
---
requirement: <the requirement text or id this finding addresses>
verdict: <Present | Surface | Absent | Incorrect | Unverifiable>
evidence: <file:line or hunk pointer, or reproduction transcript>
rationale: <one line connecting the evidence to the verdict>
spec_vs_built: <required only when verdict: Incorrect — what the spec required vs. what was built; omit otherwise>
addressed_to: coding
severity: <blocking | advisory> <!-- spec field name: finding_type -->
---
