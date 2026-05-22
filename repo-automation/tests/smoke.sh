#!/usr/bin/env bash
# repo-automation/tests/smoke.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/lib/smoke-common.sh"

smoke_main() {
  local status=0
  local smoke_output_capture=""

  # shellcheck disable=SC2034 # Used by shared test_finish_output/test_render_json.
  TEST_OUTPUT_SCRIPT="smoke"
  smoke_help_requested=0
  smoke_parse_output_mode "$@" || return 1
  if [ "$smoke_help_requested" -eq 1 ]; then
    return 0
  fi
  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    smoke_run "$@" || status=1
  else
    mkdir -p "$TEST_TEMP_ROOT" || return 1
    smoke_output_capture="$(mktemp "$TEST_TEMP_ROOT/smoke.XXXXXX")" || return 1
    if smoke_run "$@" >"$smoke_output_capture" 2>&1; then
      :
    else
      status=$?
    fi
    rm -f -- "$smoke_output_capture" >/dev/null 2>&1 || true
  fi
  smoke_finish_output "$status"
  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    test_print_final_summary \
      "script=smoke" \
      "mode=explain" \
      "rc=$status" \
      "url_or_stop=$([ "$status" -eq 0 ] && printf 'pass' || printf 'fail')" >&2
  fi
  return "$status"
}

smoke_main "$@"
# repo-automation/tests/smoke.sh EOF
