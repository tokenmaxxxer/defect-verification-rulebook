# tokenmaxxxer / verify-agent-rulebook

A Claude Code plugin marketplace implementing the `verify` agent role
specified in the tokenmaxxxer org's `docs/specs/role-handoff-contract.md`:
an agent that adversarially attempts to reproduce defects in a change that
coding and qa have already produced artifacts for — independent of, and
never overridden by, a clean verdict from `review`.

## The role

**Decides**: whether a defect exists in what was built, found by
independently attempting to reproduce it — never a re-litigation of
review's per-requirement verdict, never a holistic code-quality judgment,
and never a fix.

**Given to start**: what coding and qa have already produced for the
subject, once both exist. verify depends on `coding-record`, `qa-record`,
and `review-record` — it reads what was built, what qa already tried, and
what review concluded, then goes looking for what none of them caught.

**Produces**: a per-attempt `reproduced`/`not-reproduced` outcome, and —
when a defect reproduces — an inline `finding` block addressed to coding,
carrying `severity: blocking` or `advisory`.

**Prevents**: a defect that review's per-requirement pass and qa's own
reproduction attempts both missed from reaching landing unchallenged. A
`verify` finding with `severity: blocking` is not overridden by a clean
`review-record` — review's and verify's verdicts are independent, per
`docs/specs/role-handoff-contract.md` §4.

Full state machine, transition table, rejection rules, and the
path-ownership enforcement are in
[`docs/specs/state-machine.md`](docs/specs/state-machine.md).

## How it works

Two cooperating hooks in the `verify-cycle` plugin implement the state
machine:

- **`hooks/inject-transition-rules.sh`** (`UserPromptSubmit`) — reads
  `transition-rules.md` and the current state out of `verify-record.md`,
  and emits a compact block naming the current state and the legal
  transitions out of it. Never exits silently, even on a load failure.
- **`hooks/state-gate.sh`** (`PreToolUse`, matcher `.*`) — refuses any
  write reaching `verify-record.md` whose resulting transition is not a
  row in `transition-rules.md`, evaluated against the target path
  regardless of which tool performs the write (a `Bash` redirect, `sed
  -i`, `cp`, `mv`, or `tee` targeting the state file is caught the same
  way a `Write`/`Edit` call is). Separately, it refuses any write that
  targets another role's owned subject-scoped record path under
  `docs/reports/records/<subject>/`, per contract §11.

Both hooks fail closed: malformed input, an unreadable state file, or a
missing repo-local contract all deny the action rather than allowing it.

## Install

```
curl -fsSL https://raw.githubusercontent.com/tokenmaxxxer/verify-agent-rulebook/main/install.sh | bash
```

This registers the `tokenmaxxxer-verify` marketplace and installs
`verify-agent-env` (which pulls in `verify-cycle` as a dependency) at
**user scope**. It applies to your account on every machine-local session;
it does not travel with a repo and does not reach Claude Code on the web or
Slack cloud sessions. It names no other repository and no other
marketplace.

The script prefers a real `claude` CLI (standalone, or the binary bundled
inside the VSCode extension) if it finds one. If no `claude` binary is found
— or `TOKENMAXXXER_SETTINGS_ONLY=1` is set to force it — it falls back to
writing `~/.claude/settings.json` directly: it resolves and prefix-checks
the settings path against your home directory before writing anything,
aborts untouched on a parse failure of an existing file, backs the file up
first, and writes through a symlink rather than replacing it.

Or, from any Claude Code session, the equivalent by hand:

```
/plugin marketplace add tokenmaxxxer/verify-agent-rulebook
/plugin install verify-agent-env@tokenmaxxxer-verify
```

`install.sh --help` prints usage. The only other input it reads is
`TOKENMAXXXER_SETTINGS_ONLY=1`.

## Writing the settings by hand

```json
{
  "extraKnownMarketplaces": {
    "tokenmaxxxer-verify": {
      "source": { "source": "github", "repo": "tokenmaxxxer/verify-agent-rulebook" }
    }
  },
  "enabledPlugins": {
    "verify-agent-env@tokenmaxxxer-verify": true
  }
}
```

## The carrying artifact

`verify-record.md`, at the root of the project under verification. Its
frontmatter `status` field holds the state (`idle`, `reproducing`,
`reproduced`, `cleared`); below it, one block per reproduction attempt
carries `attempt:`, `outcome:`, and `evidence:`. See
`docs/specs/state-machine.md` for the exact shape and every gate rule.

