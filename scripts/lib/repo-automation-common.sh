# scripts/lib/repo-automation-common.sh

repo_auto_info() {
  printf 'INFO: %s\n' "$*"
}

repo_auto_warn() {
  printf 'WARN: %s\n' "$*" >&2
}

repo_auto_stop() {
  printf 'STOP: %s\n' "$*" >&2
  return 1
}

repo_auto_require_command() {
  local command_name="${1:-}"

  if [ -z "$command_name" ]; then
    repo_auto_stop "missing required command name"
    return 1
  fi

  if ! command -v "$command_name" >/dev/null 2>&1; then
    repo_auto_stop "required command not found on PATH: $command_name"
    return 1
  fi
}

repo_auto_repo_root() {
  if ! command -v git >/dev/null 2>&1; then
    repo_auto_stop "git is required"
    return 1
  fi

  git rev-parse --show-toplevel 2>/dev/null || {
    repo_auto_stop "not inside a git repository"
    return 1
  }
}

repo_auto_config_path() {
  local repo_root

  repo_root=$(repo_auto_repo_root) || return 1
  printf '%s/.repo-automation.conf\n' "$repo_root"
}

repo_auto_secret_scan_file() {
  local path="${1:-}"
  local secret_pattern='-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|(^|[^[:alnum:]_])(token|api_key|password|passwd|secret)[[:space:]]*[:=]|authorization[[:space:]]+bearer'

  if [ -z "$path" ]; then
    repo_auto_stop "missing file path for secret scan"
    return 1
  fi

  if [ ! -f "$path" ]; then
    repo_auto_stop "missing file for secret scan: $path"
    return 1
  fi

  if grep -Eiq -- "$secret_pattern" "$path"; then
    repo_auto_warn "possible secret markers found in $path"
    return 1
  fi
}

repo_auto_load_config() {
  local config_path

  config_path=$(repo_auto_config_path) || return 1

  if [ ! -f "$config_path" ]; then
    repo_auto_stop "missing config file: $config_path"
    return 1
  fi

  repo_auto_secret_scan_file "$config_path" || return 1

  # shellcheck source=/dev/null
  . "$config_path" || {
    repo_auto_stop "failed to source config file: $config_path"
    return 1
  }
}

repo_auto_state_dir() {
  local state_name="${STATE_DIR_NAME:-repo-automation-template}"
  local state_root="${TMPDIR:-$HOME/.cache}"

  printf '%s/%s\n' "$state_root" "$state_name"
}

repo_auto_is_positive_integer() {
  local value="${1:-}"

  case "$value" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac

  [ "$value" -gt 0 ] 2>/dev/null
}

repo_auto_validate_branch_name() {
  local branch_name="${1:-}"

  case "$branch_name" in
    ''|-*|*[[:space:]]*|*..*|*@{*|*~*|*\^*|*:*|*\?*|*\**|*[[]*|*\\*|/*|*//*|*/|.|..|*.lock)
      return 1
      ;;
  esac

  return 0
}

repo_auto_validate_provider() {
  case "${1:-}" in
    github|gitlab|none)
      return 0
      ;;
  esac

  return 1
}

repo_auto_validate_merge_mode() {
  case "${1:-}" in
    squash|merge|rebase)
      return 0
      ;;
  esac

  return 1
}

