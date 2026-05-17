#!/usr/bin/env bash
# repo-automation/tests/smoke.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/lib/smoke-common.sh"

smoke_main() {
  local status=0
  local smoke_output_capture=""

  TEST_OUTPUT_SCRIPT="smoke"
  smoke_parse_output_mode "$@" || return 1
  if [ "$smoke_help_requested" -eq 1 ]; then
    return 0
  fi
  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    smoke_run "$@" || status=1
  else
    smoke_output_capture="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-automation-template-tests/smoke.XXXXXX")" || return 1
    if smoke_run "$@" >"$smoke_output_capture" 2>&1; then
      :
    else
      status=$?
    fi
    rm -f -- "$smoke_output_capture" >/dev/null 2>&1 || true
  fi
  smoke_finish_output "$status"
  return "$status"
}

smoke_main "$@"
# repo-automation/tests/smoke.sh EOF
