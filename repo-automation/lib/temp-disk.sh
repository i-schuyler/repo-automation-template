# repo-automation/lib/temp-disk.sh
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

run_tests_temp_disk_default_temp_root() {
  printf '%s/repo-automation-template\n' "${TMPDIR:-$HOME/.cache}"
}

run_tests_temp_disk_path_is_under_root() {
  local path="$1"
  local root="$2"

  case "$path" in
    "$root"|"$root"/*)
      return 0
      ;;
  esac

  return 1
}

run_tests_temp_disk_is_non_negative_integer() {
  case "${1:-}" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac

  return 0
}

run_tests_temp_disk_is_positive_integer() {
  run_tests_temp_disk_is_non_negative_integer "$1" || return 1
  [ "$1" -gt 0 ] 2>/dev/null
}

run_tests_temp_disk_is_non_empty() {
  [ -n "${1:-}" ]
}

run_tests_temp_disk_is_percent_integer() {
  case "${1:-}" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac

  [ "$1" -ge 1 ] 2>/dev/null && [ "$1" -le 100 ] 2>/dev/null
}

run_tests_temp_disk_timestamp() {
  date '+%Y-%m-%dT%H%M%S'
}

run_tests_log_policy_value() {
  if [ "$run_tests_log_enabled" -ne 1 ] || [ -z "$run_tests_log_file" ]; then
    printf 'no-log\n'
    return 0
  fi

  if [ "$run_tests_log_file_explicit" -eq 1 ]; then
    printf 'explicit-log-file\n'
    return 0
  fi

  if [ "$run_tests_clean_temp" -eq 1 ]; then
    printf 'run-temp-cleaned-by-default\n'
  else
    printf 'run-temp-kept-by-request\n'
  fi
}

run_tests_log_status_value() {
  if [ "$run_tests_log_enabled" -ne 1 ] || [ -z "$run_tests_log_file" ]; then
    printf 'none\n'
    return 0
  fi

  if run_tests_log_will_be_cleaned; then
    printf 'cleaned\n'
    return 0
  fi

  printf 'path\n'
}

run_tests_log_file_value() {
  if [ "$(run_tests_log_status_value)" = "path" ]; then
    printf '%s\n' "$run_tests_log_file"
  else
    printf '\n'
  fi
}

run_tests_log_fix_value() {
  if [ "$(run_tests_log_status_value)" = "cleaned" ]; then
    printf 'use --log-file=<path> or --no-clean-temp for durable logs\n'
  else
    printf '\n'
  fi
}

run_tests_log_will_be_cleaned() {
  [ "$run_tests_clean_temp" -eq 1 ] || return 1
  [ "$run_tests_log_file_explicit" -eq 0 ] || return 1
  [ -n "$run_tests_log_file" ] || return 1
  [ -n "$run_tests_temp_root" ] || return 1
  run_tests_temp_disk_path_is_under_root "$run_tests_log_file" "$run_tests_temp_root"
}

run_tests_ensure_temp_root() {
  mkdir -p "$TEST_TEMP_ROOT" >/dev/null 2>&1 || return 1
  if [ -z "$run_tests_temp_root" ]; then
    run_tests_temp_root="$TEST_TEMP_ROOT/run-tests-$(run_tests_temp_disk_timestamp)-$$"
  fi
  mkdir -p "$run_tests_temp_root" >/dev/null 2>&1
}

run_tests_prune_stale_temp_artifacts() {
  local path=""
  local stale_mtime_mins=""

  case "$run_tests_clean_stale_temp" in
    0)
      return 0
      ;;
  esac

  if ! repo_auto_is_positive_integer "$run_tests_stale_temp_hours"; then
    run_tests_stale_temp_hours=12
  fi

  stale_mtime_mins=$((run_tests_stale_temp_hours * 60))

  [ -d "$TEST_TEMP_ROOT" ] || return 0

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    [ "$path" = "$run_tests_temp_root" ] && continue
    rm -rf -- "$path" >/dev/null 2>&1 || true
  done <<EOF
$(
  find "$TEST_TEMP_ROOT" -mindepth 1 -maxdepth 1 -mmin "+$stale_mtime_mins" 2>/dev/null | LC_ALL=C sort
)
EOF
}

run_tests_cleanup_temp_root() {
  local path=""
  local preserved_child=""

  [ "$run_tests_clean_temp" -eq 1 ] || return 0
  [ -n "$run_tests_temp_root" ] || return 0
  [ -d "$run_tests_temp_root" ] || return 0

  if [ "$run_tests_log_file_explicit" -eq 1 ] && run_tests_temp_disk_path_is_under_root "$run_tests_log_file" "$run_tests_temp_root"; then
    preserved_child="${run_tests_log_file#"$run_tests_temp_root"/}"
    preserved_child="${preserved_child%%/*}"
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      [ "$path" = "$run_tests_temp_root/$preserved_child" ] && continue
      rm -rf -- "$path" >/dev/null 2>&1 || true
    done <<EOF
$(
      find "$run_tests_temp_root" -mindepth 1 -maxdepth 1 2>/dev/null | LC_ALL=C sort
)
EOF
  else
    rm -rf -- "$run_tests_temp_root" >/dev/null 2>&1 || true
  fi

  find "$TEST_TEMP_ROOT" -depth -type d -empty -exec rmdir -- {} + >/dev/null 2>&1 || true
  run_tests_prune_stale_temp_artifacts
  run_tests_cleanup_warn_if_large
}

run_tests_cleanup_warn_if_large() {
  local total_kib=""

  [ "$run_tests_clean_temp" -eq 1 ] || return 0
  [ -d "$TEST_TEMP_ROOT" ] || return 0
  command -v du >/dev/null 2>&1 || return 0

  total_kib="$(du -sk "$TEST_TEMP_ROOT" 2>/dev/null | awk 'NR == 1 { print $1 }')"
  [ -n "$total_kib" ] || return 0
  if [ "$total_kib" -gt "$run_tests_temp_root_warn_kib" ]; then
    printf 'WARN: TEST_TEMP_ROOT still uses %s KiB after cleanup: %s\n' "$total_kib" "$TEST_TEMP_ROOT" >&2
  fi
}

run_tests_disk_guard_print_top_dirs() {
  local path

  [ -d "$TEST_TEMP_ROOT" ] || return 0
  command -v du >/dev/null 2>&1 || return 0

  printf 'INFO: top temp/cache dirs under %s\n' "$TEST_TEMP_ROOT" >&2
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    du -sh "$path" 2>/dev/null || true
  done <<EOF | LC_ALL=C sort -hr | head -n 5 >&2
$(
  find "$TEST_TEMP_ROOT" -mindepth 1 -maxdepth 1 2>/dev/null | LC_ALL=C sort
)
EOF
}

run_tests_ensure_log_parent() {
  local log_parent

  if [ -z "$run_tests_log_file" ]; then
    return 1
  fi

  log_parent="$(dirname "$run_tests_log_file")"
  mkdir -p "$log_parent" >/dev/null 2>&1
}

run_tests_disk_guard_collect() {
  local path="$1"
  local used_percent=""
  local available_percent=""
  local available_blocks=""
  local filesystem=""
  local use_percent=""
  local mountpoint=""

  if ! read -r filesystem _ _ available_blocks use_percent mountpoint <<EOF
$(LC_ALL=C "$run_tests_df_bin" -Pk "$path" 2>/dev/null | sed -n '2p')
EOF
  then
    return 1
  fi

  run_tests_disk_guard_filesystem="${filesystem:-unknown}"
  run_tests_disk_guard_available_bytes=""
  run_tests_disk_guard_used_percent="${use_percent:-}"
  run_tests_disk_guard_mountpoint="${mountpoint:-$path}"

  available_blocks="${available_blocks:-}"
  used_percent="${run_tests_disk_guard_used_percent%\%}"
  if ! run_tests_temp_disk_is_non_negative_integer "$used_percent"; then
    return 1
  fi
  if ! run_tests_temp_disk_is_non_negative_integer "$available_blocks"; then
    return 1
  fi

  if [ "$used_percent" -gt 100 ]; then
    used_percent=100
  fi
  available_percent=$((100 - used_percent))
  run_tests_disk_guard_available_bytes=$((available_blocks * 1024))
  run_tests_disk_guard_used_percent="$used_percent"
  run_tests_disk_guard_available_percent="$available_percent"
  return 0
}

run_tests_disk_guard_low_bytes_label() {
  if [ "$run_tests_disk_guard_low_bytes" -eq 1610612736 ] 2>/dev/null; then
    printf '1.5G'
    return 0
  fi

  printf '%s bytes' "$run_tests_disk_guard_low_bytes"
}

run_tests_disk_guard_low_percent_label() {
  printf '%s%%' "$run_tests_disk_guard_low_percent"
}

run_tests_disk_guard_check() {
  local guard_path="$1"
  local low_bytes_label=""
  local low_percent_label=""

  run_tests_disk_guard_checked=1
  if ! run_tests_disk_guard_collect "$guard_path"; then
    return 0
  fi

  low_bytes_label="$(run_tests_disk_guard_low_bytes_label)"
  low_percent_label="$(run_tests_disk_guard_low_percent_label)"

  if [ "$run_tests_disk_guard_available_bytes" -lt "$run_tests_disk_guard_low_bytes" ]; then
    if [ "$run_tests_disk_diagnostic" -eq 1 ]; then
      run_tests_info "disk space: filesystem=${run_tests_disk_guard_filesystem:-unknown} mount=${run_tests_disk_guard_mountpoint:-$guard_path} used=${run_tests_disk_guard_used_percent}% available=${run_tests_disk_guard_available_percent}% free_bytes=${run_tests_disk_guard_available_bytes} path=$guard_path"
    fi
    run_tests_disk_guard_print_top_dirs
    run_tests_record_fail "disk space check" "available disk space below ${low_bytes_label} (${run_tests_disk_guard_available_bytes} bytes free)"
    return 1
  fi

  if [ "$run_tests_disk_guard_available_percent" -lt "$run_tests_disk_guard_low_percent" ]; then
    if [ "$run_tests_disk_diagnostic" -eq 1 ]; then
      run_tests_info "disk space: filesystem=${run_tests_disk_guard_filesystem:-unknown} mount=${run_tests_disk_guard_mountpoint:-$guard_path} used=${run_tests_disk_guard_used_percent}% available=${run_tests_disk_guard_available_percent}% free_bytes=${run_tests_disk_guard_available_bytes} path=$guard_path"
    fi
    run_tests_disk_guard_print_top_dirs
    run_tests_record_fail "disk space check" "available disk space below ${low_percent_label} (${run_tests_disk_guard_available_percent}% free)"
    return 1
  fi

  if [ "$run_tests_disk_diagnostic" -eq 1 ]; then
    run_tests_info "disk space: filesystem=${run_tests_disk_guard_filesystem:-unknown} mount=${run_tests_disk_guard_mountpoint:-$guard_path} used=${run_tests_disk_guard_used_percent}% available=${run_tests_disk_guard_available_percent}% free_bytes=${run_tests_disk_guard_available_bytes} path=$guard_path"
  fi

  return 0
}

run_tests_temp_disk_resolve_runtime_config() {
  run_tests_temp_disk_config_error=""

  if [ "${REPO_AUTOMATION_TEST_TEMP_ROOT+x}" = x ]; then
    TEST_TEMP_ROOT="$REPO_AUTOMATION_TEST_TEMP_ROOT"
  else
    TEST_TEMP_ROOT="$(run_tests_temp_disk_default_temp_root)"
  fi

  if [ "${REPO_AUTOMATION_CLEAN_STALE_TEMP+x}" = x ]; then
    run_tests_clean_stale_temp="$REPO_AUTOMATION_CLEAN_STALE_TEMP"
  else
    run_tests_clean_stale_temp=1
  fi

  if [ "${REPO_AUTOMATION_STALE_TEMP_HOURS+x}" = x ]; then
    run_tests_stale_temp_hours="$REPO_AUTOMATION_STALE_TEMP_HOURS"
  else
    run_tests_stale_temp_hours=12
  fi

  if [ "${REPO_AUTOMATION_RUN_TESTS_DISK_GUARD_PATH+x}" = x ]; then
    run_tests_disk_guard_path="$REPO_AUTOMATION_RUN_TESTS_DISK_GUARD_PATH"
  else
    run_tests_disk_guard_path="/"
  fi

  if [ "${REPO_AUTOMATION_RUN_TESTS_DISK_LOW_BYTES+x}" = x ]; then
    run_tests_disk_guard_low_bytes="$REPO_AUTOMATION_RUN_TESTS_DISK_LOW_BYTES"
  else
    run_tests_disk_guard_low_bytes=1610612736
  fi

  if [ "${REPO_AUTOMATION_RUN_TESTS_DISK_LOW_PERCENT+x}" = x ]; then
    run_tests_disk_guard_low_percent="$REPO_AUTOMATION_RUN_TESTS_DISK_LOW_PERCENT"
  else
    run_tests_disk_guard_low_percent=15
  fi

  if [ "${REPO_AUTOMATION_RUN_TESTS_TEMP_WARN_KIB+x}" = x ]; then
    run_tests_temp_root_warn_kib="$REPO_AUTOMATION_RUN_TESTS_TEMP_WARN_KIB"
  else
    run_tests_temp_root_warn_kib=1048576
  fi

  if [ "${RUN_TESTS_DF_BIN+x}" = x ]; then
    run_tests_df_bin="$RUN_TESTS_DF_BIN"
  elif [ "${REPO_AUTOMATION_DF_BIN+x}" = x ]; then
    run_tests_df_bin="$REPO_AUTOMATION_DF_BIN"
  else
    run_tests_df_bin="df"
  fi

  if ! run_tests_temp_disk_is_non_empty "$TEST_TEMP_ROOT"; then
    run_tests_temp_disk_config_error="invalid REPO_AUTOMATION_TEST_TEMP_ROOT value"
    return 1
  fi

  if ! run_tests_temp_disk_is_non_empty "$run_tests_disk_guard_path"; then
    run_tests_temp_disk_config_error="invalid REPO_AUTOMATION_RUN_TESTS_DISK_GUARD_PATH value"
    return 1
  fi

  if ! run_tests_temp_disk_is_non_empty "$run_tests_df_bin"; then
    run_tests_temp_disk_config_error="invalid REPO_AUTOMATION_DF_BIN value"
    return 1
  fi

  if ! run_tests_temp_disk_is_positive_integer "$run_tests_stale_temp_hours"; then
    run_tests_temp_disk_config_error="invalid REPO_AUTOMATION_STALE_TEMP_HOURS value"
    return 1
  fi

  if ! run_tests_temp_disk_is_positive_integer "$run_tests_disk_guard_low_bytes"; then
    run_tests_temp_disk_config_error="invalid REPO_AUTOMATION_RUN_TESTS_DISK_LOW_BYTES value"
    return 1
  fi

  if ! run_tests_temp_disk_is_percent_integer "$run_tests_disk_guard_low_percent"; then
    run_tests_temp_disk_config_error="invalid REPO_AUTOMATION_RUN_TESTS_DISK_LOW_PERCENT value"
    return 1
  fi

  if ! run_tests_temp_disk_is_positive_integer "$run_tests_temp_root_warn_kib"; then
    run_tests_temp_disk_config_error="invalid REPO_AUTOMATION_RUN_TESTS_TEMP_WARN_KIB value"
    return 1
  fi

  return 0
}
