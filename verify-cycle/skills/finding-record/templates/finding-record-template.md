<!--
Field skeleton for one reproduction-attempt block written by the
`finding-record` skill into verify-record.md, below the header block. One
block per attempt. See ../SKILL.md for the full field-by-field rationale.

outcome must be exactly one of: reproduced, not-reproduced.

When outcome is reproduced, also emit a separate finding block (see the
second skeleton below) addressed to coding.
-->
---
attempt: <what was being tested, verbatim reference to the claim under test>
outcome: <reproduced | not-reproduced>
evidence: <repro steps, commit sha, run output; for not-reproduced, what was attempted>
---

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
severity: <blocking | advisory>
---
