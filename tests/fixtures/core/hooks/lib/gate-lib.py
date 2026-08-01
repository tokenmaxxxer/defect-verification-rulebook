# TEST FIXTURE — pinned copy of tokenmaxxxer-core's core/hooks/lib/gate-lib.py
# (issue-72, main@22a7cad); see gate-lib.sh's fixture header in this same
# directory for why this exists and what it is not.
#
# Sourceable Python helper for the gate-house standard (issue-72). Loaded
# via importlib by a gate's own Python payload (never imported by dotted
# module name — the filename carries a hyphen on purpose, matching the
# existing core/hooks/*.sh heredoc-Python convention rather than becoming
# a normal package):
#
#   import importlib.util, os
#   _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
#   gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
#   gate_lib.gate_parse_json_or_deny(raw, deny)
#
# Reference only, never copy (docs/handbooks/canon-scripts.md).

import json
import os
import posixpath


def gate_parse_json_or_deny(raw, deny):
    """Parse `raw` as a JSON object, or call deny(msg) (expected to exit).

    Codifies the malformed-JSON-deny convention already uniform across
    core's own gates (issue-72 survey section 5): a `json.loads` failure,
    non-object top level, or empty payload all deny rather than proceed on
    a best-effort guess.
    """
    if not raw:
        deny("empty tool-use payload; cannot evaluate the gate on nothing")
    try:
        event = json.loads(raw)
    except ValueError:
        deny("the tool-call payload is not valid JSON; refusing rather than "
             "guessing what was about to be written")
    if not isinstance(event, dict):
        deny("the tool-call payload is not a JSON object; failing closed")
    return event


def gate_normalize_path(root, path):
    """Resolve `path` (absolute, relative, or `./`-prefixed) against `root`
    to a root-relative, forward-slash tail, or None if it resolves outside
    root.

    Generalizes the most defensive of the three normalize techniques
    issue-72's survey (section 3) found scattered across core's gates
    (realpath-then-strip-root, record-fields-gate.sh's `resolve()`): both a
    relative `docs/issue-72/x.md` and an absolute
    `/home/u/repo/docs/issue-72/x.md` normalize to the same tail
    `issue-72/x.md`, and `./`-prefixed inputs collapse the same way via
    posixpath.normpath. This does NOT touch the real filesystem (no
    os.path.realpath / symlink resolution) — callers needing symlink-safe
    resolution against a real project root should still realpath their
    own `root` before calling this; this function's contract is pure
    string/path-algebra so it is usable in a test harness with no
    filesystem fixture at all.
    """
    r = posixpath.normpath(root.replace("\\", "/"))
    n = path.replace("\\", "/")
    a = n if posixpath.isabs(n) else posixpath.join(r, n)
    a = posixpath.normpath(a)
    if a == r:
        return ""
    prefix = r + "/"
    if a.startswith(prefix):
        return a[len(prefix):]
    return None


def _apply_replace(text, old, new, replace_all):
    """One Edit's old_string -> new_string, honoring replace_all.

    The issue-72-confirmed bug (survey section 6): record-fields-gate.sh
    always did `text.replace(old, new, 1)` — first occurrence only,
    `replace_all` never read. The tool's own documented behavior is
    `text.replace(old, new)` (every occurrence) when replace_all is true,
    first-occurrence-only otherwise. Returns (new_text, ok); ok is False
    when old_string does not occur in text (mirrors the failure the
    original code detected via `o in current`/`o not in text`).
    """
    if old not in text:
        return text, False
    if replace_all:
        return text.replace(old, new), True
    return text.replace(old, new, 1), True


def gate_reconstruct_write(tool, tool_input, current_content):
    """Reconstruct the resulting content of a Write/Edit/MultiEdit/
    NotebookEdit tool call.

    Returns (new_text, ok). ok is False when the tool_input's shape makes
    the result undeterminable (e.g. an Edit whose old_string is not present
    in current_content, or an unsupported tool) — callers should deny
    rather than silently pass such a write through, the same fail-closed
    posture record-fields-gate.sh already takes today.

    Covers, per issue-72's four-tool requirement:
      Write        -> tool_input["content"] verbatim.
      Edit         -> one old_string/new_string replace, honoring
                       tool_input.get("replace_all", False).
      MultiEdit    -> tool_input["edits"], applied in order, each edit's
                       own replace_all honored independently.
      NotebookEdit -> not reconstructed as a single text blob (a notebook
                       is a sequence of cells, not one string); returns the
                       edited cell's new source as new_text when
                       edit_mode is "insert" or "replace" (the two modes
                       that carry a resulting cell source), so a caller
                       checking cell-level content (e.g. a field check on
                       a record kept as a single markdown cell) has
                       something to check instead of silently exit-0
                       passthrough (issue-72 survey section 6: no gate in
                       this repo reconstructs NotebookEdit at all today).
    """
    if tool == "Write":
        c = tool_input.get("content")
        if isinstance(c, str):
            return c, True
        return None, False

    if tool == "Edit":
        o, n = tool_input.get("old_string"), tool_input.get("new_string")
        if not isinstance(o, str) or not isinstance(n, str) or current_content is None:
            return None, False
        replace_all = bool(tool_input.get("replace_all", False))
        text, ok = _apply_replace(current_content, o, n, replace_all)
        return (text, True) if ok else (None, False)

    if tool == "MultiEdit":
        edits = tool_input.get("edits")
        if not isinstance(edits, list) or current_content is None:
            return None, False
        text = current_content
        for e in edits:
            if not isinstance(e, dict):
                return None, False
            o, n = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(n, str):
                return None, False
            replace_all = bool(e.get("replace_all", False))
            text, ok = _apply_replace(text, o, n, replace_all)
            if not ok:
                return None, False
        return text, True

    if tool == "NotebookEdit":
        new_source = tool_input.get("new_source")
        edit_mode = tool_input.get("edit_mode", "replace")
        if edit_mode in ("insert", "replace") and isinstance(new_source, str):
            return new_source, True
        return None, False

    return None, False
