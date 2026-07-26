# docs

Documents in this repository live in one of six lifetime-based buckets,
following the `doctrine` convention from `coding-agent-rulebook`.

| Directory | What lives there |
|---|---|
| `decisions/` | Why a hard-to-reverse choice was made. Fixed at the moment of the decision. |
| `handbooks/` | Current state. Edited from now on to stay true. |
| `reports/` | An observation fixed to a point in time. |
| `specs/` | Design and specification. Updated in the same PR as the code. |
| `proposals/` | Not adopted yet — drafts, RFCs. |
| `_assets/` | Images and attachments. |

The authoritative document for this repository is
[`docs/specs/state-machine.md`](specs/state-machine.md): the `verify` role's
carrying artifact, its four states, its gated transitions, and its standing
adversarial-reproduction discipline.
