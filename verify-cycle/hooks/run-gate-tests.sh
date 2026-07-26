#!/usr/bin/env bash
# Gate tests for verify-cycle/hooks/state-gate.sh.
#
# Covers, mirroring review-agent-rulebook's
# docs/proposals/2026-07-29-same-state-gate-and-state-file-policy.md,
# re-keyed to verify's own state vocabulary (idle, reproducing, reproduced,
# cleared):
#  (a) a same-state write to the state file on a state with NO self-loop
#      row must be DENIED.
#  (b) a same-state write to the state file on a state that DOES have a
#      self-loop row (reproducing|reproducing, reproduced|reproduced)
#      must be ALLOWED.
#  (c) a normal table-legal transition must be ALLOWED.
#  (d) a transition absent from the table must be DENIED.
#  (e) a Bash-shaped write whose target resolves to the state file is
#      judged the same as the Write-shaped one.
#  (f) malformed hook JSON is DENIED with visible output, never a silent
#      exit 0.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HOOK_DIR/state-gate.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

pass=0
fail=0

run_gate() {
  # $1 = root dir, $2 = payload json
  CLAUDE_PROJECT_DIR="$1" bash "$GATE" <<<"$2"
}

expect_deny() {
  local name="$1" root="$2" payload="$3"
  local out rc
  out="$(run_gate "$root" "$payload" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $name — expected deny (non-zero exit), got exit 0. Output: $out"
    fail=$((fail+1))
  else
    echo "PASS: $name (exit $rc)"
    pass=$((pass+1))
  fi
}

expect_allow() {
  local name="$1" root="$2" payload="$3"
  local out rc
  out="$(run_gate "$root" "$payload" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $name — expected allow (exit 0), got exit $rc. Output: $out"
    fail=$((fail+1))
  else
    echo "PASS: $name"
    pass=$((pass+1))
  fi
}

new_root() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  echo "$d"
}

write_state() {
  # $1 = root, $2 = status
  printf 'status: %s\n' "$2" > "$1/verify-record.md"
}

write_contract() {
  # $1 = root. Creates a present-but-minimal
  # docs/specs/role-handoff-contract.md so Rule 0 (contract-presence)
  # does not itself refuse the call — needed for tests that exercise
  # something OTHER than Rule 0, notably the §11 owned-path tests below.
  mkdir -p "$1/docs/specs"
  printf '# role-handoff-contract\n\n## 11. NEVER-OVERWRITE\n\nA role owns exactly its own docs/reports/records/<subject>/<role>.md slot.\n' > "$1/docs/specs/role-handoff-contract.md"
}

# --- (a) same-state write, no self-loop row (idle | idle) -> DENY --------
root="$(new_root)"
write_state "$root" "idle"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: idle\n"}}
JSON
)
expect_deny "(a) same-state idle->idle, no self-loop row" "$root" "$payload"

# --- (b) same-state write, HAS self-loop row (reproducing | reproducing) -> ALLOW
root="$(new_root)"
write_state "$root" "reproducing"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: reproducing\nnote: evidence requested\n"}}
JSON
)
expect_allow "(b) same-state reproducing->reproducing, has self-loop row" "$root" "$payload"

root="$(new_root)"
write_state "$root" "reproduced"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: reproduced\nnote: finding re-examined\n"}}
JSON
)
expect_allow "(b) same-state reproduced->reproduced, has self-loop row" "$root" "$payload"

# --- (c) normal table-legal transition -> ALLOW ---------------------------
root="$(new_root)"
write_state "$root" "idle"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: reproducing\n"}}
JSON
)
expect_allow "(c) legal transition idle->reproducing" "$root" "$payload"

# --- (d) transition absent from the table -> DENY -------------------------
root="$(new_root)"
write_state "$root" "idle"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: cleared\n"}}
JSON
)
expect_deny "(d) illegal transition idle->cleared" "$root" "$payload"

