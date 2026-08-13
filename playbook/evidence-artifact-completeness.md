---
axis: evidence-artifact-completeness
rule_count_floor: 8
---

# Evidence-artifact completeness for a reproduction attempt

Research trail: adoption-evidence survey of reproduction/debugging tooling
practitioners actually use (rr record-and-replay debugger, 10,421 GitHub
stars, github.com/rr-debugger/rr; Playwright trace viewer, 94,081 GitHub
stars / ~79M weekly npm downloads, github.com/microsoft/playwright,
playwright.dev/docs/trace-viewer; automatic-context bug-capture tools
surveyed across jam.dev, marker.io, bugherd.com per multi-source 2026
comparison coverage; deterministic severity/priority matrix tooling per
qamadness.com and softwaretestershub.in). All fetched this session
2026-08-13.

## Rules

1. Capture the reproduction artifact once, at attempt time, as a single
   self-contained recording rather than relying on a live re-run to
   reproduce the same evidence later — a record-and-replay design lets a
   failure be inspected and re-inspected without needing the original
   failing conditions to recur on demand, and an attempt whose only
   evidence is "run it again and see" is not independently re-checkable
   once the branch has moved. source: https://github.com/rr-debugger/rr

2. Bundle every signal available at attempt time (steps, console/log
   output, the state snapshot, environment/sha) into one evidence pointer
   rather than splitting them across separate fields a reader must
   reassemble — a trace-viewer-style artifact carries screenshots, DOM
   state, console, and network together specifically because a bug's
   evidence is the intersection of those signals, not any one alone; an
   evidence pointer that gives only a log line without the surrounding
   state forces the reader to re-derive context the attempt already had.
   source: https://playwright.dev/docs/trace-viewer

3. Record the run environment (commit sha, run/build context) at the
   moment the attempt is made, not reconstructed afterward from memory —
   automatic-capture bug-report tooling captures environment data
   alongside the recording specifically because a reconstructed
   environment is a guess, while a captured one is a fact the evidence
   pointer can be checked against on a later, moved-forward sha.

4. When an attempt could be captured as a durable artifact (a log
   excerpt, a run transcript, a diff) rather than only described in
   prose, capture the artifact — a description of what a recording showed
   is strictly weaker than the recording, and this role's evidence
   pointer exists precisely so coding does not have to trust a paraphrase.

5. Treat a `blocked: needs-repro-access` outcome as still needing an
   artifact where one exists — the exact command attempted, its actual
   output (even a permission error or a missing-fixture message) — rather
   than a bare prose note; the same "capture what's actually there, don't
   paraphrase" discipline that governs `reproduced` evidence applies to
   the two-value outcomes below it.

6. When a candidate attempt names a specific runtime state (a flag, a
   config, a data fixture), state that starting state explicitly in the
   attempt record before the steps — an artifact is only re-checkable
   against a state that was itself written down; an implied starting
   state is not a fact a later reader can verify.

7. Do not let evidence-artifact richness change what counts as
   `reproduced` — a full trace bundle is a stronger *pointer* to the same
   three-value outcome, never grounds for treating a richly-captured
   not-reproduced attempt as more conclusive than a thinly-captured one,
   or vice versa; artifact completeness is a evidence-quality axis, not
   an outcome-vocabulary axis.

8. State which artifact type backs a given evidence pointer (recording,
   transcript, log excerpt, diff, command output) rather than leaving the
   evidence field's shape implicit — an unlabeled evidence blob forces a
   reader to guess whether they are looking at the whole picture or one
   fragment of it, which is exactly the ambiguity a bundled-artifact
   design exists to remove.

9. **REMOVAL**: Retire accepting "see the linked recording" with no
   accompanying steps/state summary as a complete attempt record — a
   recording supplements the written attempt, it does not substitute for
   stating what state and steps were used to produce it; a reader without
   access to play the recording still needs the written record to be
   self-sufficient.

10. **REMOVAL**: Stop treating environment capture as optional metadata
    tacked onto an already-written evidence pointer — capture it as part
    of making the attempt, not as a follow-up amendment, since a
    reconstructed-after-the-fact environment note carries exactly the
    accuracy risk the "capture at attempt time" design move exists to
    avoid.
