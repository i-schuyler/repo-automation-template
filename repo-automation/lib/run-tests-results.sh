#!/usr/bin/env bash
# repo-automation/lib/run-tests-results.sh

# shellcheck shell=bash
# shellcheck disable=SC2154

run_tests_add_check() {
  local name="$1"
  local status="$2"
  local message="$3"
  local timed_out="${4:-0}"

  run_tests_checks+=("${name}|${status}|${timed_out}|${message}")
  run_tests_log "${status^^}: ${name} - ${message}"
}

run_tests_record_pass() {
  run_tests_add_check "$1" "pass" "$2" "0"
}

run_tests_record_warn() {
  run_tests_add_check "$1" "warn" "$2" "0"
}

run_tests_record_fail() {
  run_tests_add_check "$1" "fail" "$2" "${3:-0}"
}

run_tests_record_skip() {
  run_tests_add_check "$1" "skipped" "$2" "0"
}

run_tests_counts() {
  local pass_count=0
  local warn_count=0
  local fail_count=0
  local skipped_count=0
  local entry status

  for entry in "${run_tests_checks[@]}"; do
    status="${entry#*|}"
    status="${status%%|*}"
    case "$status" in
      pass) pass_count=$((pass_count + 1)) ;;
      warn) warn_count=$((warn_count + 1)) ;;
      fail) fail_count=$((fail_count + 1)) ;;
      skipped) skipped_count=$((skipped_count + 1)) ;;
    esac
  done

  printf '%s %s %s %s\n' "$pass_count" "$warn_count" "$fail_count" "$skipped_count"
}

run_tests_first_entry_by_status() {
  local want_status="$1"
  local entry name status rest timed_out message

  for entry in "${run_tests_checks[@]}"; do
    name="${entry%%|*}"
    rest="${entry#*|}"
    status="${rest%%|*}"
    rest="${rest#*|}"
    timed_out="${rest%%|*}"
    message="${rest#*|}"
    if [ "$status" = "$want_status" ]; then
      printf '%s|%s|%s|%s\n' "$name" "$status" "$timed_out" "$message"
      return 0
    fi
  done

  return 1
}

# repo-automation/lib/run-tests-results.sh EOF