# --- (e) Bash-shaped write resolving to the state file, judged the same --
# (e1) Bash write reaching a state with a legal outgoing transition -> ALLOW
root="$(new_root)"
write_state "$root" "idle"
payload=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"printf 'status: reproducing\\n' > $root/verify-record.md"}}
JSON
)
expect_allow "(e1) Bash write reaching state file, legal outgoing transition exists" "$root" "$payload"

# (e2) Bash write reaching a state with NO legal outgoing transition -> DENY
root="$(new_root)"
write_state "$root" "cleared"
payload=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"printf 'status: idle\\n' > $root/verify-record.md"}}
JSON
)
expect_deny "(e2) Bash write reaching state file, no legal outgoing transition (terminal state)" "$root" "$payload"

# --- (f) malformed hook JSON -> DENY, visible output, never silent -------
root="$(new_root)"
out_f="$(run_gate "$root" '{not valid json' 2>&1)"
rc_f=$?
if [ "$rc_f" -eq 0 ]; then
  echo "FAIL: (f) malformed JSON — expected deny, got exit 0. Output: $out_f"
  fail=$((fail+1))
elif [ -z "$out_f" ]; then
  echo "FAIL: (f) malformed JSON — denied (exit $rc_f) but produced no visible output"
  fail=$((fail+1))
else
  echo "PASS: (f) malformed JSON denied with visible output (exit $rc_f)"
  pass=$((pass+1))
fi

# --- (g) existing state file with value "(none)" -> DENY, rules-not-loaded
root="$(new_root)"
write_state "$root" "(none)"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: idle\n"}}
JSON
)
out_g="$(run_gate "$root" "$payload" 2>&1)"
rc_g=$?
if [ "$rc_g" -eq 0 ]; then
  echo "FAIL: (g) existing status:(none) — expected deny, got exit 0. Output: $out_g"
  fail=$((fail+1))
elif ! printf '%s' "$out_g" | grep -q "rules could not be loaded"; then
  echo "FAIL: (g) existing status:(none) — denied but wrong message. Output: $out_g"
  fail=$((fail+1))
else
  echo "PASS: (g) existing status:(none) denied with rules-could-not-be-loaded message"
  pass=$((pass+1))
fi

# --- (h) existing state file with empty status value -> DENY, rules-not-loaded
root="$(new_root)"
printf 'status:\n' > "$root/verify-record.md"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: idle\n"}}
JSON
)
out_h="$(run_gate "$root" "$payload" 2>&1)"
rc_h=$?
if [ "$rc_h" -eq 0 ]; then
  echo "FAIL: (h) existing empty status — expected deny, got exit 0. Output: $out_h"
  fail=$((fail+1))
elif ! printf '%s' "$out_h" | grep -q "rules could not be loaded"; then
  echo "FAIL: (h) existing empty status — denied but wrong message. Output: $out_h"
  fail=$((fail+1))
else
  echo "PASS: (h) existing empty status denied with rules-could-not-be-loaded message"
  pass=$((pass+1))
fi

# --- (i) existing state file with out-of-set value -> DENY, rules-not-loaded
root="$(new_root)"
write_state "$root" "totally-bogus-state"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: idle\n"}}
JSON
)
out_i="$(run_gate "$root" "$payload" 2>&1)"
rc_i=$?
if [ "$rc_i" -eq 0 ]; then
  echo "FAIL: (i) existing out-of-set status — expected deny, got exit 0. Output: $out_i"
  fail=$((fail+1))
elif ! printf '%s' "$out_i" | grep -q "rules could not be loaded"; then
  echo "FAIL: (i) existing out-of-set status — denied but wrong message. Output: $out_i"
  fail=$((fail+1))
else
  echo "PASS: (i) existing out-of-set status denied with rules-could-not-be-loaded message"
  pass=$((pass+1))
fi

# --- (j) existing valid state with trailing whitespace/CRLF -> treated as
#     that valid state (normal table-legal transition allowed) ------------
root="$(new_root)"
printf 'status: idle  \r\n' > "$root/verify-record.md"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: reproducing\n"}}
JSON
)
expect_allow "(j) existing status with trailing whitespace/CRLF treated as valid state" "$root" "$payload"

