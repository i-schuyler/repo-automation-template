#!/usr/bin/env bash
# repo-automation/tests/lib/smoke-common.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-common.sh"

smoke_common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke_tests_dir="$(cd "$smoke_common_dir/.." && pwd)"
smoke_repo_root="$(cd "$smoke_tests_dir/../.." && pwd)"

smoke_timeout_seconds="${smoke_timeout_seconds:-120}"
smoke_test_base=""
smoke_test_dir=""
smoke_remote_dir=""
smoke_expected_origin_url="git@github.com:i-schuyler/repo-automation-template.git"
smoke_output_mode="${smoke_output_mode:-summary}"
smoke_help_requested=0

smoke_usage() {
  printf 'Usage: repo-automation/tests/smoke.sh [--quiet] [--explain] [--json] [--help]\n'
}

smoke_parse_output_mode() {
  local arg=""

  while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
      --quiet)
        smoke_output_mode="quiet"
        ;;
      --explain)
        smoke_output_mode="explain"
        ;;
      --json)
        smoke_output_mode="json"
        ;;
      --help)
        smoke_usage
        # shellcheck disable=SC2034 # Read by smoke wrapper scripts after parsing.
        smoke_help_requested=1
        return 0
        ;;
      *)
        if [ "${arg#--}" != "$arg" ]; then
          printf 'fail: unknown flag: %s\n' "$arg" >&2
        else
          printf 'fail: unknown argument: %s\n' "$arg" >&2
        fi
        return 1
        ;;
    esac
    shift
  done

  TEST_OUTPUT_MODE="$smoke_output_mode"
  return 0
}

smoke_finish_output() {
  local status="${1:-0}"

  test_finish_output "$status"
  return "$status"
}

smoke_contract_names=(
  "smoke:add-doc-pr-contract"
  "smoke:pr-create-contract"
  "smoke:report-upstream-contract"
  "smoke:failure-log-contract"
  "smoke:run-tests-contract"
  "smoke:touched-files-ci-contract"
  "smoke:ci-log-dump-contract"
  "smoke:repo-doctor-contract"
  "smoke:status-packet-contract"
  "smoke:post-codex-packet-contract"
  "smoke:review-pack-contract"
  "smoke:pr-finish-watch-exit"
  "smoke:repo-zip-contract"
  "smoke:evidence-bundle-contract"
  "smoke:repair-prompt-contract"
  "smoke:github-settings-check"
  "smoke:managed-file-tools"
  "smoke:shellcheck-ci-parity"
  "smoke:installer-contract"
  "smoke:starter-template-contract"
  "smoke:branch-cleanup-preflight"
  "smoke:prepare-release-contract"
  "smoke:automation-freshness-contract"
)

smoke_contract_scripts=(
  "repo-automation/tests/contracts/add-doc-pr.sh"
  "repo-automation/tests/contracts/pr-create.sh"
  "repo-automation/tests/contracts/report-upstream.sh"
  "repo-automation/tests/contracts/failure-log.sh"
  "repo-automation/tests/contracts/run-tests.sh"
  "repo-automation/tests/contracts/touched-files.sh"
  "repo-automation/tests/contracts/ci-log-dump.sh"
  "repo-automation/tests/contracts/repo-doctor.sh"
  "repo-automation/tests/contracts/status-packet.sh"
  "repo-automation/tests/contracts/post-codex-packet.sh"
  "repo-automation/tests/contracts/review-pack.sh"
  "repo-automation/tests/contracts/pr-finish-watch.sh"
  "repo-automation/tests/contracts/repo-zip.sh"
  "repo-automation/tests/contracts/evidence-bundle.sh"
  "repo-automation/tests/contracts/repair-prompt.sh"
  "repo-automation/tests/contracts/github-settings-check.sh"
  "repo-automation/tests/contracts/managed-file-tools.sh"
  "repo-automation/tests/contracts/shellcheck-ci-parity.sh"
  "repo-automation/tests/contracts/installer.sh"
  "repo-automation/tests/contracts/starter-template.sh"
  "repo-automation/tests/contracts/branch-cleanup-preflight.sh"
  "repo-automation/tests/contracts/prepare-release.sh"
  "repo-automation/tests/contracts/automation-freshness.sh"
)

smoke_run_all_contracts() {
  local status=0
  local i=0

  for i in "${!smoke_contract_scripts[@]}"; do
    smoke_run_named_check "${smoke_contract_names[$i]}" "${smoke_contract_scripts[$i]}" || status=1
  done

  return "$status"
}