repo_auto_validate_required_config() {
  local missing=()
  local var_name
  local value
  local decl

  for var_name in \
    REPO_AUTOMATION_CONF_VERSION \
    REPO_AUTOMATION_VERSION \
    UPSTREAM_REPO_FULL_NAME \
    UPSTREAM_ISSUE_URL \
    INSTALLED_FROM \
    INSTALLED_VERSION_OR_REF \
    INSTALLED_AT \
    LOCAL_OVERRIDES_DOC \
    DEFAULT_BRANCH \
    DOCS_DIR \
    DOCS_INDEX \
    STATE_DIR_NAME \
    CI_PROVIDER \
    PR_PROVIDER \
    MERGE_MODE \
    DOC_PR_TIMEOUT_SECONDS \
    DOC_PR_POLL_SECONDS \
    IMPLEMENTATION_PR_TIMEOUT_SECONDS \
    IMPLEMENTATION_PR_POLL_SECONDS \
    DOC_BRANCH_PREFIX \
    FEATURE_BRANCH_PREFIX \
    FIX_BRANCH_PREFIX \
    CHECK_PROFILE_DEFAULT
  do
    if [ -z "${!var_name+x}" ] || [ -z "${!var_name}" ]; then
      missing+=("$var_name")
    fi
  done

  if [ "${#missing[@]}" -ne 0 ]; then
    repo_auto_stop "missing required config variables: ${missing[*]}"
    return 1
  fi

  value="$REPO_AUTOMATION_CONF_VERSION"
  [[ "$value" =~ ^[0-9]+([.][0-9]+)*$ ]] || {
    repo_auto_stop "invalid REPO_AUTOMATION_CONF_VERSION"
    return 1
  }

  value="$REPO_AUTOMATION_VERSION"
  [[ "$value" =~ ^[0-9]+([.][0-9]+)*([.-][A-Za-z0-9][A-Za-z0-9._-]*)?$ ]] || {
    repo_auto_stop "invalid REPO_AUTOMATION_VERSION"
    return 1
  }

  for value in "$UPSTREAM_REPO_FULL_NAME" "$INSTALLED_FROM"; do
    [[ "$value" =~ ^[^[:space:]/]+/[^[:space:]/]+$ ]] || {
      repo_auto_stop "invalid repo full name in config"
      return 1
    }
  done

  [[ "$UPSTREAM_ISSUE_URL" =~ ^https?:// ]] || {
    repo_auto_stop "invalid UPSTREAM_ISSUE_URL"
    return 1
  }

  [[ "$INSTALLED_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || {
    repo_auto_stop "invalid INSTALLED_AT"
    return 1
  }

  for value in "$LOCAL_OVERRIDES_DOC" "$DOCS_DIR" "$DOCS_INDEX"; do
    case "$value" in
      ''|/*|*[[:space:]]*|*..*)
        repo_auto_stop "invalid relative path in config"
        return 1
        ;;
    esac
  done

  for value in "$DEFAULT_BRANCH" "$STATE_DIR_NAME" "$DOC_BRANCH_PREFIX" "$FEATURE_BRANCH_PREFIX" "$FIX_BRANCH_PREFIX" "$CHECK_PROFILE_DEFAULT"; do
    repo_auto_validate_branch_name "$value" || {
      repo_auto_stop "invalid branch-safe config value"
      return 1
    }
  done

  repo_auto_validate_provider "$CI_PROVIDER" || {
    repo_auto_stop "invalid CI_PROVIDER"
    return 1
  }

  repo_auto_validate_provider "$PR_PROVIDER" || {
    repo_auto_stop "invalid PR_PROVIDER"
    return 1
  }

  repo_auto_validate_merge_mode "$MERGE_MODE" || {
    repo_auto_stop "invalid MERGE_MODE"
    return 1
  }

  for value in "$DOC_PR_TIMEOUT_SECONDS" "$DOC_PR_POLL_SECONDS" "$IMPLEMENTATION_PR_TIMEOUT_SECONDS" "$IMPLEMENTATION_PR_POLL_SECONDS"; do
    repo_auto_is_positive_integer "$value" || {
      repo_auto_stop "invalid timeout value in config"
      return 1
    }
  done

  decl=$(declare -p CHECK_PROFILE_DOCS_COMMANDS 2>/dev/null) || {
    repo_auto_stop "CHECK_PROFILE_DOCS_COMMANDS must be declared as an array"
    return 1
  }

  case "$decl" in
    declare\ -a*)
      ;;
    *)
      repo_auto_stop "CHECK_PROFILE_DOCS_COMMANDS must be declared as an array"
      return 1
      ;;
  esac

  local -n docs_commands_ref=CHECK_PROFILE_DOCS_COMMANDS
  if [ "${#docs_commands_ref[@]}" -eq 0 ]; then
    repo_auto_stop "CHECK_PROFILE_DOCS_COMMANDS must not be empty"
    return 1
  fi

  decl=$(declare -p CHECK_PROFILE_NONE_COMMANDS 2>/dev/null) || {
    repo_auto_stop "CHECK_PROFILE_NONE_COMMANDS must be declared as an array"
    return 1
  }

  case "$decl" in
    declare\ -a*)
      ;;
    *)
      repo_auto_stop "CHECK_PROFILE_NONE_COMMANDS must be declared as an array"
      return 1
      ;;
  esac

  return 0
}

repo_auto_print_config_summary() {
  local entry
  local -n docs_commands_ref=CHECK_PROFILE_DOCS_COMMANDS
  local -n none_commands_ref=CHECK_PROFILE_NONE_COMMANDS

  repo_auto_validate_required_config || return 1

  printf 'repo-automation config summary:\n'
  printf '  REPO_AUTOMATION_CONF_VERSION=%s\n' "$REPO_AUTOMATION_CONF_VERSION"
  printf '  REPO_AUTOMATION_VERSION=%s\n' "$REPO_AUTOMATION_VERSION"
  printf '  UPSTREAM_REPO_FULL_NAME=%s\n' "$UPSTREAM_REPO_FULL_NAME"
  printf '  UPSTREAM_ISSUE_URL=%s\n' "$UPSTREAM_ISSUE_URL"
  printf '  INSTALLED_FROM=%s\n' "$INSTALLED_FROM"
  printf '  INSTALLED_VERSION_OR_REF=%s\n' "$INSTALLED_VERSION_OR_REF"
  printf '  INSTALLED_AT=%s\n' "$INSTALLED_AT"
  printf '  LOCAL_OVERRIDES_DOC=%s\n' "$LOCAL_OVERRIDES_DOC"
  printf '  DEFAULT_BRANCH=%s\n' "$DEFAULT_BRANCH"
  printf '  DOCS_DIR=%s\n' "$DOCS_DIR"
  printf '  DOCS_INDEX=%s\n' "$DOCS_INDEX"
  printf '  STATE_DIR_NAME=%s\n' "$STATE_DIR_NAME"
  printf '  CI_PROVIDER=%s\n' "$CI_PROVIDER"
  printf '  PR_PROVIDER=%s\n' "$PR_PROVIDER"
  printf '  MERGE_MODE=%s\n' "$MERGE_MODE"
  printf '  DOC_PR_TIMEOUT_SECONDS=%s\n' "$DOC_PR_TIMEOUT_SECONDS"
  printf '  DOC_PR_POLL_SECONDS=%s\n' "$DOC_PR_POLL_SECONDS"
  printf '  IMPLEMENTATION_PR_TIMEOUT_SECONDS=%s\n' "$IMPLEMENTATION_PR_TIMEOUT_SECONDS"
  printf '  IMPLEMENTATION_PR_POLL_SECONDS=%s\n' "$IMPLEMENTATION_PR_POLL_SECONDS"
  printf '  DOC_BRANCH_PREFIX=%s\n' "$DOC_BRANCH_PREFIX"
  printf '  FEATURE_BRANCH_PREFIX=%s\n' "$FEATURE_BRANCH_PREFIX"
  printf '  FIX_BRANCH_PREFIX=%s\n' "$FIX_BRANCH_PREFIX"
  printf '  CHECK_PROFILE_DEFAULT=%s\n' "$CHECK_PROFILE_DEFAULT"
  printf '  CHECK_PROFILE_DOCS_COMMANDS=('
  local first=1
  for entry in "${docs_commands_ref[@]}"; do
    if [ "$first" -eq 0 ]; then
      printf ' '
    fi
    printf '%q' "$entry"
    first=0
  done
  printf ')\n'
  printf '  CHECK_PROFILE_NONE_COMMANDS=('
  first=1
  for entry in "${none_commands_ref[@]}"; do
    if [ "$first" -eq 0 ]; then
      printf ' '
    fi
    printf '%q' "$entry"
    first=0
  done
  printf ')\n'
}

# scripts/lib/repo-automation-common.sh EOF