# --- (k) state file genuinely absent -> (none)->X bootstrap row ALLOWED --
root="$(new_root)"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/verify-record.md","content":"status: idle\n"}}
JSON
)
expect_allow "(k) genuinely absent state file, (none)->idle bootstrap row allowed" "$root" "$payload"

# --- (l) invoked from a cwd OUTSIDE the repo, CLAUDE_PROJECT_DIR unset ---
# Root resolution must be anchored to the hook's own on-disk location, never
# to the process cwd or CLAUDE_PROJECT_DIR. Run the SAME payload against the
# real on-disk gate once from inside this repo's own checkout and once from
# an unrelated outside directory, both with CLAUDE_PROJECT_DIR unset — the
# two must reach the identical decision, proving the outside-cwd invocation
# still resolved and judged this repo's own verify-record.md rather than
# some other (or no) state file.
repo_root="$(cd "$HOOK_DIR/../.." && pwd -P)"
outside_dir="$(mktemp -d)"
payload_l='{"tool_name":"Write","tool_input":{"file_path":"verify-record.md","content":"status: idle\n"}}'
out_in="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$GATE" 2>&1)"
code_in=$?
out_out="$(cd "$outside_dir" && env -u CLAUDE_PROJECT_DIR bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$GATE" 2>&1)"
code_out=$?
rm -rf "$outside_dir"
if [ "$code_in" -eq "$code_out" ]; then
  echo "PASS: (l) invocation from outside the repo resolves the same repo root as invocation from inside it (exit $code_out matches exit $code_in)"
  pass=$((pass+1))
else
  echo "FAIL: (l) invocation from outside the repo (exit $code_out) diverged from invocation from inside it (exit $code_in) — outside: $out_out | inside: $out_in"
  fail=$((fail+1))
fi

# --- (m) §11 subject-scoped own-record write -> ALLOW ---------------------
# verify writing its own docs/reports/records/<subject>/verify.md slot is
# allowed, for two distinct subject values.
root="$(new_root)"
write_contract "$root"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/reports/records/checkout-flow/verify.md","content":"status: idle\n"}}
JSON
)
expect_allow "(m1) §11 own-record write, subject=checkout-flow -> allow" "$root" "$payload"

root="$(new_root)"
write_contract "$root"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/reports/records/billing-retry/verify.md","content":"status: idle\n"}}
JSON
)
expect_allow "(m2) §11 own-record write, subject=billing-retry -> allow" "$root" "$payload"

# --- (n) §11 subject-scoped foreign-record write -> DENY, cites §11 -------
# verify writing another role's docs/reports/records/<subject>/<role>.md
# slot must be refused (exit 2) rather than silently allowed, for two
# distinct subject values, and the refusal must cite §11.
root="$(new_root)"
write_contract "$root"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/reports/records/checkout-flow/coding.md","content":"status: idle\n"}}
JSON
)
out_n1="$(run_gate "$root" "$payload" 2>&1)"
rc_n1=$?
if [ "$rc_n1" -eq 0 ]; then
  echo "FAIL: (n1) §11 foreign-record write, subject=checkout-flow — expected deny, got exit 0. Output: $out_n1"
  fail=$((fail+1))
elif ! printf '%s' "$out_n1" | grep -q "§11"; then
  echo "FAIL: (n1) §11 foreign-record write, subject=checkout-flow — denied but did not cite §11. Output: $out_n1"
  fail=$((fail+1))
else
  echo "PASS: (n1) §11 foreign-record write, subject=checkout-flow denied (exit $rc_n1), cites §11"
  pass=$((pass+1))
fi