smoke_run() {
  local status=0
  local smoke_output_capture=""

  trap 'test_cleanup' EXIT INT TERM

  cd "$smoke_repo_root" || return 1

  if [ "$smoke_timeout_seconds" -gt 0 ] && ! test_have_timeout; then
    test_warn_timeout_once
  fi

  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    smoke_run_all_contracts || status=1
  else
    mkdir -p "$TEST_TEMP_ROOT" || return 1
    smoke_output_capture="$(mktemp "$TEST_TEMP_ROOT/smoke.XXXXXX")" || return 1
    exec 3>&1 4>&2
    exec >"$smoke_output_capture" 2>&1
    smoke_run_all_contracts || status=1
    exec 1>&3 2>&4
    rm -f -- "$smoke_output_capture" >/dev/null 2>&1 || true
  fi

  return "$status"
}

smoke_json_assert() {
  local json_file="$1"
  local check_code="$2"
  if python3 - "$json_file" "$check_code" <<'PY'
import json
import pathlib
import sys

json_path = pathlib.Path(sys.argv[1])
check_code = sys.argv[2]
data = json.loads(json_path.read_text(encoding="utf-8"))
globals_dict = {"data": data}
ok = eval(check_code, {}, globals_dict)  # controlled local test expression
sys.exit(0 if ok else 1)
PY
  then
    return 0
  fi

  return 1
}

smoke_assert_flag_error_shape() {
  local stderr_file="$1"
  local reason="$2"
  local flag="$3"
  local fix="$4"

  grep -Fxq "fail: $reason" "$stderr_file" &&
    grep -Fxq "flag: $flag" "$stderr_file" &&
    grep -Fxq "fix: $fix" "$stderr_file"
}

smoke_assert_single_path_output() {
  local output_file="$1"

  [ "$(wc -l < "$output_file" | tr -d '[:space:]')" = "1" ] &&
    ! grep -Eq '^(INFO|PASS):|^(packet dir|packet zip|bundle dir|bundle zip|zip path|file count):' "$output_file"
}

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
    if [ -n "${GH_STUB_PR_VIEW_FAIL_ONCE_FILE:-}" ] && [ ! -e "${GH_STUB_PR_VIEW_FAIL_ONCE_FILE}" ]; then
      : > "$GH_STUB_PR_VIEW_FAIL_ONCE_FILE"
      printf '%s\n' "${GH_STUB_PR_VIEW_FAIL_ONCE_STDERR:-net/http: TLS handshake timeout}" >&2
      exit 1
    fi
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
    if [ -n "${GH_STUB_RUN_LIST_FAIL_ONCE_FILE:-}" ] && [ ! -e "${GH_STUB_RUN_LIST_FAIL_ONCE_FILE}" ]; then
      : > "$GH_STUB_RUN_LIST_FAIL_ONCE_FILE"
      printf '%s\n' "${GH_STUB_RUN_LIST_FAIL_ONCE_STDERR:-net/http: TLS handshake timeout}" >&2
      exit 1
    fi
    printf '%s\n' "${GH_STUB_RUN_LIST_JSON:-[]}"
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

smoke_write_artifact_safety_fixture() {
  local root="$1"

  mkdir -p "$root/docs" "$root/build" "$root/node_modules/pkg" "$root/vendor/cache" "$root/.cache" "$root/repo-automation-output/review-pack" || return 1

  cat > "$root/.editorconfig" <<'EOF'
root = true

[*.md]
charset = utf-8
EOF
  printf '%s\n' '.cache/ignored.cache' >> "$root/.gitignore"
  cat > "$root/.env" <<'EOF'
SECRET_TOKEN=fixture-secret
EOF
  printf 'ignored cache fixture\n' > "$root/.cache/ignored.cache"
  printf 'safe untracked doc fixture\n' > "$root/docs/safe-untracked.md"
  printf 'generated packet artifact fixture\n' > "$root/repo-automation-output/review-pack/output.txt"
  printf 'build output fixture\n' > "$root/build/output.bin"
  printf 'nested dependency cache fixture\n' > "$root/node_modules/pkg/cache.txt"
  printf 'nested vendor cache fixture\n' > "$root/vendor/cache/tool.bin"
}

