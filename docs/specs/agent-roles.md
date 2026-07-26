---
status: draft
---

# Agent roles and their state machines — `verify`

This document defines the `verify` role, mirroring the concreteness of
`review-agent-rulebook`'s own `docs/specs/agent-roles.md`: named states, a
named artifact carrying the state, explicit gate conditions evaluated on a
file, not on which tool wrote it. Where `review-agent-rulebook`'s document
described `coding`, `qa`, and `review` as siblings, this document describes
`verify` as the seventh role, sanctioned in
`docs/specs/role-handoff-contract.md` v2 alongside the other six.

## Part 1 — Role

### `verify`

**Decides**: whether a defect exists in what was built, discovered by
independently attempting to reproduce it — never by re-litigating review's
per-requirement verdict, and never by holistic code-quality judgment.

**Given to start**: what coding and qa have already produced for the
subject — their records — once both exist for it (contract §3's first
verify wake). Per contract §4, verify depends on `coding-record`,
`qa-record`, and `review-record`: it reads what was built, what qa already
tried, and what review concluded, then goes looking for what none of them
caught.

**Produces**: a per-attempt `reproduced`/`not-reproduced` outcome in its
own record, and — when a defect reproduces — an inline `finding` block
addressed to coding, carrying `severity: blocking` or `advisory`.

**Prevents**: a defect that review's per-requirement pass and qa's own
reproduction attempts both missed from reaching landing unchallenged. A
`verify` finding with `severity: blocking` is not overridden by a clean
`review-record` — review's and verify's verdicts are independent
(contract §4).

### `review` (existing, as-is)

Described from `review-agent-rulebook`'s own `docs/specs/agent-roles.md`
and `docs/specs/state-machine.md`, read directly, not proposed to change
by this document. review decides whether what was built is what was
specified, per requirement, and never talks to verify directly — the human
carries output between roles, exactly as this document's Part 2 describes
for `verify`. Nothing here is changed by this document.

### `coding`, `qa` (existing, as-is)

Described from `coding-agent-rulebook`'s `warrant` plugin and
`qa-agent-rulebook`'s `qa-cycle` plugin respectively, read directly, not
proposed to change. Nothing here is changed by this document.

## Part 2 — Working with the role

The user is the only channel between roles. Agents never talk to each
other, and the `verify` role runs in its own sandbox with only its own
plugin installed — `verify` never reads another role's repository directly;
it reads records that live inside the same work repository's `docs/`
buckets, per the shared blackboard model (`role-handoff-contract.md`), but
never reaches across into `coding-agent-rulebook`, `qa-agent-rulebook`, or
`review-agent-rulebook`'s own plugin repositories.

**Starting the role.** verify wakes when coding and qa have both produced
artifacts for a subject (first wake), and again before landing, as a
pre-land gate (second wake) — contract §3. A human reads the board, matches
it against the WAKES-ON table, and opens `verify` accordingly; nothing here
claims this happens automatically.

**Answering a gate.** verify stops at named points (Part 3) and needs a
decision only the user can give — a valid answer is confirmation that the
draft outcome set is final, or a waiver of a blocking finding under
contract §8's human-judgment seat. The role never infers approval from the
content of a file — a file saying every attempt was recorded is not
consent by itself.

**Carrying output forward.** verify's own record lives at
`docs/reports/records/<subject>/verify.md`, inside the same work
repository — the blackboard is fully in-repo (contract §10). verify writes
only that path (contract §11); an existing record at a path verify does not
own is refused to write, reported as a conflict, and never overwritten.

**The failure this arrangement has, stated plainly.** Same as
`review-agent-rulebook`'s own Part 2: with the user as the only router and
no cross-agent communication, the thing that goes wrong is the user losing
track of which output is current. The mitigation costs nothing: `verify`,
on being opened, reports its own current state and what its last output was
based on.

## Part 3 — State machine

