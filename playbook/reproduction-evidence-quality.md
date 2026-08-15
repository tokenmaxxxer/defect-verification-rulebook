---
axis: reproduction-evidence-quality
rule_count_floor: 8
---

# Reproduction-evidence quality for a defect attempt

Research trail: bug-report/reproduction-steps best-practice literature (QA Wolf bug-report guide, Marker.io steps-to-reproduce guide, TestDevLab reproduction-matters article, Supportbench reproduction-steps standardization guide, QATestLab reproduction-steps course material), plus (rules 11-13, 2026-08-14) adoption-evidence survey of the Claude Code plugin/skill ecosystem's own verification tooling (Anthropic's official plugin marketplace's PR-review toolkit and a widely-installed root-cause-analysis skill). All fetched/searched this session.

## Rules

1. Start every reproduction attempt from a known, stated state and list exact inputs/values/timing in a numbered sequence — precise steps "eliminate ambiguity and prevent back-and-forth clarification," which for verify means the evidence pointer coding receives is actionable without a follow-up round-trip. source: https://marker.io/blog/steps-to-reproduce-a-bug

2. Reduce a reproduction to its minimum necessary path before recording it — "cutting unnecessary actions, like reducing twenty steps down to five, not only simplifies the report but also makes verification quicker" — a bloated repro buries the one step that actually matters and slows down any later re-check against a new sha. source: https://www.qawolf.com/blog/what-makes-a-great-bug-report

3. Keep a repro within roughly 2-8 steps where the underlying path allows it; if a genuine minimal path exceeds that, that itself is worth noting rather than silently padding around it — practitioner guidance treats "2-3 to 7-8 steps" as the normal range for a well-reduced repro. source: https://www.qawolf.com/blog/what-makes-a-great-bug-report

4. Record expected vs. actual result explicitly, not just the steps — a complete report needs "expected vs. actual results, numbered reproduction steps, visual evidence, and technical logs" together, because steps alone let a reader reproduce the symptom without confirming it's the same symptom the attempt targeted. source: https://www.qawolf.com/blog/what-makes-a-great-bug-report

5. Attach the actual artifact (command output, log excerpt, run transcript) rather than a paraphrase of what it showed — session artifacts "preserve the state of the system at the time the bug occurred," and a paraphrase loses exactly the detail a later re-derivation would need to confirm the claim independently. source: https://www.qawolf.com/blog/what-makes-a-great-bug-report

6. When an attempt is intermittent, record the actual hit rate observed ("reproduced N times out of M attempts") instead of collapsing it to a bare reproduced/not-reproduced — "if it only happens sometimes, record the reproduction rate," since a defect that fires 1/10 times is evidence-wise a different claim than one that fires 10/10, even though the outcome vocabulary itself stays three-valued. source: https://www.testdevlab.com/blog/issue-reproduction-why-reproducing-bugs-matter

7. Capture the environment the attempt actually ran in (commit sha, build/run context) alongside the repro steps, not as an afterthought — environment details "for software bugs" (application version, build number, dev/test environment) are load-bearing because the same steps can reproduce on one sha and not another, and an undated repro cannot be re-checked against a moved-forward branch. source: https://www.testdevlab.com/blog/issue-reproduction-why-reproducing-bugs-matter

8. When an attempt does not reproduce on the first pass, do not immediately record not-reproduced — confirm the starting state matches what the candidate source (qa report, review requirement, self-devised path) actually described before concluding the claim doesn't hold, since a reproduction failure caused by a mismatched starting state is a false not-reproduced, not evidence the defect is absent.

9. **REMOVAL**: Stop accepting a screenshot or log excerpt with no accompanying numbered steps as sufficient evidence for a reproduced finding — visual/log evidence supplements steps, it does not substitute for them; a finding with evidence but no reconstructable path is not independently re-checkable by coding, which is the whole point of citing an evidence pointer instead of a paraphrase. source: https://www.qawolf.com/blog/what-makes-a-great-bug-report

10. **REMOVAL**: Retire any repro record that lists actions taken during exploration rather than the reduced minimal path — the exploration trail (everything tried before the minimal path was found) is process, not evidence; carrying it into the finding record reintroduces the twenty-steps-instead-of-five bloat the minimal-path discipline exists to cut. source: https://www.qawolf.com/blog/what-makes-a-great-bug-report

11. Judge a "Present" requirement or a green test suite by whether it exercised the claimed behavior, not by whether it executed the claimed code path — a coverage report that counts lines touched treats a path run-through-with-no-assertion the same as a path actually checked, and an attempt that only confirms the path executed (without confirming the outcome it produced) is not yet a not-reproduced verdict on the underlying claim.

12. When a not-reproduced or reproduced verdict rests on more than one causal step (e.g. "the handler silently swallows the error, so the caller sees success" is two linked claims), attach evidence to each linked step individually rather than one evidence pointer for the chain's end state — a single end-state artifact can be consistent with several different causal chains, and only per-step evidence lets a reader confirm which chain actually held.

13. Treat an empty or pass-through catch/rescue block, a caught-and-logged-only error, or a fallback that substitutes a default value for a failure as its own attempt category worth checking even when no qa report or review requirement names it — this class of defect produces no crash and no failing assertion by construction, so it is systematically under-represented in qa- and review-sourced candidate lists and needs to appear as a self-devised attempt on its own.
