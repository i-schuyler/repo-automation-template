#!/usr/bin/env bash
# repo-automation/tests/lib/smoke-gh-stub.sh

smoke_write_gh_stub() {
  local gh_stub_dir="$1"

  mkdir -p "$gh_stub_dir" || return 1
  cat > "$gh_stub_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -u
cmd="${1:-}"
sub="${2:-}"
shift 2 >/dev/null 2>&1 || true
  case "$cmd $sub" in
  'auth status')
    exit 0
    ;;
  'pr checks')
    if [ -n "${GH_STUB_PR_CHECKS_SEQUENCE_FILE:-}" ] && [ -f "$GH_STUB_PR_CHECKS_SEQUENCE_FILE" ]; then
      first_line="$(sed -n '1p' "$GH_STUB_PR_CHECKS_SEQUENCE_FILE" 2>/dev/null || true)"
      rest_lines="$(sed -n '2,$p' "$GH_STUB_PR_CHECKS_SEQUENCE_FILE" 2>/dev/null || true)"
      if [ -n "$first_line" ]; then
        printf '%s\n' "$first_line"
        printf '%s\n' "$rest_lines" > "$GH_STUB_PR_CHECKS_SEQUENCE_FILE"
      else
        printf '%s\n' "${GH_STUB_PR_CHECKS_JSON:-[]}"
      fi
    else
      printf '%s\n' "${GH_STUB_PR_CHECKS_JSON:-[]}"
    fi
    ;;
  'pr view')
    if [ -n "${GH_STUB_PR_VIEW_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr view $*" >> "$GH_STUB_PR_VIEW_LOG_FILE"
    fi
    if [ -n "${GH_STUB_PR_VIEW_FAIL_ONCE_FILE:-}" ] && [ ! -e "${GH_STUB_PR_VIEW_FAIL_ONCE_FILE}" ]; then
      : > "$GH_STUB_PR_VIEW_FAIL_ONCE_FILE"
      printf '%s\n' "${GH_STUB_PR_VIEW_FAIL_ONCE_STDERR:-net/http: TLS handshake timeout}" >&2
      exit 1
    fi
    case " $* " in
      *' --json '*)
        if [[ " $* " != *' --jq '* ]]; then
          GH_STUB_PR_VIEW_NUMBER_VALUE="${GH_STUB_PR_VIEW_NUMBER:-123}" \
          GH_STUB_PR_VIEW_TITLE_VALUE="${GH_STUB_PR_VIEW_TITLE:-demo title}" \
          GH_STUB_PR_VIEW_URL_VALUE="${GH_STUB_PR_VIEW_URL:-https://github.com/i-schuyler/repo-automation-template/pull/123}" \
          GH_STUB_PR_VIEW_STATE_VALUE="${GH_STUB_PR_VIEW_STATE:-OPEN}" \
          GH_STUB_PR_VIEW_IS_DRAFT_VALUE="${GH_STUB_PR_VIEW_IS_DRAFT:-false}" \
          GH_STUB_PR_VIEW_MERGEABLE_VALUE="${GH_STUB_PR_VIEW_MERGEABLE:-MERGEABLE}" \
          GH_STUB_PR_VIEW_HEAD_SHA_VALUE="${GH_STUB_PR_VIEW_HEAD_SHA:-}" \
          GH_STUB_PR_VIEW_HEAD_REF_VALUE="${GH_STUB_PR_VIEW_HEAD_REF:-feature/demo}" \
          python3 - <<'PY'
import json
import os

number_value = os.environ.get('GH_STUB_PR_VIEW_NUMBER_VALUE', '123')
try:
    number_value = int(number_value)
except Exception:
    pass

