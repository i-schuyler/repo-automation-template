#!/usr/bin/env bash
# repo-automation/tests/lib/smoke-capture.sh

# shellcheck shell=bash

smoke_capture_file=""
smoke_capture_stdout_fd=""
smoke_capture_stderr_fd=""

smoke_capture_begin() {
  local capture_prefix="${1:-smoke}"

  mkdir -p "$TEST_TEMP_ROOT" || return 1
  smoke_capture_file="$(mktemp "$TEST_TEMP_ROOT/${capture_prefix}.XXXXXX")" || return 1
  exec {smoke_capture_stdout_fd}>&1 {smoke_capture_stderr_fd}>&2
  exec >"$smoke_capture_file" 2>&1
}

smoke_capture_restore() {
  if [ -n "$smoke_capture_stdout_fd" ] && [ -n "$smoke_capture_stderr_fd" ]; then
    exec 1>&"$smoke_capture_stdout_fd" 2>&"$smoke_capture_stderr_fd"
    exec {smoke_capture_stdout_fd}>&- {smoke_capture_stderr_fd}>&-
    smoke_capture_stdout_fd=""
    smoke_capture_stderr_fd=""
  fi
}

smoke_capture_cleanup() {
  local capture_file="$smoke_capture_file"

  smoke_capture_restore || return 1
  if [ -n "$capture_file" ]; then
    rm -f -- "$capture_file" >/dev/null 2>&1 || true
  fi
  smoke_capture_file=""
}

# repo-automation/tests/lib/smoke-capture.sh EOF
