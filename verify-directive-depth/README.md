# verify-directive-depth

Deepens the `verify` role's directive: the USE-WHEN (phase 1, attempt scoping) and
HAND-OFF (phase 2, outcome recording) facets are restructured into explicit numbered
steps, a judgment criterion, and a "never" line, so attempt sourcing and outcome
recording are enforced at the directive level rather than left implicit. It does not
add its own gate — the SessionStart hook only emits the directive text.

Kill switch:

```
export VERIFY_DIRECTIVE_DEPTH_OFF=1
```

This plugin composes with sibling plugins `verify-outcome-gate`, `verify-finding-gate`,
`verify-state-guard`, and the base `verify` plugin — each owns one methodology element;
this one owns directive depth only, no gate of its own.
