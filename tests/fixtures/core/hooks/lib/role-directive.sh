#!/usr/bin/env bash
# TEST FIXTURE — pinned copy of tokenmaxxxer-core's
# core/hooks/lib/role-directive.sh (issue-66, main@22a7cad); see
# gate-lib.sh's fixture header in this same directory for why this exists.
# Not in tests/stub-check.sh's CANON_GATES list (role-directive.sh is not
# a stub-check target — directive.sh, the file that sources it, is checked
# structurally instead).
#
# Sourceable library: the boilerplate every rulebook's own SessionStart
# `directive.sh` repeated byte-for-byte except for role-token substitution
# (issue-66 survey: preamble, kill-switch case, CLAUDE_ROLE guard, opening
# and closing lines were identical in shape across all 43 copies). A
# rulebook's directive.sh now sources this file and calls
# core_role_directive with its four genuinely role-unique values; every
# unique bit of shell logic below lives in exactly one place.
#
# Usage, from a rulebook's own hooks/directive.sh:
#
#   #!/usr/bin/env bash
#   . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
#   core_role_directive \
#     "YOU DECIDE: ..." \
#     "USE WHEN: ..." \
#     "PRODUCES: ..." \
#     "HAND-OFF: ..."
#
# core_role_directive <you_decide> <use_when> <produces> <hand_off>
#
# Reads CLAUDE_ROLE from the environment (no role -> silent no-op, same as
# core's own directive.sh). Kill switch, per role, via
# <ROLE>_CYCLE_OFF=1 (role name uppercased with `tr`, not bash 4's
# `${var^^}`, to stay inside parse-check.sh's bash-3.2 compatibility
# floor).
core_role_directive() {
  local you_decide="$1" use_when="$2" produces="$3" hand_off="$4"
  local role="${CLAUDE_ROLE:-}"
  [ -n "$role" ] || return 0

  local role_upper
  role_upper="$(printf '%s' "$role" | tr '[:lower:]-' '[:upper:]_')"
  local off_var="${role_upper}_CYCLE_OFF"
  eval "local off_val=\"\${${off_var}:-}\""
  case "$off_val" in ""|0|false|no|off) ;; *) return 0 ;; esac

  cat <<EOF
[${role}] Role directive (on top of core's protocol):

${you_decide}
${use_when}
${produces}
${hand_off}

RECORD: docs/issue-<n>/reports/${role}.md, phase-gated per contract v3 s19
EOF
}