smoke_setup_temp_repo() {
  mkdir -p "$TEST_TEMP_ROOT" || return 1
  smoke_test_base="$(mktemp -d "${TEST_TEMP_ROOT}/smoke.XXXXXX")" || return 1
  test_register_temp_dir "$smoke_test_base" || return 1
  smoke_test_dir="$smoke_test_base/smoke"
  smoke_remote_dir="$smoke_test_base/smoke-remote.git"
  mkdir -p "$smoke_test_dir" || return 1

  export smoke_repo_root smoke_test_base smoke_test_dir smoke_remote_dir smoke_expected_origin_url smoke_timeout_seconds

  mkdir -p "$smoke_test_dir/repo-automation/bin" "$smoke_test_dir/repo-automation/lib" "$smoke_test_dir/repo-automation/tests/lib" "$smoke_test_dir/repo-automation/tests/lib/contracts" "$smoke_test_dir/repo-automation/tests/contracts" "$smoke_test_dir/repo-automation/tests" || return 1
  cp "$smoke_repo_root/AGENTS.md" "$smoke_test_dir/AGENTS.md" || return 1
  cp "$smoke_repo_root/repo-automation/lib/common.sh" "$smoke_test_dir/repo-automation/lib/common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/bin/branch-cleanup" "$smoke_test_dir/repo-automation/bin/branch-cleanup" || return 1
  cp "$smoke_repo_root/repo-automation/bin/codex-slice-preflight" "$smoke_test_dir/repo-automation/bin/codex-slice-preflight" || return 1
  cp "$smoke_repo_root/repo-automation/bin/pr-finish" "$smoke_test_dir/repo-automation/bin/pr-finish" || return 1
  cp "$smoke_repo_root/repo-automation/bin/add-doc-pr" "$smoke_test_dir/repo-automation/bin/add-doc-pr" || return 1
  cp "$smoke_repo_root/repo-automation/bin/pr-create" "$smoke_test_dir/repo-automation/bin/pr-create" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-flow" "$smoke_test_dir/repo-automation/bin/repo-flow" || return 1
  cp "$smoke_repo_root/repo-automation/bin/automation-freshness" "$smoke_test_dir/repo-automation/bin/automation-freshness" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-automation-report-upstream" "$smoke_test_dir/repo-automation/bin/repo-automation-report-upstream" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-doctor" "$smoke_test_dir/repo-automation/bin/repo-doctor" || return 1
  cp "$smoke_repo_root/repo-automation/bin/github-settings-check" "$smoke_test_dir/repo-automation/bin/github-settings-check" || return 1
  cp "$smoke_repo_root/repo-automation/bin/managed-file-check" "$smoke_test_dir/repo-automation/bin/managed-file-check" || return 1
  cp "$smoke_repo_root/repo-automation/bin/managed-file-add" "$smoke_test_dir/repo-automation/bin/managed-file-add" || return 1
  cp "$smoke_repo_root/repo-automation/bin/failure-log" "$smoke_test_dir/repo-automation/bin/failure-log" || return 1
  cp "$smoke_repo_root/repo-automation/bin/touched-files" "$smoke_test_dir/repo-automation/bin/touched-files" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-status" "$smoke_test_dir/repo-automation/bin/ci-status" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-watch" "$smoke_test_dir/repo-automation/bin/ci-watch" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-log-dump" "$smoke_test_dir/repo-automation/bin/ci-log-dump" || return 1
  cp "$smoke_repo_root/repo-automation/bin/shellcheck-ci-parity" "$smoke_test_dir/repo-automation/bin/shellcheck-ci-parity" || return 1
  cp "$smoke_repo_root/repo-automation/bin/status-packet" "$smoke_test_dir/repo-automation/bin/status-packet" || return 1
  cp "$smoke_repo_root/repo-automation/bin/post-codex-packet" "$smoke_test_dir/repo-automation/bin/post-codex-packet" || return 1
  cp "$smoke_repo_root/repo-automation/bin/review-pack" "$smoke_test_dir/repo-automation/bin/review-pack" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repair-prompt" "$smoke_test_dir/repo-automation/bin/repair-prompt" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-zip" "$smoke_test_dir/repo-automation/bin/repo-zip" || return 1
  cp "$smoke_repo_root/repo-automation/bin/evidence-bundle" "$smoke_test_dir/repo-automation/bin/evidence-bundle" || return 1
  cp "$smoke_repo_root/repo-automation/bin/starter-template-ready" "$smoke_test_dir/repo-automation/bin/starter-template-ready" || return 1
  cp "$smoke_repo_root/repo-automation/bin/prepare-release" "$smoke_test_dir/repo-automation/bin/prepare-release" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-automation-install" "$smoke_test_dir/repo-automation/bin/repo-automation-install" || return 1
  cp "$smoke_repo_root/repo-automation/bin/run-tests" "$smoke_test_dir/repo-automation/bin/run-tests" || return 1
  cp "$smoke_repo_root/repo-automation/helper-metadata.json" "$smoke_test_dir/repo-automation/helper-metadata.json" || return 1
  cp "$smoke_repo_root/repo-automation/manifest.json" "$smoke_test_dir/repo-automation/manifest.json" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/test-common.sh" "$smoke_test_dir/repo-automation/tests/lib/test-common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-common.sh" "$smoke_test_dir/repo-automation/tests/lib/smoke-common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/contracts"/*.sh "$smoke_test_dir/repo-automation/tests/lib/contracts/" || return 1
  cp "$smoke_repo_root/repo-automation/tests/docs-check.sh" "$smoke_test_dir/repo-automation/tests/docs-check.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/smoke.sh" "$smoke_test_dir/repo-automation/tests/smoke.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/version-consistency.sh" "$smoke_test_dir/repo-automation/tests/version-consistency.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/contracts"/*.sh "$smoke_test_dir/repo-automation/tests/contracts/" || return 1
  chmod +x "$smoke_test_dir/repo-automation/bin/branch-cleanup" "$smoke_test_dir/repo-automation/bin/codex-slice-preflight" "$smoke_test_dir/repo-automation/bin/pr-finish" "$smoke_test_dir/repo-automation/bin/add-doc-pr" "$smoke_test_dir/repo-automation/bin/pr-create" "$smoke_test_dir/repo-automation/bin/repo-flow" "$smoke_test_dir/repo-automation/bin/automation-freshness" "$smoke_test_dir/repo-automation/bin/github-settings-check" "$smoke_test_dir/repo-automation/bin/managed-file-check" "$smoke_test_dir/repo-automation/bin/managed-file-add" "$smoke_test_dir/repo-automation/bin/starter-template-ready" "$smoke_test_dir/repo-automation/bin/prepare-release" "$smoke_test_dir/repo-automation/bin/repo-automation-report-upstream" "$smoke_test_dir/repo-automation/bin/repo-doctor" "$smoke_test_dir/repo-automation/bin/failure-log" "$smoke_test_dir/repo-automation/bin/touched-files" "$smoke_test_dir/repo-automation/bin/ci-status" "$smoke_test_dir/repo-automation/bin/ci-watch" "$smoke_test_dir/repo-automation/bin/shellcheck-ci-parity" "$smoke_test_dir/repo-automation/bin/status-packet" "$smoke_test_dir/repo-automation/bin/post-codex-packet" "$smoke_test_dir/repo-automation/bin/review-pack" "$smoke_test_dir/repo-automation/bin/repair-prompt" "$smoke_test_dir/repo-automation/bin/repo-zip" "$smoke_test_dir/repo-automation/bin/evidence-bundle" "$smoke_test_dir/repo-automation/bin/repo-automation-install" "$smoke_test_dir/repo-automation/bin/run-tests" "$smoke_test_dir/repo-automation/tests/docs-check.sh" "$smoke_test_dir/repo-automation/tests/smoke.sh" "$smoke_test_dir/repo-automation/tests/version-consistency.sh" "$smoke_test_dir/repo-automation/tests/contracts"/*.sh || return 1

  (
    cd "$smoke_test_dir" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-test" || return 1
    git config user.email "repo-automation-test@example.com" || return 1
    cat > README.md <<EOF
# smoke

Current version: 0.1.0
EOF
    cat > CONTRIBUTING.md <<'EOF'
# Contributing

Smoke fixture contribution notes.
EOF
    cat > SUPPORT.md <<'EOF'
# Support

Smoke fixture support notes.
EOF
    cat > VERSION <<EOF
0.1.0
EOF
    cat > CHANGELOG.md <<EOF
# Changelog

## [0.1.0] - Unreleased

EOF
    mkdir -p docs .github/workflows .github/ISSUE_TEMPLATE || return 1
    cp -R "$smoke_repo_root/repo-automation/docs" repo-automation/ || return 1
    cp "$smoke_repo_root/.github/pull_request_template.md" .github/pull_request_template.md || return 1
    cp "$smoke_repo_root/.github/ISSUE_TEMPLATE/automation-bug.yml" .github/ISSUE_TEMPLATE/automation-bug.yml || return 1
    cp "$smoke_repo_root/.github/ISSUE_TEMPLATE/automation-feature.yml" .github/ISSUE_TEMPLATE/automation-feature.yml || return 1
    mkdir -p examples/downstream/docs/repo-automation || return 1
    cat > docs/DECISIONS.md <<EOF
# Decisions

| Current version line | starts at 0.1.0 |
EOF
    cat > docs/KNOWN_LIMITATIONS.md <<'EOF'
# Known Limitations

Smoke fixture limitations.
EOF
    cat > docs/VERSIONING.md <<EOF
# Versioning

Current version: 0.1.0

## Version Modes

The automation release version is checked by prepare-release.

Version numbers must stay aligned in these places:
- VERSION
- .repo-automation.conf
- REPO_AUTOMATION_VERSION
- REPO_AUTOMATION_CONF_VERSION
- repo-automation/tests/version-consistency.sh
- examples/downstream/.repo-automation.conf.example
EOF
    cat > docs/DOWNSTREAM_FEEDBACK.md <<'EOF'
# Downstream Feedback

Installed config should include:

```sh
INSTALLED_VERSION_OR_REF="0.1.0"
```
EOF
    cat > docs/WORKFLOW_AUDIT_CHECKLIST.md <<'EOF'
# Workflow Audit Checklist

Smoke fixture checklist notes.
EOF
    cat > docs/INDEX.md <<EOF
# Docs Index

- [README](../README.md)
- [Changelog](../CHANGELOG.md)
- [Contributing](../CONTRIBUTING.md)
- [Support](../SUPPORT.md)
- [Decisions](../docs/DECISIONS.md)
- [Known Limitations](../docs/KNOWN_LIMITATIONS.md)
- [Downstream Feedback](../docs/DOWNSTREAM_FEEDBACK.md)
- [Versioning](../docs/VERSIONING.md)
- [Workflow Audit Checklist](../docs/WORKFLOW_AUDIT_CHECKLIST.md)
- [Pull Request Template](../.github/pull_request_template.md)
- [Automation Bug Issue Form](../.github/ISSUE_TEMPLATE/automation-bug.yml)
- [Automation Feature Issue Form](../.github/ISSUE_TEMPLATE/automation-feature.yml)
- [Example Downstream Config](../examples/downstream/.repo-automation.conf.example)
- [Example Downstream Repo Automation README](../examples/downstream/docs/repo-automation/README.md)
- [Branch Cleanup](../repo-automation/docs/branch-cleanup.md)
- [Codex Slice Preflight](../repo-automation/docs/codex-slice-preflight.md)
- [PR Finish](../repo-automation/docs/pr-finish.md)
- [Add Doc PR](../repo-automation/docs/add-doc-pr.md)
- [PR Create](../repo-automation/docs/pr-create.md)
- [Report Upstream](../repo-automation/docs/repo-automation-report-upstream.md)
- [Repo Doctor](../repo-automation/docs/repo-doctor.md)
- [GitHub Settings Check](../repo-automation/docs/github-settings-check.md)
- [Failure Log](../repo-automation/docs/failure-log.md)
- [Touched Files](../repo-automation/docs/touched-files.md)
- [CI Status](../repo-automation/docs/ci-status.md)
- [CI Watch](../repo-automation/docs/ci-watch.md)
- [Status Packet](../repo-automation/docs/status-packet.md)
- [Repo Zip](../repo-automation/docs/repo-zip.md)
- [Evidence Bundle](../repo-automation/docs/evidence-bundle.md)
- [Starter Template Readiness](../repo-automation/docs/starter-template-readiness.md)
- [Managed Files](../repo-automation/docs/managed-files.md)
- [Repo Automation Install](../repo-automation/docs/repo-automation-install.md)
- [Output Modes](../repo-automation/docs/output-modes.md)
- [Testing](../repo-automation/docs/testing.md)
EOF
    mkdir -p examples/downstream || return 1
    cat > examples/downstream/.repo-automation.conf.example <<EOF
REPO_AUTOMATION_VERSION="0.1.0"
INSTALLED_VERSION_OR_REF="0.1.0-EXAMPLE"
EOF
    cat > examples/downstream/docs/repo-automation/README.md <<'EOF'
# Downstream Repo Automation

```text
Repo automation installed context:
- Installed version/ref: 0.1.0-EXAMPLE
```
EOF
    cat > .github/workflows/ci.yml <<EOF
name: CI
permissions:
  contents: read
EOF
    touch .github/ISSUE_TEMPLATE/automation-bug.yml .github/ISSUE_TEMPLATE/automation-feature.yml || return 1
    git add README.md || return 1
    git add VERSION CHANGELOG.md README.md docs .github examples || return 1
    git commit -m "init" >/dev/null || return 1
    git init --bare --initial-branch=main "$smoke_remote_dir" >/dev/null || return 1
    git remote add origin "$smoke_remote_dir" || return 1
    git push -u origin main >/dev/null || return 1
    git remote set-url origin "$smoke_expected_origin_url" || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    cat > .repo-automation.conf <<EOF
# .repo-automation.conf
REPO_AUTOMATION_CONF_VERSION="0.1"
REPO_AUTOMATION_VERSION="0.1.0"
UPSTREAM_REPO_FULL_NAME="i-schuyler/repo-automation-template"
UPSTREAM_ISSUE_URL="https://github.com/i-schuyler/repo-automation-template/issues/new/choose"
INSTALLED_FROM="i-schuyler/repo-automation-template"
INSTALLED_VERSION_OR_REF="0.1.0"
INSTALLED_AT="2026-05-06"
LOCAL_OVERRIDES_DOC="repo-automation/docs/local-overrides.md"
DEFAULT_BRANCH="main"
DOCS_DIR="docs"
DOCS_INDEX="docs/INDEX.md"
STATE_DIR_NAME="repo-automation-template-tests"
REMOTE_NAME="origin"
EXPECTED_REMOTE_URL="$smoke_expected_origin_url"
PREFLIGHT_REQUIRE_CLEAN_WORKTREE="true"
CI_PROVIDER="github"
PR_PROVIDER="github"
MERGE_MODE="squash"
DOC_PR_TIMEOUT_SECONDS=60
DOC_PR_POLL_SECONDS=10
IMPLEMENTATION_PR_TIMEOUT_SECONDS=300
IMPLEMENTATION_PR_POLL_SECONDS=15
DOC_BRANCH_PREFIX="docs"
FEATURE_BRANCH_PREFIX="feature"
FIX_BRANCH_PREFIX="fix"
CHECK_PROFILE_DEFAULT="docs"
CHECK_PROFILE_DOCS_COMMANDS=("git diff --check")
CHECK_PROFILE_NONE_COMMANDS=()
# .repo-automation.conf EOF
EOF
    # Commit the full automation baseline before docs-only boundary tests.
    git add -A >/dev/null || return 1
    git commit -m "add test automation files" >/dev/null || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    return 0
  ) || return 1
}

smoke_setup_subset_repo() {
  local subset_base
  local subset_dir

  subset_base="$(mktemp -d "${TEST_TEMP_ROOT}/subset.XXXXXX")" || return 1
  test_register_temp_dir "$subset_base" || return 1
  subset_dir="$subset_base/repo"

  cp -R "$smoke_test_dir" "$subset_dir" || return 1
  cat > "$subset_dir/repo-automation/tests/smoke.sh" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
printf 'PASS: subset smoke stub
'
EOF
  chmod +x "$subset_dir/repo-automation/tests/smoke.sh" || return 1
  (
    cd "$subset_dir" || return 1
    git config user.name "repo-automation-test" || return 1
    git config user.email "repo-automation-test@example.com" || return 1
    git add repo-automation/tests/smoke.sh >/dev/null 2>&1 || return 1
    git commit -m "Stub smoke check" >/dev/null 2>&1 || return 1
  ) || return 1

  printf '%s
' "$subset_dir"
}

smoke_restore_fixture_after_timeout() {
  if [ "${TEST_LAST_TIMEOUT:-0}" -eq 1 ] || [ ! -d "$smoke_test_dir" ]; then
    smoke_setup_temp_repo || return 1
  fi
}

smoke_run_named_check() {
  local check_name="$1"
  local check_function="$2"

  if test_run_named_check "$check_name" "$check_function"; then
    return 0
  fi

  smoke_restore_fixture_after_timeout || return 1
  return 1
}

# repo-automation/tests/lib/smoke-common.sh EOF
