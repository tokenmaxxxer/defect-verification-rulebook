# verify-outcome-gate

A `PreToolUse` gate on writes to `docs/issue-<n>/reports/verify.md`. For every
`outcome:` field found in the write's resulting content, it enforces:

1. The value is exactly one of the three adopted outcomes:
   `reproduced`, `not-reproduced`, `blocked: needs-repro-access`. Any other
   value is refused by name.
2. Every `outcome:` occurrence has an accompanying `evidence:` field —
   `reproduced` needs the reproduction path itself, `not-reproduced` needs
   evidence describing what was attempted, and `blocked: needs-repro-access`
   needs evidence naming what access or information is missing. An outcome
   with no paired evidence is refused by name.

If the write contains no `outcome:` field at all (e.g. an early-stage write
before any attempt is recorded), the gate allows it — there is nothing to
judge yet. Writes to any path other than
`docs/issue-<n>/reports/verify.md` are allowed immediately without
inspection.

This mirrors `verify/skills/finding-record/SKILL.md`'s field contract; the
gate invents no new fields or values.

## Kill switch

```
export VERIFY_OUTCOME_GATE_OFF=1
```

Any of `1`, `true`, `yes`, or unset-non-empty-truthy values (anything other
than the empty string, `0`, `false`, `no`, `off`) disables the gate.

## Composition with sibling plugins

This gate only judges the outcome/evidence shape described above; it does
not check severity or verdict correctness (`verify-finding-gate` layers on
top of this one for that), directive depth (`verify-directive-depth`), or
state transitions (`verify-state-guard`). The base `verify` plugin's own
`closed-checks-gate.sh` (a separate PreToolUse gate on the same record file,
enforcing the §16 cite-and-skip sha rule) is unaffected by this plugin —
both gates apply independently to the same writes; neither replaces the
other.
