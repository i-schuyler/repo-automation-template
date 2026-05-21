#!/usr/bin/env bash
# repo-automation/tests/contracts/review-pack.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/artifacts.sh"

smoke_review_pack_print_final_summary() {
  local status="$1"
  local status_count="$2"
  local url_or_stop="$3"

  printf '===== FINAL SUMMARY =====\n' >&2
  printf 'script=review-pack-contract\n' >&2
  printf 'rc=%s\n' "$status" >&2
  printf 'mode=explain\n' >&2
  printf 'status_count=%s\n' "$status_count" >&2
  printf 'url_or_stop=%s\n' "$url_or_stop" >&2
  printf '===== END =====\n' >&2
}

smoke_main() {
  local status=0
  local smoke_output_capture=""
  local status_count=0
  local final_failure=""

  # shellcheck disable=SC2034 # Used by shared test_finish_output/test_render_json.
  TEST_OUTPUT_SCRIPT="review-pack"
  smoke_help_requested=0
  smoke_parse_output_mode "$@" || return 1
  if [ "$smoke_help_requested" -eq 1 ]; then
    return 0
  fi
  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    trap 'test_cleanup' EXIT INT TERM

    smoke_setup_temp_repo || return 1

    smoke_run_named_check "smoke:review-pack-contract" smoke_check_review_pack_contract || status=1
    status_count="${#TEST_EVENT_KIND[@]}"
    if [ "$status" -ne 0 ]; then
      final_failure="$(printf '%s\n' "${TEST_EVENT_MESSAGE[@]}" | awk 'NF { print; exit }')"
      smoke_review_pack_print_final_summary "$status" "$status_count" "STOP ${final_failure:-review-pack contract failed}"
    else
      smoke_review_pack_print_final_summary "$status" "$status_count" "pass"
    fi
    return "$status"
  else
    mkdir -p "$TEST_TEMP_ROOT" || return 1
    smoke_output_capture="$(mktemp "$TEST_TEMP_ROOT/review-pack.XXXXXX")" || return 1
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