data = {
    'number': number_value,
    'title': os.environ.get('GH_STUB_PR_VIEW_TITLE_VALUE', 'demo title'),
    'url': os.environ.get('GH_STUB_PR_VIEW_URL_VALUE', 'https://github.com/i-schuyler/repo-automation-template/pull/123'),
    'state': os.environ.get('GH_STUB_PR_VIEW_STATE_VALUE', 'OPEN'),
    'isDraft': os.environ.get('GH_STUB_PR_VIEW_IS_DRAFT_VALUE', 'false').lower() == 'true',
    'mergeable': os.environ.get('GH_STUB_PR_VIEW_MERGEABLE_VALUE', 'MERGEABLE'),
    'headRefOid': os.environ.get('GH_STUB_PR_VIEW_HEAD_SHA_VALUE', ''),
    'headRefName': os.environ.get('GH_STUB_PR_VIEW_HEAD_REF_VALUE', 'feature/demo'),
}
print(json.dumps(data))
PY
          exit 0
        fi
        ;;
    esac
    case " $* " in
      *' --json number '*|*' --jq .number '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_NUMBER:-123}"
        ;;
      *' --json title '*|*' --jq .title '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_TITLE:-demo title}"
        ;;
      *' --json url '*|*' --jq .url '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_URL:-https://github.com/i-schuyler/repo-automation-template/pull/123}"
        ;;
      *' --json state '*|*' --jq .state '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_STATE:-OPEN}"
        ;;
      *' --json isDraft '*|*' --jq .isDraft '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_IS_DRAFT:-false}"
        ;;
      *' --json mergeable '*|*' --jq .mergeable '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_MERGEABLE:-MERGEABLE}"
        ;;
      *' --json headRefName '*|*' --jq .headRefName '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_HEAD_REF:-feature/demo}"
        ;;
      *' --json headRefOid '*|*' --jq .headRefOid '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_HEAD_SHA:-}"
        ;;
      *)
        printf '%s\n' "${GH_STUB_PR_VIEW_HEAD_REF:-feature/demo}"
        ;;
    esac
    ;;
  'pr merge')
    if [ -n "${GH_STUB_PR_MERGE_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr merge $*" >> "$GH_STUB_PR_MERGE_LOG_FILE"
    fi
    if [ -n "${GH_STUB_PR_MERGE_STDERR_FILE:-}" ]; then
      printf '%s\n' "gh pr merge $*" >> "$GH_STUB_PR_MERGE_STDERR_FILE"
    fi
    if [ "${GH_STUB_PR_MERGE_EXIT:-0}" -ne 0 ] 2>/dev/null; then
      printf '%s\n' "${GH_STUB_PR_MERGE_ERROR:-merge failed}" >&2
      exit "${GH_STUB_PR_MERGE_EXIT}"
    fi
    if [ "${GH_STUB_PR_MERGE_UPDATE_MAIN:-0}" -eq 1 ] 2>/dev/null; then
      git branch -f main HEAD >/dev/null 2>&1 || true
    fi
    ;;
  'pr create')
    body_file=""
    title=""
    base=""
    head=""
    prev=""
    for arg in "$@"; do
      if [ -n "$prev" ]; then
        case "$prev" in
          --title)
            title="$arg"
            ;;
          --body-file)
            body_file="$arg"
            ;;
          --base)
            base="$arg"
            ;;
          --head)
            head="$arg"
            ;;
        esac
        prev=""
        continue
      fi
      case "$arg" in
        --title|--body-file|--base|--head)
          prev="$arg"
          ;;
      esac
    done
    if [ -n "${GH_STUB_PR_CREATE_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr create title=$title base=$base head=$head body_file=$body_file" >> "$GH_STUB_PR_CREATE_LOG_FILE"
    fi
    if [ -n "$body_file" ] && [ -f "$body_file" ] && [ -n "${GH_STUB_PR_CREATE_BODY_COPY_FILE:-}" ]; then
      cat "$body_file" > "$GH_STUB_PR_CREATE_BODY_COPY_FILE"
    fi
    if [ -n "$body_file" ] && [ -f "$body_file" ] && [ -n "${GH_STUB_PR_CREATE_BODY_CONTENT_FILE:-}" ]; then
      cat "$body_file" > "$GH_STUB_PR_CREATE_BODY_CONTENT_FILE"
    fi
    printf '%s\n' "${GH_STUB_PR_CREATE_URL:-https://github.com/i-schuyler/repo-automation-template/pull/123}"
    ;;
  'pr edit')
    body_file=""
    number="${1:-}"
    prev=""
    for arg in "$@"; do
      if [ -n "$prev" ]; then
        case "$prev" in
          --body-file)
            body_file="$arg"
            ;;
        esac
        prev=""
        continue
      fi
      case "$arg" in
        --body-file=*)
          body_file="${arg#--body-file=}"
          ;;
        --body-file)
          prev="$arg"
          ;;
      esac
    done
    if [ -n "${GH_STUB_PR_EDIT_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr edit number=$number body_file=$body_file" >> "$GH_STUB_PR_EDIT_LOG_FILE"
    fi
    if [ "${GH_STUB_PR_EDIT_EXIT:-0}" -ne 0 ] 2>/dev/null; then
      printf '%s\n' "${GH_STUB_PR_EDIT_ERROR:-gh pr edit failed}" >&2
      exit "${GH_STUB_PR_EDIT_EXIT}"
    fi
    if [ -n "$body_file" ] && [ -f "$body_file" ] && [ -n "${GH_STUB_PR_EDIT_BODY_COPY_FILE:-}" ]; then
      cat "$body_file" > "$GH_STUB_PR_EDIT_BODY_COPY_FILE"
    fi
    if [ -n "$body_file" ] && [ -f "$body_file" ] && [ -n "${GH_STUB_PR_EDIT_BODY_CONTENT_FILE:-}" ]; then
      cat "$body_file" > "$GH_STUB_PR_EDIT_BODY_CONTENT_FILE"
    fi
    ;;
  'pr list')
    case " $* " in
      *' --jq '*)
        printf '%s\n' "${GH_STUB_PR_LIST_NUMBER:-}"
        ;;
      *)
        printf '%s\n' "${GH_STUB_PR_LIST_JSON:-[]}"
        ;;
    esac
    ;;
  'run list')
    if [ -n "${GH_STUB_RUN_LIST_LOG_FILE:-}" ]; then
      printf '%s\n' "gh run list $*" >> "$GH_STUB_RUN_LIST_LOG_FILE"
    fi
    if [ -n "${GH_STUB_RUN_LIST_SEQUENCE_FILE:-}" ] && [ -f "$GH_STUB_RUN_LIST_SEQUENCE_FILE" ]; then
      first_line="$(sed -n '1p' "$GH_STUB_RUN_LIST_SEQUENCE_FILE" 2>/dev/null || true)"
      rest_lines="$(sed -n '2,$p' "$GH_STUB_RUN_LIST_SEQUENCE_FILE" 2>/dev/null || true)"
      if [ -n "$first_line" ]; then
        printf '%s\n' "$first_line"
        printf '%s\n' "$rest_lines" > "$GH_STUB_RUN_LIST_SEQUENCE_FILE"
      else
        printf '%s\n' "${GH_STUB_RUN_LIST_JSON:-[]}"
      fi
    elif [ -n "${GH_STUB_RUN_LIST_FAIL_ONCE_FILE:-}" ] && [ ! -e "${GH_STUB_RUN_LIST_FAIL_ONCE_FILE}" ]; then
      : > "$GH_STUB_RUN_LIST_FAIL_ONCE_FILE"
      printf '%s\n' "${GH_STUB_RUN_LIST_FAIL_ONCE_STDERR:-net/http: TLS handshake timeout}" >&2
      exit 1
    elif [[ " $* " == *' --commit '* && " $* " == *' --event pull_request '* && -n "${GH_STUB_RUN_LIST_SHA_PR_JSON:-}" ]]; then
      printf '%s\n' "$GH_STUB_RUN_LIST_SHA_PR_JSON"
    elif [[ " $* " == *' --commit '* && -n "${GH_STUB_RUN_LIST_SHA_JSON:-}" ]]; then
      printf '%s\n' "$GH_STUB_RUN_LIST_SHA_JSON"
    elif [[ " $* " == *' --branch '* && " $* " == *' --event pull_request '* && -n "${GH_STUB_RUN_LIST_BRANCH_PR_JSON:-}" ]]; then
      printf '%s\n' "$GH_STUB_RUN_LIST_BRANCH_PR_JSON"
    else
      printf '%s\n' "${GH_STUB_RUN_LIST_JSON:-[]}"
    fi
    ;;
  'run view')
    if [ -n "${GH_STUB_RUN_VIEW_ALWAYS_FAIL_STDERR:-}" ]; then
      printf '%s\n' "${GH_STUB_RUN_VIEW_ALWAYS_FAIL_STDERR}" >&2
      exit 1
    fi
    if [ -n "${GH_STUB_RUN_VIEW_FAIL_ONCE_FILE:-}" ] && [ ! -e "${GH_STUB_RUN_VIEW_FAIL_ONCE_FILE}" ]; then
      : > "$GH_STUB_RUN_VIEW_FAIL_ONCE_FILE"
      printf '%s\n' "${GH_STUB_RUN_VIEW_FAIL_ONCE_STDERR:-net/http: TLS handshake timeout}" >&2
      exit 1
    fi
    if [ -n "${GH_STUB_RUN_VIEW_CALLED_FILE:-}" ]; then
      : > "$GH_STUB_RUN_VIEW_CALLED_FILE"
    fi
    if [ "${GH_STUB_RUN_VIEW_EMPTY:-0}" -eq 1 ] 2>/dev/null; then
      exit 0
    fi
    case " $* " in
      *' --log-failed '*)
        printf '%s\n' "${GH_STUB_RUN_VIEW_FAILED_LOG:-}"
        ;;
      *)
        printf '%s\n' "${GH_STUB_RUN_VIEW_LOG:-}"
        ;;
    esac
    ;;
  'api repos/'*)
    endpoint="$sub"
    case "$endpoint" in
      */actions/permissions)
        printf '%s\n' "${GH_STUB_ACTIONS_PERMISSIONS_JSON:-{\"enabled\":true,\"allowed_actions\":\"all\"}}"
        ;;
      */branches/*/protection)
        printf '%s\n' "${GH_STUB_BRANCH_PROTECTION_JSON:-{\"required_status_checks\":{}}}"
        ;;
      */rulesets)
        printf '%s\n' "${GH_STUB_RULESETS_JSON:-[]}"
        ;;
      *)
        printf '%s\n' "${GH_STUB_REPO_JSON:-{\"default_branch\":\"main\",\"delete_branch_on_merge\":true,\"allow_merge_commit\":true,\"allow_squash_merge\":true,\"allow_rebase_merge\":true}}"
        ;;
    esac
    ;;
  *)
    printf 'gh stub unexpected command: %s %s\n' "$cmd" "$sub" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$gh_stub_dir/gh" || return 1
}

