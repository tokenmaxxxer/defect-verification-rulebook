# verify-finding-gate

A PreToolUse gate that enforces one rule: once a write to
`docs/issue-<n>/reports/verify.md` claims `outcome: reproduced` for an
attempt, that same attempt's record must also carry a paired `finding` block
declaring:

- `verdict:` — one of `Present|Surface|Absent|Incorrect|Unverifiable`
- `addressed_to: coding` — exactly this value
- `severity:` — `blocking` or `advisory`

If a write contains no `outcome: reproduced` anywhere, the gate has nothing
to check and allows immediately. If it contains one or more, each occurrence
is checked for its own paired finding fields (see the windowed-search
pairing heuristic documented in `hooks/finding-gate.sh`), and a write missing
any field on any reproduced attempt is refused. All missing/invalid fields
are reported together in a single deny message.

Correctness of the *values* recorded (is this really `blocking`? is the
verdict actually right?) is out of scope for this gate — it checks presence
and shape only, per the phase-1 proposal's C6 boundary. It never touches the
content of the write beyond judging it.

## Kill switch

```
export VERIFY_FINDING_GATE_OFF=1
```

Any of `1`, `true`, `yes`, `on` (or anything other than empty/`0`/`false`/
`no`/`off`) disables the gate for the session; the gate then allows every
call unconditionally.

## Composition

This gate layers beside — and never replaces — the base `verify` plugin's
`closed-checks-gate.sh` and the sibling `verify-outcome-gate` plugin's hook;
all fire as independent PreToolUse entries on the same write. `verify-state-guard`
depends on this plugin's judgment: it needs a reproduced attempt's finding
severity on record before it can gate a transition to `cleared`.