root="$(new_root)"
write_contract "$root"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/reports/records/billing-retry/review.md","content":"status: idle\n"}}
JSON
)
out_n2="$(run_gate "$root" "$payload" 2>&1)"
rc_n2=$?
if [ "$rc_n2" -eq 0 ]; then
  echo "FAIL: (n2) §11 foreign-record write, subject=billing-retry — expected deny, got exit 0. Output: $out_n2"
  fail=$((fail+1))
elif ! printf '%s' "$out_n2" | grep -q "§11"; then
  echo "FAIL: (n2) §11 foreign-record write, subject=billing-retry — denied but did not cite §11. Output: $out_n2"
  fail=$((fail+1))
else
  echo "PASS: (n2) §11 foreign-record write, subject=billing-retry denied (exit $rc_n2), cites §11"
  pass=$((pass+1))
fi

# --- (o) write-detection bypass fix (docs/proposals/2026-07-26-fix-state-gate-writeop-bypass.md)
# Root resolution for this gate is always anchored to the hook's own git
# root (never CLAUDE_PROJECT_DIR), so these three cases operate directly
# against THIS repo's checkout with a scratch subject, cleaned up on exit.
REPO_ROOT="$(cd "$HOOK_DIR/../.." && pwd -P)"
SCRATCH_SUBJECT="gatefix-bypass-test"
SCRATCH_DIR="$REPO_ROOT/docs/reports/records/$SCRATCH_SUBJECT"
cleanup_scratch() { rm -rf "$SCRATCH_DIR"; }
trap 'cleanup_scratch; rm -rf "$WORKDIR"' EXIT
cleanup_scratch
mkdir -p "$SCRATCH_DIR"

# (o1) Bash + python3 -c "open(<foreign role's record path>,'w').write(...)"
# must be REFUSED — this is the write-through-another-tool idiom the
# idiom-whitelist previously fell through on.
payload_o1=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"open('docs/reports/records/$SCRATCH_SUBJECT/coding.md','w').write('x')\""}}
JSON
)
out_o1="$(cd "$REPO_ROOT" && printf '%s' "$payload_o1" | bash "$GATE" 2>&1)"
rc_o1=$?
if [ "$rc_o1" -ne 0 ]; then
  echo "PASS: (o1) Bash python3-open write to a foreign role's record is refused (exit $rc_o1)"
  pass=$((pass+1))
else
  echo "FAIL: (o1) Bash python3-open write to a foreign role's record was ALLOWED (exit 0): $out_o1"
  fail=$((fail+1))
fi

# (o2) a legal write to verify's OWN record slot must still be ALLOWED.
payload_o2=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/$SCRATCH_SUBJECT/verify.md","content":"status: idle\n"}}
JSON
)
out_o2="$(cd "$REPO_ROOT" && printf '%s' "$payload_o2" | bash "$GATE" 2>&1)"
rc_o2=$?
if [ "$rc_o2" -eq 0 ]; then
  echo "PASS: (o2) legal write to verify's own record slot is allowed (exit 0)"
  pass=$((pass+1))
else
  echo "FAIL: (o2) legal write to verify's own record slot was DENIED (exit $rc_o2): $out_o2"
  fail=$((fail+1))
fi

# (o3) a Bash python3-open write whose target path cannot be resolved
# statically (built via concatenation), in a command that names the owned
# record tree, must be REFUSED (default-deny on an indeterminate target).
payload_o3=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import sys; open('docs/reports/records/' + sys.argv[1] + '/coding.md','w').write('x')\" $SCRATCH_SUBJECT"}}
JSON
)
out_o3="$(cd "$REPO_ROOT" && printf '%s' "$payload_o3" | bash "$GATE" 2>&1)"
rc_o3=$?
if [ "$rc_o3" -ne 0 ]; then
  echo "PASS: (o3) Bash python3-open write with indeterminate target in the owned record tree is refused (exit $rc_o3)"
  pass=$((pass+1))
else
  echo "FAIL: (o3) Bash python3-open write with indeterminate target in the owned record tree was ALLOWED (exit 0): $out_o3"
  fail=$((fail+1))
fi

cleanup_scratch

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