## Handoff protocol

The authoritative contract is the work repo's own
`docs/specs/role-handoff-contract.md` — the gate resolves exactly one root
(the git root of the current working directory) and reads that file inside
it; if it is absent, handoff-protocol actions are refused rather than
silently passed. This section is not a pinned excerpt of any particular
contract; it describes only how the verify role behaves against whatever
contract the work repo carries.

### WAKES-ON

verify wakes on two conditions, per contract §3's table: coding and qa have
both produced artifacts for a subject (first wake), and again before
landing, as a pre-land gate (second wake). Like every role's WAKES-ON row,
this is human-consulted — no automated watcher exists yet in this operating
model. A human reads the board, matches it against contract §3's table,
and opens `verify` when the row is satisfied. This document describes that
behavior in prose; it does not wire any automated trigger for it.

### READ / DEPENDS-ON / NEVER-OVERWRITE

**READ (broad).** Per contract §4: verify may read every other role's
record unconditionally, for context — including `review-record`'s verdicts
and `hypothesis`'s and `build-proposal`'s narrative sections. Reading them
is never itself a violation.

**DEPENDS-ON (narrow, contract §4).** verify depends on `coding-record`,
`qa-record`, and `review-record` — what was built, what qa already tried,
and what review concluded. What a `finding`'s basis may cite is narrower
than what verify may read: its own independent reproduction attempt, never
a restatement of another role's prior conclusion standing in for one. Per
the contract's own words: a `verify` finding with `severity: blocking` is
"not overridden by a `review-record` in `loop_state: reported` with a
clean verdict — review's and verify's verdicts are independent."

**NEVER-OVERWRITE (contract §11).** verify writes only
`docs/reports/records/<subject>/verify.md` (`kind: verify-record`,
including inline `finding` blocks). An existing record already at a path
verify does not own under `docs/reports/records/` is refused to write,
reported as a conflict, and never overwritten.

### Blackboard record spec

`verify-record` at `docs/reports/records/<subject>/verify.md`. Its
`loop_state` vocabulary, quoted verbatim from contract §2's table:
`idle,reproducing,reproduced,cleared`. Per the same table's "required
fields beyond common header" column for `verify-record`: what was
attempted, what reproduced (if anything), and reproduction evidence (repro
steps, commit sha, run output).

### Finding back-edge participation

verify is a major finding producer. Findings addressed to coding live as
inline blocks within `verify.md` itself — never as separate files — per
contract §2's `finding` row: "inline block within the addressing role's
own record."

Required finding fields, quoted from the same table row: `requirement`,
`verdict` (`Present|Surface|Absent|Incorrect|Unverifiable`), `evidence`,
`rationale`, `spec_vs_built` (required only when `verdict: Incorrect`),
`addressed_to: coding`, `severity: blocking|advisory`.

### Loop-termination rule (contract §6)

A wake is consumed only by writing the resulting record entry (a
`loop_state` change, a new `finding`, or equivalent); an unchanged board
wakes no one. Per contract §6's verify↔coding extension: "a `verify` wake
is not a valid consumption unless it produces either a `cleared`
`loop_state` (no unresolved reproduced findings) or a new/re-affirmed
`finding`. A blocking finding resolves only when coding's
`finding-response` supplies fix evidence that verify re-observes, or the
human explicitly waives it under section 8's human-judgment seat."

## Kill switch

```sh
export VERIFY_CYCLE_DISABLE=1
```

Disables both hooks.

## Repo layout

- `install.sh` — the one-shot installer described above.
- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `verify-cycle/` — the role plugin: `hooks/`, `skills/verify-cycle/`.
- `verify-agent-env/` — the bundle plugin; no code of its own, lists
  `verify-cycle` as a dependency.
- `docs/` — `specs/` (state machine, authoritative), `handbooks/`,
  `decisions/`, `reports/`, `proposals/`, `_assets/`.

## Scope

This repository is fully self-contained: no shared code, no cross-repo
dependency, and no file shared with `coding-agent-rulebook`,
`qa-agent-rulebook`, `review-agent-rulebook`, or any sibling
`<role>-agent-rulebook` repository. It never reads another role's
repository, and it never talks to another agent directly — the user
carries verify's conclusion forward by hand.
