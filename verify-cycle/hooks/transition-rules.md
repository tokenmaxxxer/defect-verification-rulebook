# verify role — transition table

Single source of truth for legal `verify-record.md` `status` transitions.
Read by both `inject-transition-rules.sh` (UserPromptSubmit) and
`state-gate.sh` (PreToolUse). State set and `loop_state` vocabulary
(`idle`, `reproducing`, `reproduced`, `cleared`) taken verbatim from
`docs/specs/role-handoff-contract.md` section 2's `verify-record` row.

`actor` is `user` when the transition requires the user to have said
something in their own turn; `agent` when the agent may make it unprompted.
There is no approval-token mechanism: for an `actor: user` row, the model
reads the user's own turn, judges the precondition met, and records — as
one line appended to `verify-record.md` — the user utterance it read as
the basis for the transition. Nothing mints or checks a token for this;
nothing enforces that the recorded line is accurate.

from | to | actor | precondition
--- | --- | --- | ---
(none) | idle | agent | verify-record.md does not yet exist; agent creates it to begin the role at idle
idle | reproducing | agent | coding and qa have both produced artifacts for this subject (contract §3's first verify wake); agent begins attempting reproduction of what coding built and what qa reported, independent of what review already concluded
reproducing | reproducing | user | verify needs evidence/access the coding or qa role must grant before a specific reproduction attempt can continue — stays in reproducing, not its own state
reproducing | reproduced | agent | every reproduction attempt taken up in this pass carries a recorded outcome (reproduced, with evidence, or not reproduced) — never a bare pass/fail with no attempt recorded
reproduced | reproduced | user | a `finding` addressed to verify, or a disputed reproduction, is re-examined; the outcome is re-recorded inline against the same attempt, not a new state
reproduced | cleared | user | user (or the pre-land gate wake, contract §3's second verify wake) confirms no unresolved `severity: blocking` finding remains, or explicitly waives one under contract §8's human-judgment seat
