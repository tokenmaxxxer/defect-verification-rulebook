#!/usr/bin/env bash
# Tests for verify-cycle's procedure gates (§20 record-fields, §11 path-
# ownership, §21 doc-bucket, §16 closed-checks, §21 handbook-trigger, §13
# trailer). Each gate: one crafted VIOLATION that must be REFUSED and one
# compliant case that must PASS.
set -uo pipefail
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0

run() { # $1 gate  $2 root  $3 payload
  CLAUDE_PROJECT_DIR="$2" bash "$HOOK_DIR/$1" <<<"$3" 2>&1
}
expect_deny() { local n="$1" g="$2" r="$3" p="$4" out rc
  out="$(run "$g" "$r" "$p")"; rc=$?
  if [ "$rc" -ne 0 ]; then echo "PASS(refuse): $n (exit $rc)"; pass=$((pass+1))
  else echo "FAIL(refuse): $n — expected deny, got exit 0. Out: $out"; fail=$((fail+1)); fi
}
expect_allow() { local n="$1" g="$2" r="$3" p="$4" out rc
  out="$(run "$g" "$r" "$p")"; rc=$?
  if [ "$rc" -eq 0 ]; then echo "PASS(allow): $n"; pass=$((pass+1))
  else echo "FAIL(allow): $n — expected allow, got exit $rc. Out: $out"; fail=$((fail+1)); fi
}
new_repo() { local d; d="$(mktemp -d -p "$WORK")"; git init -q "$d"
  mkdir -p "$d/docs/specs"; printf '# contract\n' > "$d/docs/specs/role-handoff-contract.md"
  ( cd "$d" && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
  echo "$d"; }

# ---- §20 record-fields-gate ----
R="$(new_repo)"; mkdir -p "$R/docs/reports/records/checkout"
bad='{"tool_name":"Write","tool_input":{"file_path":"__R__/docs/reports/records/checkout/verify.md","content":"loop_state: reproducing\nwhat was done: reproduced the bug\nwhy: chose A over B\nupstream: records/checkout/coding.md\n"}}'
expect_deny "§20 non-terminal record missing next-steps/resolution-path" record-fields-gate.sh "$R" "${bad//__R__/$R}"
good='{"tool_name":"Write","tool_input":{"file_path":"__R__/docs/reports/records/checkout/verify.md","content":"loop_state: reproducing\n## what was done\nreproduced the bug\n## why\nchose approach A over B because B was slower\nupstream: records/checkout/coding.md\n## next-steps\nre-run against fix\n## open-finding resolution path\nowner: coding resolves finding 1\n"}}'
expect_allow "§20 non-terminal record with all sections" record-fields-gate.sh "$R" "${good//__R__/$R}"

# ---- §11 path-ownership-gate ----
R="$(new_repo)"; mkdir -p "$R/docs/reports/records/checkout"
expect_deny "§11 write to another role's coding.md" path-ownership-gate.sh "$R" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R/docs/reports/records/checkout/coding.md\",\"content\":\"x\"}}"
expect_allow "§11 write to verify's own verify.md" path-ownership-gate.sh "$R" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R/docs/reports/records/checkout/verify.md\",\"content\":\"loop_state: idle\"}}"

# ---- §21 doc-bucket-gate ----
R="$(new_repo)"
expect_deny "§21 write under docs/ outside buckets" doc-bucket-gate.sh "$R" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R/docs/random-notes.md\",\"content\":\"x\"}}"
expect_allow "§21 write into reports/ bucket" doc-bucket-gate.sh "$R" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R/docs/reports/2026-07-26-run.md\",\"content\":\"x\"}}"

# ---- §16 closed-checks-gate ----
R="$(new_repo)"; HEAD="$(git -C "$R" rev-parse HEAD)"; mkdir -p "$R/docs/reports/records/checkout"
expect_deny "§16 closed_checks cites stale code_sha" closed-checks-gate.sh "$R" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R/docs/reports/records/checkout/verify.md\",\"content\":\"loop_state: reproduced\nclosed_checks:\n  - check: lens-1\n    code_sha: deadbeef1234567\n\"}}"
expect_allow "§16 closed_checks cites current HEAD" closed-checks-gate.sh "$R" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R/docs/reports/records/checkout/verify.md\",\"content\":\"loop_state: reproduced\nclosed_checks:\n  - check: lens-1\n    code_sha: $HEAD\n\"}}"

# ---- §21 handbook-trigger-gate (commit-time) ----
R="$(new_repo)"; printf '{}\n' > "$R/package.json"; ( cd "$R" && git add package.json )
expect_deny "§21 op-surface change without handbook" handbook-trigger-gate.sh "$R" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'change dep'\"}}"
mkdir -p "$R/docs/handbooks"; printf '# svc\n' > "$R/docs/handbooks/root.md"; ( cd "$R" && git add docs/handbooks/root.md )
expect_allow "§21 op-surface change with handbook update" handbook-trigger-gate.sh "$R" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'change dep'\"}}"

# ---- §13 trailer-gate (commit-time) ----
R="$(new_repo)"; printf 'status: reproducing\n' > "$R/verify-record.md"
expect_deny "§13 in-progress commit lacking Subject: trailer" trailer-gate.sh "$R" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'land verify work'\"}}"
expect_allow "§13 in-progress commit with Subject: trailer" trailer-gate.sh "$R" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'land verify work' -m 'Subject: checkout'\"}}"

echo; echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
