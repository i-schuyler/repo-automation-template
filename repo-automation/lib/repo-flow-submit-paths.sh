#!/usr/bin/env bash
# repo-automation/lib/repo-flow-submit-paths.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

repo_flow_submit_stop() {
  repo_flow_stop "$*"
}

repo_flow_submit_validate_path() {
  local path="$1"

  case "$path" in
    "")
      repo_flow_submit_stop "empty path"
      return 1
      ;;
    /*)
      repo_flow_submit_stop "absolute paths are not allowed: $path"
      return 1
      ;;
    *..*)
      repo_flow_submit_stop "path contains ..: $path"
      return 1
      ;;
  esac

  return 0
}

repo_flow_submit_stage_paths() {
  local paths_csv="$1"
  local allow_pre_staged="${2:-0}"
  local path=""
  local tracked_path=0
  local -a submit_paths=()

  if [ "$allow_pre_staged" -eq 0 ] && ! git diff --cached --quiet --exit-code -- >/dev/null 2>&1; then
    repo_flow_submit_stop "pre-staged changes are not allowed with --paths"
    return 1
  fi

  IFS=, read -r -a submit_paths <<< "$paths_csv"

  for path in "${submit_paths[@]}"; do
    repo_flow_submit_validate_path "$path" || return 1
    tracked_path=0
    if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      tracked_path=1
    fi
    if [ "$tracked_path" -eq 0 ] && [ ! -e "$path" ] && [ ! -L "$path" ]; then
      repo_flow_submit_stop "missing untracked path: $path"
      return 1
    fi
  done

  for path in "${submit_paths[@]}"; do
    if ! git add -- "$path"; then
      repo_flow_submit_stop "git add failed for path: $path"
      return 1
    fi
  done

  return 0
}

repo_flow_submit_stage_all() {
  if ! git -C "${repo_root:-.}" add -A -- .; then
    repo_flow_submit_stop "git add failed for all working tree changes"
    return 1
  fi

  return 0
}

repo_flow_submit_collect_modified_paths() {
  local status=""
  local path=""
  local -a modified_paths=()
  local -A seen_paths=()

  status="$(git diff --name-only --diff-filter=MRD --cached; git diff --name-only --diff-filter=MRD)"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    repo_flow_submit_validate_path "$path" || return 1
    if [ -z "${seen_paths[$path]:-}" ]; then
      modified_paths+=("$path")
      seen_paths["$path"]=1
    fi
  done <<EOF
$status
EOF

  if [ "${#modified_paths[@]}" -eq 0 ]; then
    repo_flow_submit_stop "no modified tracked paths found"
    return 1
  fi

  printf '%s\n' "${modified_paths[@]}"
}

repo_flow_submit_has_new_files() {
  local status_line=""

  while IFS= read -r status_line; do
    [ -n "$status_line" ] || continue
    case "$status_line" in
      A*|' A'*|'?? '*)
        return 0
        ;;
    esac
  done <<EOF
$(git status --porcelain --untracked-files=all)
EOF

  return 1
}

repo_flow_submit_path_is_requested() {
  local requested_path="$1"
  local status_path="$2"

  case "$status_path" in
    "$requested_path"|"$requested_path"/*)
      return 0
      ;;
  esac

  return 1
}

repo_flow_submit_format_unrequested_paths() {
  local max_paths="$1"
  shift
  local -a paths=("$@")
  local shown_count=0
  local remaining_count=0
  local output=""
  local path=""

  if [ "${#paths[@]}" -eq 0 ]; then
    return 1
  fi

  shown_count="${#paths[@]}"
  if [ "$shown_count" -gt "$max_paths" ]; then
    shown_count="$max_paths"
    remaining_count=$(( ${#paths[@]} - max_paths ))
  fi

  for path in "${paths[@]:0:shown_count}"; do
    if [ -n "$output" ]; then
      output="$output,"
    fi
    output="$output$path"
  done

  if [ "$remaining_count" -gt 0 ]; then
    output="$output (+$remaining_count more)"
  fi

  printf '%s\n' "$output"
}

repo_flow_submit_check_unrequested_changes() {
  local paths_csv="$1"
  local status_line=""
  local status_path=""
  local requested_path=""
  local -a submit_paths=()
  local -a unrequested_paths=()

  IFS=, read -r -a submit_paths <<< "$paths_csv"

  while IFS= read -r status_line; do
    [ -n "$status_line" ] || continue
    case "$status_line" in
      '?? '*)
        status_path="${status_line#?? }"
        ;;
      *)
        status_path="${status_line#?? }"
        status_path="${status_path##* -> }"
        ;;
    esac

    for requested_path in "${submit_paths[@]}"; do
      if repo_flow_submit_path_is_requested "$requested_path" "$status_path"; then
        continue 2
      fi
    done

    unrequested_paths+=("$status_path")
  done <<EOF
$(git status --porcelain --untracked-files=all)
EOF

  if [ "${#unrequested_paths[@]}" -gt 0 ]; then
    printf 'unrequested_paths=%s\n' "$(repo_flow_submit_format_unrequested_paths 3 "${unrequested_paths[@]}")" >&2
    repo_flow_submit_stop "unrequested working tree changes remain; commit a clean explicit submit"
    return 1
  fi

  return 0
}

# repo-automation/lib/repo-flow-submit-paths.sh EOF
