---
status: specs
---

# verify role — state machine

Transcribed from `docs/specs/agent-roles.md` (Part 1 "`verify`" and Part 3
"`verify`") in this repository, in this repository's own words, so this
repository is self-contained. It also draws directly on
`docs/specs/role-handoff-contract.md` §2's `verify-record` row for the
carrying artifact's exact `loop_state` vocabulary. If any of these disagree,
the contract is authoritative and this file should be brought back into
line with it.

## What this role decides

Whether a defect exists in what was built, found by independently
attempting to reproduce it — never a re-litigation of review's
per-requirement verdict, never a holistic code-quality judgment.

## What it is given to start, and what it depends on

Given: what coding and qa have already produced for the subject, once both
exist (contract §3's first verify wake).

Depends on, per contract §4: `coding-record`, `qa-record`, and
`review-record`. Reading every other role's record is always allowed
(contract §4's READ-broad rule — "Every role may read every other role's
record, unconditionally, for context"); what verify's own `finding` may
cite as its basis is narrower — its own independent reproduction attempt,
not a restatement of review's or qa's prior conclusion standing in for one.

**Independence from review.** Per contract §4: "A `verify` finding with
`severity: blocking` is not overridden by a `review-record` in
`loop_state: reported` with a clean verdict — review's and verify's
verdicts are independent, and verify's blocking findings gate landing on
their own terms." verify's contract entry "enforces structure only — that
a verify record exists, its WAKES-ON edges, and a blocking-finding channel
back to coding — and does not dictate what counts as a defect; deciding
what is a real defect is verify's own judgment."

**Enforcement.** A path is the only thing a mechanical gate can check
here. `verify-cycle/hooks/state-gate.sh` (`PreToolUse`, matcher `.*`)
enforces, regardless of tool: whether a write reaches
`verify-record.md` (Rule 1, the transition-table check), and separately,
whether a `Write`/`Edit`/`MultiEdit` call targets a subject-scoped record
path under `docs/reports/records/<subject>/` owned by a role other than
`verify` (contract §11's NEVER-OVERWRITE rule) — refused as a path-ownership
conflict regardless of the transition-table check. It does not, and cannot,
mechanically check that verify's `finding` was built on an independent
reproduction rather than review's or qa's prior conclusion; that judgment
stays with the role, per contract §14's warning that a heuristic check for
a non-mechanical property produces false confidence.

## Carrying artifact

`verify-record.md`, at the root of the project under verification (the path
is configurable via `VERIFY_RECORD_NAME`, default `verify-record.md`; both
hooks read the same environment variable so they never disagree about the
file's name). Its state lives in a YAML-frontmatter-shaped header block's
`status` field:

```markdown
---
status: reproducing
---
```

Below the header, the file holds zero or more attempt blocks, each its own
`---`-delimited block (recognized only when opened and closed by a line
that is exactly `---`):

```markdown
---
attempt: <what was being tested, verbatim reference to the claim under test>
outcome: reproduced
evidence: <repro steps, commit sha, run output>
---
```

A block is the header if it carries a `status:` key and no `attempt:` key;
every other block is an attempt block and must carry exactly one
`attempt:` key, one `outcome:` key, and one `evidence:` key to be
well-formed. An attempt whose outcome is `reproduced` may additionally
carry a `finding` block per `docs/specs/role-handoff-contract.md` §2's
`finding` row, with `addressed_to: coding` and `severity: blocking|advisory`.

## States

`idle`, `reproducing`, `reproduced`, `cleared` — taken verbatim from
`docs/specs/role-handoff-contract.md` §2's `verify-record` row.

## Transition table

| From | To | Fires on |
|---|---|---|
| `idle` | `reproducing` | coding and qa have both produced artifacts for the subject (contract §3's first verify wake) |
| `reproducing` | `reproducing` | **gated, self-loop** — verify needs evidence/access before a specific reproduction attempt can continue |
| `reproducing` | `reproduced` | every reproduction attempt taken up in this pass carries a recorded outcome |
| `reproduced` | `reproduced` | **gated, self-loop** — a disputed reproduction is re-examined, recorded inline against the same attempt |
| `reproduced` | `cleared` | **gated** — no unresolved `severity: blocking` finding remains, or the user waives one under contract §8 |

## Rejection rule — `reproducing -> reproduced`

Refused unless every attempt block in `verify-record.md` carries exactly
one `outcome` of `reproduced` or `not-reproduced`, and an `evidence`
pointer. A block with no `outcome:` line, more than one, an empty value, or
a value outside that two-item set fails the transition. A file with zero
attempt blocks also fails — an empty verification pass is not a complete
one.

## Rejection rule — `reproduced -> cleared`

Refused unless the model judges, from the user's own turn, that no
unresolved `severity: blocking` finding remains among the recorded
attempts, or that the user has explicitly waived one under contract §8's
human-judgment seat. Content alone (every attempt recorded) is never
consent by itself.

**Evaluated on the target path, not the tool.** Per
`docs/specs/agent-roles.md` Part 3, mirroring `review-agent-rulebook`'s own
statement of the same rule: a guard that only inspects `Write`/`Edit` tool
payloads is bypassed by the same edit made through a shell redirect, `sed
-i`, `cp`, `mv`, or `tee`. `hooks/state-gate.sh` closes this by also
scanning `Bash` command strings for the state file's basename alongside a
write-shaped construct and, when found, treating the call as a candidate
write to the state file.

## Per-role path ownership (§11 NEVER-OVERWRITE)

verify writes only `docs/reports/records/<subject>/verify.md` (including
inline `finding` blocks). An existing record already at a path verify does
not own under `docs/reports/records/` is refused to write, reported as a
conflict, and never overwritten — enforced mechanically by
`hooks/state-gate.sh`'s §11 classification check, independent of the
transition-table gate.

## Fails closed

Every one of these denies the tool call (exit 2) rather than allowing it:
unparseable or missing JSON on stdin, a payload that is not an object, an
unreadable `tool_input` on a tool this gate inspects, a missing or
unreadable `verify-record.md` once a candidate write to it is detected,
unreadable attempted content on a `Write`/`Edit`/`MultiEdit` call, and the
absence of `docs/specs/role-handoff-contract.md` at the repo root (Rule 0).
`python3` itself being unavailable is also a refusal, not a fall-through.

## Refuses while in each state

- **`idle`**: refuses to record any attempt before coding and qa have both
  produced artifacts for the subject.
- **`reproducing`**: refuses to skip recording an outcome for any attempt
  taken up, and refuses to merge `reproduced`/`not-reproduced` into a bare
  pass/fail.
- **`reproduced`**: refuses to move to `cleared` while an unwaived
  `severity: blocking` finding remains unresolved.
- **`cleared`**: refuses to revise a cleared outcome set without the user
  reopening the role against a new coding or qa artifact for the subject.
- **All states**: refuses to edit, patch, or "fix" the code under
  verification — this role reports, it does not build. Refuses to let a
  clean `review-record` stand in for verify's own independent reproduction
  attempt.

## Kill switch

`export VERIFY_CYCLE_DISABLE=1` disables both hooks
(`hooks/inject-transition-rules.sh`, `hooks/state-gate.sh`); unset, empty,
`0`, `false`, `no`, or `off` all mean active.