smoke_reset_gh_stub_state() {
  local gh_stub_var=""

  for gh_stub_var in \
    GH_STUB_ACTIONS_PERMISSIONS_JSON \
    GH_STUB_BRANCH_PROTECTION_JSON \
    GH_STUB_REPO_JSON \
    GH_STUB_RULESETS_JSON \
    GH_STUB_PR_CHECKS_JSON \
    GH_STUB_PR_CHECKS_SEQUENCE_FILE \
    GH_STUB_PR_CREATE_BODY_CONTENT_FILE \
    GH_STUB_PR_CREATE_BODY_COPY_FILE \
    GH_STUB_PR_CREATE_LOG_FILE \
    GH_STUB_PR_CREATE_NUMBER \
    GH_STUB_PR_CREATE_URL \
    GH_STUB_PR_EDIT_BODY_CONTENT_FILE \
    GH_STUB_PR_EDIT_BODY_COPY_FILE \
    GH_STUB_PR_EDIT_ERROR \
    GH_STUB_PR_EDIT_EXIT \
    GH_STUB_PR_EDIT_LOG_FILE \
    GH_STUB_PR_LIST_JSON \
    GH_STUB_PR_LIST_NUMBER \
    GH_STUB_PR_MERGE_ERROR \
    GH_STUB_PR_MERGE_EXIT \
    GH_STUB_PR_MERGE_LOG_FILE \
    GH_STUB_PR_MERGE_STDERR_FILE \
    GH_STUB_PR_MERGE_UPDATE_MAIN \
    GH_STUB_PR_STATE_FILE \
    GH_STUB_PR_VIEW_BODY_ERROR \
    GH_STUB_PR_VIEW_BODY_EXIT \
    GH_STUB_PR_VIEW_BODY_FILE \
    GH_STUB_PR_VIEW_BODY_TEXT \
    GH_STUB_PR_VIEW_EMPTY \
    GH_STUB_PR_VIEW_FAIL_ONCE_FILE \
    GH_STUB_PR_VIEW_FAIL_ONCE_STDERR \
    GH_STUB_PR_VIEW_HEAD_REF \
    GH_STUB_PR_VIEW_HEAD_SHA \
    GH_STUB_PR_VIEW_IS_DRAFT \
    GH_STUB_PR_VIEW_LOG_FILE \
    GH_STUB_PR_VIEW_MERGEABLE \
    GH_STUB_PR_VIEW_NUMBER \
    GH_STUB_PR_VIEW_STATE \
    GH_STUB_PR_VIEW_TITLE \
    GH_STUB_PR_VIEW_URL \
    GH_STUB_RUN_LIST_FAIL_ONCE_FILE \
    GH_STUB_RUN_LIST_FAIL_ONCE_STDERR \
    GH_STUB_RUN_LIST_JSON \
    GH_STUB_RUN_LIST_BRANCH_PR_JSON \
    GH_STUB_RUN_LIST_LOG_FILE \
    GH_STUB_RUN_LIST_SHA_JSON \
    GH_STUB_RUN_LIST_SHA_PR_JSON \
    GH_STUB_RUN_LIST_SEQUENCE_FILE \
    GH_STUB_RUN_VIEW_ALWAYS_FAIL_STDERR \
    GH_STUB_RUN_VIEW_CALLED_FILE \
    GH_STUB_RUN_VIEW_EMPTY \
    GH_STUB_RUN_VIEW_FAIL_ONCE_FILE \
    GH_STUB_RUN_VIEW_FAIL_ONCE_STDERR \
    GH_STUB_RUN_VIEW_FAILED_LOG \
    GH_STUB_RUN_VIEW_LOG
  do
    unset -v "$gh_stub_var" >/dev/null 2>&1 || true
  done
}

# repo-automation/tests/lib/smoke-gh-stub.sh EOF
