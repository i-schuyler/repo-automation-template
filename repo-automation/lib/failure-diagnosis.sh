#!/usr/bin/env bash
# repo-automation/lib/failure-diagnosis.sh

repo_failure_diagnosis_write_card_file() {
  local card_path="$1"
  shift
  local card_dir=""
  local tmp_path=""
  local field_name=""
  local field_value=""

  [ -n "$card_path" ] || return 1
  card_dir="$(dirname "$card_path")"
  mkdir -p "$card_dir" || return 1
  tmp_path="$(mktemp "${TMPDIR:-$HOME/.cache}/.${card_path##*/}.XXXXXX")" || return 1

  {
    while [ "$#" -gt 0 ]; do
      field_name="$1"
      shift
      if [ "$#" -eq 0 ]; then
        printf 'fail: missing value for failure card field: %s\n' "$field_name" >&2
        return 1
      fi
      field_value="$1"
      shift
      printf '%s=%s\n' "$field_name" "$field_value"
    done
  } >"$tmp_path" || {
    rm -f -- "$tmp_path" >/dev/null 2>&1 || true
    return 1
  }

  mv -f -- "$tmp_path" "$card_path"
}

repo_failure_diagnosis_print_detail_lines() {
  local field_name=""
  local field_value=""

  while [ "$#" -gt 0 ]; do
    field_name="$1"
    shift
    if [ "$#" -eq 0 ]; then
      printf 'fail: missing value for failure detail field: %s\n' "$field_name" >&2
      return 1
    fi
    field_value="$1"
    shift
    printf '  %s: %s\n' "$field_name" "$field_value"
  done
}

# repo-automation/lib/failure-diagnosis.sh EOF
