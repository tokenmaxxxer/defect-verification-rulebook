# verify-state-guard

Enforces the fixed `loop_state` order on the verify role's record
(`docs/issue-<n>/reports/verify.md`), per
`docs/specs/role-handoff-contract.md`:

```
idle < reproducing < reproduced < cleared
```

A record must not jump straight to `reproduced` or `cleared` without ever
having passed through `reproducing` first. Additionally, a write declaring
`loop_state: cleared` is refused if the record still shows an unresolved
`severity: blocking` finding (a `severity: blocking` occurrence with no
`resolved:`, `resolution:`, or `status: resolved` marker appearing after it
in the text).

## How it works

Two hooks, deliberately kept failure-independent:

- `hooks/verify-state.sh` — a passive PostToolUse + SessionStart writer.
  After a write to a verify record lands on disk, it reads the record's
  current `loop_state:` and, if its rank is higher than what's already
  recorded, bumps the on-disk state file. It never lowers the recorded
  highest state, and it never blocks or denies anything — any internal
  problem is swallowed silently (exit 0). On SessionStart it also
  best-effort bootstraps a missing state file from the record's current
  `loop_state:` for any `docs/issue-*/reports/verify.md` it finds.

- `hooks/state-guard.sh` — the PreToolUse gate. It reconstructs the
  resulting content of a proposed write to a verify record, extracts the
  new `loop_state:` value, and judges it against the on-disk state file's
  `highest_state` — **never** against the record's current on-disk content.
  Keeping the gate's trust boundary limited to the state file (rather than
  re-deriving "was reproducing ever reached" from the record itself) keeps
  the writer and the gate failure-independent: a bug in one does not
  silently make the other's judgment wrong in the same way.

## State file

One file per issue number, at:

```
.claude/verify-state-issue-<n>.json
```

```json
{ "highest_state": "reproducing" }
```

## Kill switch

```
export VERIFY_STATE_GUARD_OFF=1
```

Any non-empty value other than `0`, `false`, `no`, or `off` disables both
hooks.

## Composition

This plugin depends on `verify-finding-gate` having already validated
finding fields (per the approved proposal's dependency table), and layers
beside `verify-outcome-gate`, `verify-directive-depth`, and the base
`verify` plugin — each judges a different facet of the same record write.
