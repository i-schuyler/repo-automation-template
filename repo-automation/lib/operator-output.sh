#!/usr/bin/env bash
# repo-automation/lib/operator-output.sh

repo_operator_output_emit_file_block() {
  local block_label="$1"
  local source_path="$2"
  local require_file="${3:-0}"
  local last_byte=""

  if [ -z "$source_path" ] || [ ! -f "$source_path" ] || [ ! -r "$source_path" ] || [ ! -s "$source_path" ]; then
    [ "$require_file" -eq 0 ] && return 0
    return 1
  fi

  printf '===== %s =====\n' "$block_label"
  cat "$source_path" || return 1
  last_byte="$(tail -c 1 "$source_path" 2>/dev/null | od -An -t x1 | tr -d '[:space:]')"
  if [ "$last_byte" != "0a" ]; then
    printf '\n'
  fi
  printf '===== END %s =====\n' "$block_label"
}

repo_operator_output_write_file_block() {
  local block_label="$1"
  local source_path="$2"
  local block_path="$3"
  local tmp_path=""

  tmp_path="$(mktemp "$(dirname "$block_path")/.${block_path##*/}.XXXXXX")" || return 1
  if repo_operator_output_emit_file_block "$block_label" "$source_path" 1 > "$tmp_path" && mv -f -- "$tmp_path" "$block_path"; then
    return 0
  fi
  rm -f -- "$tmp_path" >/dev/null 2>&1 || true
  return 1
}

# repo-automation/lib/operator-output.sh EOF
