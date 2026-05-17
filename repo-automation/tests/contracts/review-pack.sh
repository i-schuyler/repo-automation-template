#!/usr/bin/env bash
# repo-automation/tests/contracts/review-pack.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/artifacts.sh"

smoke_main() {
  local status=0
  local smoke_output_capture=""

  TEST_OUTPUT_SCRIPT="review-pack"
  smoke_parse_output_mode "$@" || return 1
  if [ "$smoke_help_requested" -eq 1 ]; then
    return 0
  fi
  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    trap 'test_cleanup' EXIT INT TERM

    smoke_setup_temp_repo || return 1

    smoke_run_named_check "smoke:review-pack-contract" smoke_check_review_pack_contract || status=1
  else
    smoke_output_capture="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-automation-template-tests/review-pack.XXXXXX")" || return 1
    exec 3>&1 4>&2
    exec >"$smoke_output_capture" 2>&1
    trap 'test_cleanup' EXIT INT TERM

    smoke_setup_temp_repo || status=1
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:review-pack-contract" smoke_check_review_pack_contract || status=1
    fi

    exec 1>&3 2>&4
    rm -f -- "$smoke_output_capture" >/dev/null 2>&1 || true
  fi

  smoke_finish_output "$status"
  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/review-pack.sh EOF