The role's legal transitions live in a per-repo data file
`verify-cycle/hooks/transition-rules.md`, pipe-delimited with columns
`from | to | actor | precondition`, where `actor` is `user` for transitions
that require the user to have said something and `agent` otherwise. A
`UserPromptSubmit` hook renders the rows matching the current state into
every prompt as a condition→allowed-transition table. If the table or the
state file cannot be read, that hook still emits a block saying so and
forbidding transitions until it is fixed — it never exits silently.

The `PreToolUse` gate decides three things, mirroring
`review-agent-rulebook`'s own gate design exactly: whether a write reaches
the role's state file, judged by resolved target path rather than tool name
or literal filename; whether the resulting transition is a row in the
table; and, separately, whether a `Write`/`Edit`/`MultiEdit` call targets
another role's owned subject-scoped record path under
`docs/reports/records/<subject>/`, per contract §11 — refused outright as a
path-ownership conflict, independent of the transition-table check.
Anything not reaching either check passes.

On each transition the model appends one line to the state file naming the
user utterance it read as the basis. Nothing enforces this; it exists so a
reader outside the session can see what the transition rested on.

**Skills.** The `verify` role carries a `skills/` directory,
`verify-cycle/skills/<name>/SKILL.md`: `verify-cycle` (the state-machine
walkthrough), `finding-record` (per-attempt outcome and finding recording),
and `severity-classification` (attaching `blocking`/`advisory` to an
escalated finding). A skill's artifact write is never gated by the
`PreToolUse` transition check above — only the write that changes the
`status` field in the state file is checked against the transition table.

**Bootstrap convention.** Same as `review-agent-rulebook`'s own: when the
role's state file does not exist, the current state is the synthetic
literal `(none)`. `transition-rules.md` carries a row whose `from` is
`(none)`, naming verify's legal initial state (`idle`); the write that
creates the state file is allowed exactly when such a row exists for the
target.

### `verify`

**Carrying artifact**: the verify record file; state in its frontmatter
field `status`.

**States**: `idle`, `reproducing`, `reproduced`, `cleared` — taken verbatim
from `docs/specs/role-handoff-contract.md` §2's `verify-record` row's
`loop_state` vocabulary.

**Transition table**:

| From | To | Fires on |
|---|---|---|
| `idle` | `reproducing` | coding and qa have both produced artifacts for the subject (contract §3's first verify wake); agent begins independent reproduction attempts |
| `reproducing` | `reproducing` | **gated, self-loop** — verify needs evidence/access the coding or qa role must grant before a specific reproduction attempt can continue |
| `reproducing` | `reproduced` | every reproduction attempt taken up in this pass carries a recorded outcome (reproduced or not-reproduced) |
| `reproduced` | `reproduced` | **gated, self-loop** — a finding addressed to verify, or a disputed reproduction, is re-examined and re-recorded inline against the same attempt |
| `reproduced` | `cleared` | **gated** — no unresolved `severity: blocking` finding remains, or the user explicitly waives one under contract §8 |

**Rejection rule**: `reproducing -> reproduced` fails unless every
reproduction attempt taken up in this pass carries exactly one outcome of
`reproduced` or `not-reproduced`, with an evidence pointer.
`reproduced -> cleared` fails unless the model judges, from the user's own
turn, that no unresolved blocking finding remains or that the user has
explicitly waived one.

**Refuses in every state**: editing, patching, or "helpfully fixing" the
code under verification — this role reports what it reproduces, it does
not build. Letting a clean `review-record` stand in for verify's own
independent reproduction attempt — a per-requirement `Present` verdict from
review is context, never grounds to skip verify's own attempt.

## Reference

Sourcing for verify's role definition is
`docs/specs/role-handoff-contract.md` §2 (`verify-record` row), §3
(WAKES-ON), §4 (DEPENDS-ON and the review-independence rule), and §11
(owned path). Where this document and the contract disagree, the contract
is authoritative and this file should be brought back into line with it,
mirroring `review-agent-rulebook`'s own stated precedence rule for its
`docs/specs/state-machine.md`.
