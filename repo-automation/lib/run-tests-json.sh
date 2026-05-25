#!/usr/bin/env bash
# repo-automation/lib/run-tests-json.sh

# shellcheck shell=bash
# shellcheck disable=SC2154

run_tests_json_escape() {
  local input="$1"
  input=${input//\\/\\\\}
  input=${input//\"/\\\"}
  input=${input//$'\n'/\\n}
  input=${input//$'\r'/\\r}
  input=${input//$'\t'/\\t}
  printf '%s' "$input"
}

run_tests_print_json() {
  local overall_status="$1"
  local pass_count="$2"
  local warn_count="$3"
  local fail_count="$4"
  local skipped_count="$5"
  local entry name status message timed_out rest json_checks=""
  local selected_json=""
  local first=1
  local first_selected=1
  local want_level="$run_tests_json_level"
  local timed_out_json
  local log_status=""
  local log_file=""
  local log_fix=""

  log_status="$(run_tests_log_status_value)"
  log_file="$(run_tests_log_file_value)"
  log_fix="$(run_tests_log_fix_value)"

  for entry in "${run_tests_checks[@]}"; do
    name="${entry%%|*}"
    rest="${entry#*|}"
    status="${rest%%|*}"
    rest="${rest#*|}"
    timed_out="${rest%%|*}"
    message="${rest#*|}"

    case "$want_level" in
      fail)
        [ "$status" = "fail" ] || continue
        ;;
      warn)
        [ "$status" = "fail" ] || [ "$status" = "warn" ] || continue
        ;;
      all)
        ;;
    esac

    if [ "$first" -eq 0 ]; then
      json_checks+=', '
    fi
    if [ "$timed_out" = "1" ]; then
      timed_out_json=true
    else
      timed_out_json=false
    fi
    json_checks+="{\"name\":\"$(run_tests_json_escape "$name")\","
    json_checks+="\"status\":\"$(run_tests_json_escape "$status")\","
    json_checks+="\"message\":\"$(run_tests_json_escape "$message")\","
    json_checks+="\"timed_out\":${timed_out_json}}"
    first=0
  done

  if [ "$run_tests_run_mode" = "changed" ]; then
    for entry in "${run_tests_changed_selected_subsets[@]}"; do
      if [ "$first_selected" -eq 0 ]; then
        selected_json+=', '
      fi
      selected_json+="\"$(run_tests_json_escape "$entry")\""
      first_selected=0
    done
  fi

  printf '{'
  printf '"script":"run-tests",'
  printf '"mode":"%s",' "$(run_tests_json_escape "$run_tests_mode")"
  printf '"overall_status":"%s",' "$(run_tests_json_escape "$overall_status")"
  printf '"pass_count":%s,' "$pass_count"
  printf '"warn_count":%s,' "$warn_count"
  printf '"fail_count":%s,' "$fail_count"
  printf '"skipped_count":%s,' "$skipped_count"
  printf '"json_level":"%s",' "$(run_tests_json_escape "$run_tests_json_level")"
  printf '"checks":[%s],' "$json_checks"
  if [ "$run_tests_run_mode" = "changed" ]; then
    printf '"selected_subsets":[%s],' "$selected_json"
  fi
  printf '"log_status":"%s",' "$(run_tests_json_escape "$log_status")"
  printf '"log_policy":"%s",' "$(run_tests_json_escape "$(run_tests_log_policy_value)")"
  printf '"log_file":"%s"' "$(run_tests_json_escape "$log_file")"
  if [ -n "$log_fix" ]; then
    printf ',"log_fix":"%s"' "$(run_tests_json_escape "$log_fix")"
  fi
  printf '}\n'
}

# repo-automation/lib/run-tests-json.sh EOF
