---
axis: independence-from-upstream-verdicts
rule_count_floor: 8
---

# Preserving independence from coding/qa/review's prior verdicts

Research trail: cognitive-bias-in-testing literature (MagicPod confirmation-bias-in-QA article, Xebia bias-mapping article, PractiTest cognitive-bias article, Katalon cognitive-biases guide). All fetched/searched this session.

## Rules

1. Treat a review requirement marked Present as a claim to independently test, not as a fact already settled — confirmation bias leads testers to "seek evidence that confirms preconceptions while dismissing contradictory information," and a role whose whole purpose is catching what review's pass missed cannot let review's own verdict pre-shape the attempt. source: https://blog.magicpod.com/confirmation-bias-in-qa-unveiling-the-hidden-traps

2. When devising a self-devised attempt, deliberately include at least one edge case or negative path rather than only the paths a positive/happy-path bias would suggest — testers under confirmation bias "prefer positive tests, cherry-pick tests that confirm a hypothesis, or avoid edge cases that could fail," and this role exists specifically to cover what that bias would skip. source: https://blog.magicpod.com/confirmation-bias-in-qa-unveiling-the-hidden-traps

3. Re-derive a closed_checks entry from primary evidence rather than citing it against a stale sha, and do not let a prior "closed" status make a re-derivation feel unnecessary — collaborative review checkpoints work because they let "testers challenge each other's decisions or identify overlooked risks," which requires actually looking, not deferring to the earlier verdict's label. source: https://xebia.com/blog/mapping-biases-to-testing-confirmation-bias/

4. When an attempt comes up not-reproduced, resist the pull to stop looking for other candidate attempts on the same area just because the first one cleared — cognitive-bias guidance frames bias mitigation as needing "diverse viewpoints" and "broader testing approaches" precisely because one clean result creates pressure to treat the whole area as settled. source: https://www.practitest.com/resource-center/article/cognitive-biases-in-software-testing/

5. Do not adjust an attempt's scope or rigor based on which role (coding, qa, or review) is credited with the underlying work — bias mitigation strategies emphasize "tester rotation" and structural independence specifically because familiarity with an author or team correlates with reduced scrutiny, and this role's value is exactly the removal of that correlation. source: https://katalon.com/resources-center/blog/cognitive-biases-in-software-testing

6. When qa's defect report and review's Present verdict disagree about the same area, attempt both independently rather than resolving the disagreement by picking the more authoritative-sounding source — the point of independent verification is that "two sets of eyes are always better than one — especially when it comes to spotting biased assumptions," and deferring to authority instead of evidence defeats that. source: https://blog.magicpod.com/confirmation-bias-in-qa-unveiling-the-hidden-traps

7. Record a not-reproduced outcome with the same evidentiary rigor as a reproduced one (what was tried, what state, what result) rather than a bare label — asymmetric rigor (detailed reproduced findings, terse not-reproduced notes) is itself a confirmation-bias signature: more effort spent justifying the outcome that "found something" than the one that didn't.

8. When time or attempt budget is tight, do not let it default-favor citing closed_checks over re-deriving — cite-and-skip is legitimate only when the sha genuinely matches; under time pressure the incentive to declare a match without checking is exactly the shortcut collaborative-review and rotation practices are designed to interrupt. source: https://xebia.com/blog/mapping-biases-to-testing-confirmation-bias/

9. **REMOVAL**: Stop treating a "clean" review record (no open items) as lowering the bar for how many self-devised attempts this pass should include — a clean upstream record is not evidence of absence, and letting it shrink the attempt list re-imports the deference rule 3 and rule 6 forbid, just earlier in the process (at planning instead of at citation).

10. **REMOVAL**: Retire the practice of writing an attempt's expected outcome before running it in prose that leaks into the outcome record (e.g. phrasing that presumes reproduced or not-reproduced going in) — pre-committing to an expected result in the write-up is a textbook confirmation-bias vector, and the fix is writing the attempt's target claim only, with the outcome slot genuinely open until the attempt runs. source: https://www.functionize.com/blog/the-impact-of-cognitive-bias-on-software-testing
