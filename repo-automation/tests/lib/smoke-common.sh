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
  "smoke:pr-finish-watch-exit"
  "smoke:repo-zip-contract"
  "smoke:evidence-bundle-contract"
  "smoke:github-settings-check"
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
  "repo-automation/tests/contracts/pr-finish-watch.sh"
  "repo-automation/tests/contracts/repo-zip.sh"
  "repo-automation/tests/contracts/evidence-bundle.sh"
  "repo-automation/tests/contracts/github-settings-check.sh"
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
    test_run_named_check "${smoke_contract_names[$i]}" "${smoke_contract_scripts[$i]}" || status=1
  done

  return "$status"
}

smoke_run() {
  trap 'test_cleanup' EXIT INT TERM

  cd "$smoke_repo_root" || return 1

  if [ "$smoke_timeout_seconds" -gt 0 ] && ! test_have_timeout; then
    test_warn_timeout_once
  fi

  smoke_run_all_contracts
}

smoke_json_assert() {
  local json_file="$1"
  local check_code="$2"
  if python - "$json_file" "$check_code" <<'PY'
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
    printf '%s\n' "${GH_STUB_PR_CHECKS_JSON:-[]}"
    ;;
  'pr view')
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
    printf '%s\n' "${GH_STUB_RUN_LIST_JSON:-[]}"
    ;;
  'run view')
    if [ -n "${GH_STUB_RUN_VIEW_CALLED_FILE:-}" ]; then
      : > "$GH_STUB_RUN_VIEW_CALLED_FILE"
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

smoke_setup_temp_repo() {
  mkdir -p "$TEST_TEMP_ROOT" || return 1
  smoke_test_base="$(mktemp -d "${TEST_TEMP_ROOT}/smoke.XXXXXX")" || return 1
  test_register_temp_dir "$smoke_test_base" || return 1
  smoke_test_dir="$smoke_test_base/smoke"
  smoke_remote_dir="$smoke_test_base/smoke-remote.git"
  mkdir -p "$smoke_test_dir" || return 1

  export smoke_repo_root smoke_test_base smoke_test_dir smoke_remote_dir smoke_expected_origin_url smoke_timeout_seconds

  mkdir -p "$smoke_test_dir/repo-automation/bin" "$smoke_test_dir/repo-automation/lib" "$smoke_test_dir/repo-automation/tests/lib" "$smoke_test_dir/repo-automation/tests/contracts" "$smoke_test_dir/repo-automation/tests" || return 1
  cp "$smoke_repo_root/AGENTS.md" "$smoke_test_dir/AGENTS.md" || return 1
  cp "$smoke_repo_root/repo-automation/lib/common.sh" "$smoke_test_dir/repo-automation/lib/common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/bin/branch-cleanup" "$smoke_test_dir/repo-automation/bin/branch-cleanup" || return 1
  cp "$smoke_repo_root/repo-automation/bin/codex-slice-preflight" "$smoke_test_dir/repo-automation/bin/codex-slice-preflight" || return 1
  cp "$smoke_repo_root/repo-automation/bin/pr-finish" "$smoke_test_dir/repo-automation/bin/pr-finish" || return 1
  cp "$smoke_repo_root/repo-automation/bin/add-doc-pr" "$smoke_test_dir/repo-automation/bin/add-doc-pr" || return 1
  cp "$smoke_repo_root/repo-automation/bin/pr-create" "$smoke_test_dir/repo-automation/bin/pr-create" || return 1
  cp "$smoke_repo_root/repo-automation/bin/automation-freshness" "$smoke_test_dir/repo-automation/bin/automation-freshness" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-automation-report-upstream" "$smoke_test_dir/repo-automation/bin/repo-automation-report-upstream" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-doctor" "$smoke_test_dir/repo-automation/bin/repo-doctor" || return 1
  cp "$smoke_repo_root/repo-automation/bin/github-settings-check" "$smoke_test_dir/repo-automation/bin/github-settings-check" || return 1
  cp "$smoke_repo_root/repo-automation/bin/failure-log" "$smoke_test_dir/repo-automation/bin/failure-log" || return 1
  cp "$smoke_repo_root/repo-automation/bin/touched-files" "$smoke_test_dir/repo-automation/bin/touched-files" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-status" "$smoke_test_dir/repo-automation/bin/ci-status" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-watch" "$smoke_test_dir/repo-automation/bin/ci-watch" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-log-dump" "$smoke_test_dir/repo-automation/bin/ci-log-dump" || return 1
  cp "$smoke_repo_root/repo-automation/bin/status-packet" "$smoke_test_dir/repo-automation/bin/status-packet" || return 1
  cp "$smoke_repo_root/repo-automation/bin/post-codex-packet" "$smoke_test_dir/repo-automation/bin/post-codex-packet" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-zip" "$smoke_test_dir/repo-automation/bin/repo-zip" || return 1
  cp "$smoke_repo_root/repo-automation/bin/evidence-bundle" "$smoke_test_dir/repo-automation/bin/evidence-bundle" || return 1
  cp "$smoke_repo_root/repo-automation/bin/starter-template-ready" "$smoke_test_dir/repo-automation/bin/starter-template-ready" || return 1
  cp "$smoke_repo_root/repo-automation/bin/prepare-release" "$smoke_test_dir/repo-automation/bin/prepare-release" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-automation-install" "$smoke_test_dir/repo-automation/bin/repo-automation-install" || return 1
  cp "$smoke_repo_root/repo-automation/bin/run-tests" "$smoke_test_dir/repo-automation/bin/run-tests" || return 1
  cp "$smoke_repo_root/repo-automation/manifest.json" "$smoke_test_dir/repo-automation/manifest.json" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/test-common.sh" "$smoke_test_dir/repo-automation/tests/lib/test-common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-common.sh" "$smoke_test_dir/repo-automation/tests/lib/smoke-common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/docs-check.sh" "$smoke_test_dir/repo-automation/tests/docs-check.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/smoke.sh" "$smoke_test_dir/repo-automation/tests/smoke.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/version-consistency.sh" "$smoke_test_dir/repo-automation/tests/version-consistency.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/contracts"/*.sh "$smoke_test_dir/repo-automation/tests/contracts/" || return 1
  chmod +x "$smoke_test_dir/repo-automation/bin/branch-cleanup" "$smoke_test_dir/repo-automation/bin/codex-slice-preflight" "$smoke_test_dir/repo-automation/bin/pr-finish" "$smoke_test_dir/repo-automation/bin/add-doc-pr" "$smoke_test_dir/repo-automation/bin/pr-create" "$smoke_test_dir/repo-automation/bin/automation-freshness" "$smoke_test_dir/repo-automation/bin/github-settings-check" "$smoke_test_dir/repo-automation/bin/starter-template-ready" "$smoke_test_dir/repo-automation/bin/prepare-release" "$smoke_test_dir/repo-automation/bin/repo-automation-report-upstream" "$smoke_test_dir/repo-automation/bin/repo-doctor" "$smoke_test_dir/repo-automation/bin/failure-log" "$smoke_test_dir/repo-automation/bin/touched-files" "$smoke_test_dir/repo-automation/bin/ci-status" "$smoke_test_dir/repo-automation/bin/ci-watch" "$smoke_test_dir/repo-automation/bin/status-packet" "$smoke_test_dir/repo-automation/bin/post-codex-packet" "$smoke_test_dir/repo-automation/bin/repo-zip" "$smoke_test_dir/repo-automation/bin/evidence-bundle" "$smoke_test_dir/repo-automation/bin/repo-automation-install" "$smoke_test_dir/repo-automation/bin/run-tests" "$smoke_test_dir/repo-automation/tests/docs-check.sh" "$smoke_test_dir/repo-automation/tests/smoke.sh" "$smoke_test_dir/repo-automation/tests/version-consistency.sh" "$smoke_test_dir/repo-automation/tests/contracts"/*.sh || return 1

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

smoke_check_add_doc_pr_docs_only() {
  local status=0
  local add_doc_pr_json="$smoke_test_base/add-doc-pr-plan-$$.json"
  local add_doc_pr_stderr="$smoke_test_base/add-doc-pr-plan-$$.stderr"
  local add_doc_pr_failure_details=""
  local repo_doctor_help="$smoke_test_base/repo-doctor-help-$$.txt"
  local ci_log_dump_help="$smoke_test_base/ci-log-dump-help-$$.txt"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/branch-cleanup --help >/dev/null
  ); then
    test_pass "branch-cleanup help succeeds"
  else
    test_fail "branch-cleanup help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-finish --help >/dev/null
  ); then
    test_pass "pr-finish help succeeds"
  else
    test_fail "pr-finish help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/add-doc-pr --help >/dev/null
  ); then
    test_pass "add-doc-pr help succeeds"
  else
    test_fail "add-doc-pr help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --help >/dev/null
  ); then
    test_pass "report-upstream help succeeds"
  else
    test_fail "report-upstream help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --help > "$repo_doctor_help" && grep -q 'artifact-guard' "$repo_doctor_help" && grep -q 'starter-template-readiness' "$repo_doctor_help" && grep -q 'github-settings-readiness' "$repo_doctor_help"
  ); then
    test_pass "repo-doctor help succeeds"
  else
    test_fail "repo-doctor help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --help >/dev/null
  ); then
    test_pass "repo-automation-install help succeeds"
  else
    test_fail "repo-automation-install help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --help > "$ci_log_dump_help"
  ) && grep -q 'Usage: repo-automation/bin/ci-log-dump' "$ci_log_dump_help"; then
    test_pass "ci-log-dump help succeeds"
  else
    test_fail "ci-log-dump help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    mkdir -p docs || return 1
    printf 'docs only change\n' > docs/plan-doc.md || return 1
    repo-automation/bin/add-doc-pr --plan --json > "$add_doc_pr_json" 2> "$add_doc_pr_stderr"
  ) && python -m json.tool "$add_doc_pr_json" >/dev/null; then
    if smoke_json_assert "$add_doc_pr_json" '"docs/plan-doc.md" in data.get("changed_files", []) and len(data.get("blocked_files", [])) == 0'; then
      test_pass "add-doc-pr docs-only plan/json succeeds"
    else
      if [ -s "$add_doc_pr_json" ]; then
        add_doc_pr_failure_details="$(python -c 'import json, pathlib, sys; data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")); print(" (changed_files=" + json.dumps(data.get("changed_files", [])) + "; blocked_files=" + json.dumps(data.get("blocked_files", [])) + ")")' "$add_doc_pr_json")"
      elif [ -s "$add_doc_pr_stderr" ]; then
        add_doc_pr_failure_details=" (stderr=$(tr '\n' ' ' < "$add_doc_pr_stderr"))"
      fi
      test_fail "add-doc-pr docs-only plan/json succeeds${add_doc_pr_failure_details}"
      status=1
    fi
  else
    if [ -s "$add_doc_pr_json" ]; then
      add_doc_pr_failure_details="$(python -c 'import json, pathlib, sys; data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")); print(" (changed_files=" + json.dumps(data.get("changed_files", [])) + "; blocked_files=" + json.dumps(data.get("blocked_files", [])) + ")")' "$add_doc_pr_json")"
    elif [ -s "$add_doc_pr_stderr" ]; then
      add_doc_pr_failure_details=" (stderr=$(tr '\n' ' ' < "$add_doc_pr_stderr"))"
    fi
    test_fail "add-doc-pr docs-only plan/json succeeds${add_doc_pr_failure_details}"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f docs/plan-doc.md || return 1
  ); then
    :
  fi

  rm -f "$add_doc_pr_json" "$add_doc_pr_stderr" "$repo_doctor_help" "$ci_log_dump_help" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_add_doc_pr_blocked_file() {
  local status=0
  local add_doc_pr_block_json="$smoke_test_base/add-doc-pr-blocked-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    printf '#!/usr/bin/env bash\n' > repo-automation/bin/blocked-change.sh || return 1
    repo-automation/bin/add-doc-pr --plan --json > "$add_doc_pr_block_json"
    return 1
  ); then
    test_fail "add-doc-pr blocks repo-automation/bin/ changes in plan mode"
    status=1
  else
    if python -m json.tool "$add_doc_pr_block_json" >/dev/null && \
      smoke_json_assert "$add_doc_pr_block_json" '"repo-automation/bin/blocked-change.sh" in data.get("blocked_files", [])'; then
      test_pass "add-doc-pr blocks repo-automation/bin/ changes in plan mode"
    else
      test_fail "add-doc-pr blocks repo-automation/bin/ changes in plan mode"
      status=1
    fi
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f repo-automation/bin/blocked-change.sh || return 1
  ); then
    :
  fi

  rm -f "$add_doc_pr_block_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_pr_create_prepare_branch() {
  local branch_name="$1"
  local file_name="$2"
  local file_body="$3"

  cd "$smoke_test_dir" || return 1
  git checkout main >/dev/null 2>&1 || return 1
  git branch -D "$branch_name" >/dev/null 2>&1 || true
  git switch -c "$branch_name" >/dev/null 2>&1 || return 1
  printf '%s\n' "$file_body" > "$file_name" || return 1
  git add "$file_name" || return 1
  git commit -m "test: $branch_name" >/dev/null 2>&1 || return 1
}

smoke_check_pr_create_body_file() {
  local status=0
  local branch_name="feature/pr-create-body-file"
  local helper_json="$smoke_test_base/pr-create-body-file.json"
  local helper_log="$smoke_test_base/pr-create-body-file.log"
  local helper_body="$smoke_test_base/pr-create-body-file-body.md"
  local helper_body_copy="$smoke_test_base/pr-create-body-file-body-copy.md"
  local gh_stub_dir="$smoke_test_base/gh-pr-create-stub"
  local body_text="Mixed PR body from file"

  smoke_pr_create_prepare_branch "$branch_name" repo-automation/tests/pr-create-body-file.txt "body file fixture" || return 1
  printf '%s\n' "$body_text" > "$helper_body" || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$helper_log" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$helper_body_copy" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/321' \
    GH_STUB_PR_VIEW_NUMBER=321 \
    repo-automation/bin/pr-create --json --branch "$branch_name" --base main --title "Mixed change body file" --body-file "$helper_body" > "$helper_json"
  ) && python -m json.tool "$helper_json" >/dev/null && \
    smoke_json_assert "$helper_json" 'data.get("action_taken") == "created-pr" and data.get("pr_number") == "321" and data.get("pr_url") == "https://github.com/i-schuyler/repo-automation-template/pull/321" and data.get("branch") == "feature/pr-create-body-file" and data.get("base_branch") == "main"'; then
    if grep -Fq 'gh pr create title=Mixed change body file base=main head=feature/pr-create-body-file body_file=' "$helper_log" && cmp -s "$helper_body" "$helper_body_copy"; then
      test_pass "pr-create body-file PR creation succeeds"
    else
      test_fail "pr-create body-file PR creation succeeds"
      status=1
    fi
  else
    test_fail "pr-create body-file PR creation succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git checkout main >/dev/null 2>&1 || return 1
    git branch -D "$branch_name" >/dev/null 2>&1 || return 1
  ); then
    :
  fi

  rm -f "$helper_json" "$helper_log" "$helper_body" "$helper_body_copy" >/dev/null 2>&1 || true
  rm -rf "$gh_stub_dir" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_pr_create_body_text() {
  local status=0
  local branch_name="feature/pr-create-body-text"
  local helper_json="$smoke_test_base/pr-create-body-text.json"
  local helper_log="$smoke_test_base/pr-create-body-text.log"
  local helper_body_copy="$smoke_test_base/pr-create-body-text-body-copy.md"
  local gh_stub_dir="$smoke_test_base/gh-pr-create-stub-text"
  local body_text='Mixed PR body from inline text'

  smoke_pr_create_prepare_branch "$branch_name" repo-automation/tests/pr-create-body-text.txt "body text fixture" || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$helper_log" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$helper_body_copy" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/322' \
    GH_STUB_PR_VIEW_NUMBER=322 \
    repo-automation/bin/pr-create --json --branch "$branch_name" --base main --title "Mixed change body text" --body "$body_text" > "$helper_json"
  ) && python -m json.tool "$helper_json" >/dev/null && \
    smoke_json_assert "$helper_json" 'data.get("action_taken") == "created-pr" and data.get("pr_number") == "322" and data.get("pr_url") == "https://github.com/i-schuyler/repo-automation-template/pull/322" and data.get("branch") == "feature/pr-create-body-text" and data.get("base_branch") == "main"'; then
    if grep -Fq 'gh pr create title=Mixed change body text base=main head=feature/pr-create-body-text body_file=' "$helper_log" && printf '%s\n' "$body_text" | cmp -s - "$helper_body_copy"; then
      test_pass "pr-create body-text PR creation succeeds"
    else
      test_fail "pr-create body-text PR creation succeeds"
      status=1
    fi
  else
    test_fail "pr-create body-text PR creation succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git checkout main >/dev/null 2>&1 || return 1
    git branch -D "$branch_name" >/dev/null 2>&1 || return 1
  ); then
    :
  fi

  rm -f "$helper_json" "$helper_log" "$helper_body_copy" >/dev/null 2>&1 || true
  rm -rf "$gh_stub_dir" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_report_upstream_preview() {
  local status=0
  local report_bug_json="$smoke_test_base/report-upstream-bug-$$.json"
  local report_feature_json="$smoke_test_base/report-upstream-feature-$$.json"
  local report_preview_bug="$smoke_test_base/report-upstream-bug-preview-$$.md"
  local report_preview_feature="$smoke_test_base/report-upstream-feature-preview-$$.md"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream \
      --type bug \
      --title "Bug smoke" \
      --command "repo-automation/bin/example --flag" \
      --expected "works" \
      --actual "fails" \
      --dry-run \
      --json \
      --preview-file "$report_preview_bug" > "$report_bug_json"
  ) && python -m json.tool "$report_bug_json" >/dev/null && [ -f "$report_preview_bug" ]; then
    test_pass "report-upstream bug dry-run/json preview succeeds"
  else
    test_fail "report-upstream bug dry-run/json preview succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream \
      --type feature \
      --title "Feature smoke" \
      --use-case "repeat docs churn" \
      --proposed "better helper" \
      --why-upstream "shared contract" \
      --dry-run \
      --json \
      --preview-file "$report_preview_feature" > "$report_feature_json"
  ) && python -m json.tool "$report_feature_json" >/dev/null && [ -f "$report_preview_feature" ]; then
    test_pass "report-upstream feature dry-run/json preview succeeds"
  else
    test_fail "report-upstream feature dry-run/json preview succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --type bug --dry-run >/dev/null 2>&1
  ); then
    test_fail "report-upstream missing title fails safely"
    status=1
  else
    test_pass "report-upstream missing title fails safely"
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --type wrong --title "Invalid type" --dry-run >/dev/null 2>&1
  ); then
    test_fail "report-upstream invalid type fails safely"
    status=1
  else
    test_pass "report-upstream invalid type fails safely"
  fi

  rm -f "$report_bug_json" "$report_feature_json" "$report_preview_bug" "$report_preview_feature" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_report_upstream_secret_scan() {
  local status=0
  local report_secret_json="$smoke_test_base/report-upstream-secret-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    printf 'token=supersecret\n' > logs-secret.txt || return 1
    repo-automation/bin/repo-automation-report-upstream \
      --type bug \
      --title "Secret scan smoke" \
      --logs-file logs-secret.txt \
      --dry-run \
      --json > "$report_secret_json"
    return 1
  ); then
    test_fail "report-upstream secret scan blocks likely secret logs"
    status=1
  else
    if python -m json.tool "$report_secret_json" >/dev/null && \
      smoke_json_assert "$report_secret_json" 'data.get("redaction_scan") == "blocked"'; then
      test_pass "report-upstream secret scan blocks likely secret logs"
    else
      test_fail "report-upstream secret scan blocks likely secret logs"
      status=1
    fi
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f logs-secret.txt || return 1
  ); then
    :
  fi

  rm -f "$report_secret_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_run_tests_contract() {
  local status=0
  local run_tests_default_out="$smoke_test_base/run-tests-default-$$.txt"
  local run_tests_explain_out="$smoke_test_base/run-tests-explain-$$.txt"
  local run_tests_json="$smoke_test_base/run-tests-warn-$$.json"
  local run_tests_log_file="$smoke_test_base/run-tests-log-$$.log"
  local run_tests_no_log_file="$smoke_test_base/run-tests-no-log-$$.log"
  local run_tests_no_log_out="$smoke_test_base/run-tests-no-log-$$.txt"

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --timeout=200 > "$run_tests_default_out"
  ) && ! grep -Eq '^PASS:' "$run_tests_default_out" && grep -Eq '^RESULT: pass=' "$run_tests_default_out"; then
    test_pass "run-tests default output is compact"
  else
    test_fail "run-tests default output is compact"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --explain > "$run_tests_explain_out"
  ) && grep -Eq '^PASS: repo-automation/tests/docs-check.sh - passed' "$run_tests_explain_out"; then
    test_pass "run-tests explain output shows details"
  else
    test_fail "run-tests explain output shows details"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --json --json-level=warn > "$run_tests_json"
  ) && python -m json.tool "$run_tests_json" >/dev/null && \
    smoke_json_assert "$run_tests_json" 'data.get("script") == "run-tests" and data.get("json_level") == "warn" and data.get("overall_status") in ("pass", "warn", "fail")'; then
    test_pass "run-tests json warn is parseable"
  else
    test_fail "run-tests json warn is parseable"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --timeout=200 --log-file="$run_tests_log_file" >/dev/null
  ) && [ -f "$run_tests_log_file" ]; then
    test_pass "run-tests log-file creates a log"
  else
    test_fail "run-tests log-file creates a log"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --timeout=200 --log-file="$run_tests_no_log_file" --no-log > "$run_tests_no_log_out"
  ) && [ ! -e "$run_tests_no_log_file" ] && ! grep -Eq '^Log:' "$run_tests_no_log_out"; then
    test_pass "run-tests no-log does not create a log"
  else
    test_fail "run-tests no-log does not create a log"
    status=1
  fi

  local run_tests_subset_repo=""
  local run_tests_subset_smoke_json="$smoke_test_base/run-tests-subset-smoke-$$.json"
  local run_tests_subset_docs_json="$smoke_test_base/run-tests-subset-docs-$$.json"
  local run_tests_subset_version_json="$smoke_test_base/run-tests-subset-version-$$.json"
  local run_tests_subset_changed_docs_json="$smoke_test_base/run-tests-subset-changed-docs-$$.json"
  local run_tests_subset_changed_smoke_json="$smoke_test_base/run-tests-subset-changed-smoke-$$.json"
  local run_tests_subset_changed_bin_json="$smoke_test_base/run-tests-subset-changed-bin-$$.json"

  run_tests_subset_repo="$(smoke_setup_subset_repo)" || {
    test_fail "run-tests subset fixture creates a repo"
    status=1
  }

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    repo-automation/bin/run-tests --smoke --json --json-level=all > "$run_tests_subset_smoke_json" || true
  ) && python -m json.tool "$run_tests_subset_smoke_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_smoke_json" 'data.get("script") == "run-tests" and len(data.get("checks", [])) == 1 and data.get("checks", [])[0].get("name") == "repo-automation/tests/smoke.sh"'; then
    test_pass "run-tests smoke subset runs only smoke"
  else
    test_fail "run-tests smoke subset runs only smoke"
    status=1
  fi

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    repo-automation/bin/run-tests --docs --json --json-level=all > "$run_tests_subset_docs_json" || true
  ) && python -m json.tool "$run_tests_subset_docs_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_docs_json" 'data.get("script") == "run-tests" and len(data.get("checks", [])) == 1 and data.get("checks", [])[0].get("name") == "repo-automation/tests/docs-check.sh"'; then
    test_pass "run-tests docs subset runs only docs-check"
  else
    test_fail "run-tests docs subset runs only docs-check"
    status=1
  fi

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    repo-automation/bin/run-tests --version --json --json-level=all > "$run_tests_subset_version_json" || true
  ) && python -m json.tool "$run_tests_subset_version_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_version_json" 'data.get("script") == "run-tests" and len(data.get("checks", [])) == 1 and data.get("checks", [])[0].get("name") == "repo-automation/tests/version-consistency.sh"'; then
    test_pass "run-tests version subset runs only version-consistency"
  else
    test_fail "run-tests version subset runs only version-consistency"
    status=1
  fi

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    printf '\nsubset docs change\n' >> repo-automation/docs/testing.md || return 1
    repo-automation/bin/run-tests --changed --json --json-level=all > "$run_tests_subset_changed_docs_json" || true
  ) && python -m json.tool "$run_tests_subset_changed_docs_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_changed_docs_json" 'data.get("selected_subsets") in (["docs"], ["docs", "version"]) and any(check.get("name") == "repo-automation/tests/docs-check.sh" for check in data.get("checks", [])) and not any(check.get("name") == "repo-automation/tests/smoke.sh" for check in data.get("checks", []))'; then
    test_pass "run-tests changed subset follows docs-only changes"
  else
    test_fail "run-tests changed subset follows docs-only changes"
    status=1
  fi

  local run_tests_subset_changed_smoke_repo=""
  run_tests_subset_changed_smoke_repo="$(smoke_setup_subset_repo)" || {
    test_fail "run-tests changed subset follows docs plus smoke changes"
    status=1
  }

  if [ -n "$run_tests_subset_changed_smoke_repo" ] && (
    cd "$run_tests_subset_changed_smoke_repo" || return 1
    printf '\nsubset docs plus smoke change\n' >> repo-automation/docs/testing.md || return 1
    printf '\n# subset smoke change\n' >> repo-automation/tests/smoke.sh || return 1
    repo-automation/bin/run-tests --changed --json --json-level=all > "$run_tests_subset_changed_smoke_json" || true
  ) && python -m json.tool "$run_tests_subset_changed_smoke_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_changed_smoke_json" 'len(data.get("selected_subsets", [])) == 2 and "docs" in data.get("selected_subsets", []) and "smoke" in data.get("selected_subsets", []) and any(check.get("name") == "repo-automation/tests/docs-check.sh" for check in data.get("checks", [])) and any(check.get("name") == "repo-automation/tests/smoke.sh" for check in data.get("checks", []))'; then
    test_pass "run-tests changed subset follows docs plus smoke changes"
  else
    test_fail "run-tests changed subset follows docs plus smoke changes"
    status=1
  fi

  local run_tests_subset_changed_bin_repo=""
  run_tests_subset_changed_bin_repo="$(smoke_setup_subset_repo)" || {
    test_fail "run-tests changed subset follows docs plus bin changes"
    status=1
  }

  if [ -n "$run_tests_subset_changed_bin_repo" ] && (
    cd "$run_tests_subset_changed_bin_repo" || return 1
    printf '\nsubset docs plus bin change\n' >> repo-automation/docs/testing.md || return 1
    printf '\n# subset bin change\n' >> repo-automation/bin/failure-log || return 1
    repo-automation/bin/run-tests --changed --json --json-level=all > "$run_tests_subset_changed_bin_json" || true
  ) && python -m json.tool "$run_tests_subset_changed_bin_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_changed_bin_json" 'len(data.get("selected_subsets", [])) == 2 and "docs" in data.get("selected_subsets", []) and "smoke" in data.get("selected_subsets", []) and any(check.get("name") == "repo-automation/tests/docs-check.sh" for check in data.get("checks", [])) and any(check.get("name") == "repo-automation/tests/smoke.sh" for check in data.get("checks", []))'; then
    test_pass "run-tests changed subset follows docs plus bin changes"
  else
    test_fail "run-tests changed subset follows docs plus bin changes"
    status=1
  fi

  rm -f "$run_tests_default_out" "$run_tests_explain_out" "$run_tests_json" "$run_tests_log_file" "$run_tests_no_log_file" "$run_tests_no_log_out" "$run_tests_subset_smoke_json" "$run_tests_subset_docs_json" "$run_tests_subset_version_json" "$run_tests_subset_changed_docs_json" "$run_tests_subset_changed_smoke_json" "$run_tests_subset_changed_bin_json" >/dev/null 2>&1 || true
  return "$status"
}



smoke_check_failure_log_contract() {
  local status=0
  local temp_root="$smoke_test_base/failure-log-root"
  local log_root="$temp_root/repo-automation-template"
  local latest_human="$smoke_test_base/failure-log-latest-$$.txt"
  local kind_json="$smoke_test_base/failure-log-kind-$$.json"

  mkdir -p "$log_root" || return 1
  cat > "$log_root/run-tests-20260512-110000.log" <<'EOF'
INFO: run-tests old
FAIL: old run-tests failure
EOF
  cat > "$log_root/run-tests-20260512-120000.log" <<'EOF'
INFO: run-tests latest
FAIL: latest run-tests failure
detail one
detail two
EOF
  cat > "$log_root/repo-doctor-20260512-130000.log" <<'EOF'
INFO: repo-doctor latest
FAIL: latest repo-doctor failure
detail one
detail two
detail three
EOF
  touch -t 202605121100.00 "$log_root/run-tests-20260512-110000.log" || return 1
  touch -t 202605121200.00 "$log_root/run-tests-20260512-120000.log" || return 1
  touch -t 202605121300.00 "$log_root/repo-doctor-20260512-130000.log" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --latest > "$latest_human"
  ) && grep -Eq "^Latest failure log: .*/repo-doctor-20260512-130000\.log$" "$latest_human" && grep -Eq '^FAIL: latest repo-doctor failure$' "$latest_human"; then
    test_pass "failure-log latest human output selects newest matching log"
  else
    test_fail "failure-log latest human output selects newest matching log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --kind=run-tests --lines=2 --machine-json > "$kind_json"
  ) && python -m json.tool "$kind_json" >/dev/null &&     smoke_json_assert "$kind_json" 'data.get("script") == "failure-log" and data.get("kind") == "run-tests" and data.get("lines") == 2 and data.get("log_file", "").endswith("run-tests-20260512-120000.log") and len(data.get("excerpt", [])) == 2 and "FAIL: latest run-tests failure" in data.get("excerpt", [])'; then
    test_pass "failure-log kind filter, line limits, and machine-json work"
  else
    test_fail "failure-log kind filter, line limits, and machine-json work"
    status=1
  fi

  rm -f "$latest_human" "$kind_json" >/dev/null 2>&1 || true
  rm -f "$log_root"/run-tests-20260512-110000.log "$log_root"/run-tests-20260512-120000.log "$log_root"/repo-doctor-20260512-130000.log >/dev/null 2>&1 || true
  rmdir "$log_root" "$temp_root" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_touched_files_and_ci_contract() {
  local status=0
  local touched_worktree_json="$smoke_test_base/touched-files-worktree-$$.json"
  local touched_range_json="$smoke_test_base/touched-files-range-$$.json"
  local ci_status_pr_json="$smoke_test_base/ci-status-pr-$$.json"
  local ci_status_branch_json="$smoke_test_base/ci-status-branch-$$.json"
  local ci_status_failure_stderr="$smoke_test_base/ci-status-failure-$$.txt"
  local ci_watch_timeout_stderr="$smoke_test_base/ci-watch-timeout-$$.txt"
  local gh_stub_dir="$smoke_test_base/gh-stub"
  local touched_range_repo=""

  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    printf '\nsmoke touched-files\n' >> README.md || return 1
    : > scratch.txt || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/touched-files --machine-json > "$touched_worktree_json"
  ) && python -m json.tool "$touched_worktree_json" >/dev/null && \
    smoke_json_assert "$touched_worktree_json" 'data.get("mode") == "working-tree" and "README.md" in data.get("working_tree_tracked_files", []) and "scratch.txt" in data.get("untracked_files", [])'; then
    test_pass "touched-files working-tree fallback is parseable"
  else
    test_fail "touched-files working-tree fallback is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f scratch.txt >/dev/null 2>&1 || true
    git checkout -- README.md >/dev/null 2>&1 || true
  ); then
    :
  fi

  touched_range_repo="$(smoke_setup_subset_repo)" || {
    test_fail "touched-files commit-range fixture creates a repo"
    status=1
  }

  if [ -n "$touched_range_repo" ] && (
    cd "$touched_range_repo" || return 1
    git checkout -b feature/touched-files-range >/dev/null 2>&1 || return 1
    printf '
range touch
' >> repo-automation/docs/testing.md || return 1
    git add repo-automation/docs/testing.md || return 1
    git commit -m "range touch" >/dev/null || return 1
    repo-automation/bin/touched-files --machine-json > "$touched_range_json"
  ) && python -m json.tool "$touched_range_json" >/dev/null &&     smoke_json_assert "$touched_range_json" 'data.get("mode") == "commit-range" and "repo-automation/docs/testing.md" in data.get("commit_range_files", [])'; then
    test_pass "touched-files commit-range output is parseable"
  else
    test_fail "touched-files commit-range output is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr=123 --machine-json > "$ci_status_pr_json"
  ) && python -m json.tool "$ci_status_pr_json" >/dev/null && \
    smoke_json_assert "$ci_status_pr_json" 'data.get("mode") == "pr" and data.get("overall_status") == "pending" and len(data.get("checks", [])) == 1'; then
    test_pass "ci-status pr machine-json is parseable"
  else
    test_fail "ci-status pr machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_LIST_JSON='[]' GH_STUB_RUN_LIST_JSON='[{"number":99,"name":"ci","status":"completed","conclusion":"success"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --branch=feature/demo --machine-json > "$ci_status_branch_json"
  ) && python -m json.tool "$ci_status_branch_json" >/dev/null && \
    smoke_json_assert "$ci_status_branch_json" 'data.get("mode") == "branch" and data.get("overall_status") == "pass" and data.get("latest_run", {}).get("number") == 99'; then
    test_pass "ci-status branch machine-json is parseable"
  else
    test_fail "ci-status branch machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_LIST_JSON='[]' GH_STUB_RUN_LIST_JSON='[]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --branch=feature/missing > /dev/null 2> "$ci_status_failure_stderr"
  ); then
    test_fail "ci-status missing branch fails cleanly"
    status=1
  elif grep -Eq 'no pull request or workflow run found' "$ci_status_failure_stderr"; then
    test_pass "ci-status missing branch fails cleanly"
  else
    test_fail "ci-status missing branch fails cleanly"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 > /dev/null 2> "$ci_watch_timeout_stderr"
  ); then
    test_fail "ci-watch timeout fails cleanly"
    status=1
  elif grep -Eq 'timed out after 1s while waiting for CI' "$ci_watch_timeout_stderr"; then
    test_pass "ci-watch timeout fails cleanly"
  else
    test_fail "ci-watch timeout fails cleanly"
    status=1
  fi

  rm -f "$touched_worktree_json" "$touched_range_json" "$ci_status_pr_json" "$ci_status_branch_json" "$ci_status_failure_stderr" "$ci_watch_timeout_stderr" >/dev/null 2>&1 || true
  return "$status"
}


smoke_check_ci_log_dump_contract() {
  local status=0
  local gh_stub_dir="$smoke_test_base/gh-stub-ci-log-dump"
  local ci_log_out_dir="$smoke_test_base/ci-log-dump-out"
  local ci_log_json="$smoke_test_base/ci-log-dump-$$.json"
  local ci_log_human="$smoke_test_base/ci-log-dump-$$.txt"

  smoke_write_gh_stub "$gh_stub_dir" || return 1
  mkdir -p "$ci_log_out_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[
      {"databaseId":111,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"push","headBranch":"branch/old","status":"completed","workflowName":"ci"},
      {"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"schedule","headBranch":"branch/new","status":"completed","workflowName":"ci"},
      {"databaseId":333,"conclusion":"success","createdAt":"2026-05-12T14:00:00Z","event":"push","headBranch":"branch/other","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='line one
line two
line three
FAIL: ci run failed
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --tail=2 --out-dir="$ci_log_out_dir" > "$ci_log_human"
  ) && grep -Eq '^Run id: 222$' "$ci_log_human" && grep -Eq "^Saved log path: $ci_log_out_dir/actions_run_222_[0-9]{8}-[0-9]{6}\.log$" "$ci_log_human" && grep -Eq '^tail one$' "$ci_log_human" && grep -Eq '^tail two$' "$ci_log_human" && [ -n "$(find "$ci_log_out_dir" -maxdepth 1 -type f -name 'actions_run_222_*.log' -print -quit)" ]; then
    test_pass "ci-log-dump latest-failed selects the newest failed run and saves the log"
  else
    test_fail "ci-log-dump latest-failed selects the newest failed run and saves the log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[
      {"databaseId":111,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"push","headBranch":"branch/old","status":"completed","workflowName":"ci"},
      {"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"schedule","headBranch":"branch/new","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='line one
line two
line three
FAIL: ci run failed
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --tail=2 --out-dir="$ci_log_out_dir" --machine-json > "$ci_log_json"
  ) && python -m json.tool "$ci_log_json" >/dev/null &&     smoke_json_assert "$ci_log_json" 'data.get("script") == "ci-log-dump" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("run_id") == "222" and "actions_run_222_" in data.get("log_path", "") and data.get("log_path", "").endswith(".log") and data.get("file_size_bytes", 0) > 0 and data.get("tail_excerpt", []) == ["tail one", "tail two"]'; then
    test_pass "ci-log-dump machine-json reports the saved path and tail excerpt"
  else
    test_fail "ci-log-dump machine-json reports the saved path and tail excerpt"
    status=1
  fi

  local ci_log_empty_marker="$smoke_test_base/ci-log-dump-run-view-called-$$.marker"
  local ci_log_empty_status=0
  (
    cd "$smoke_test_dir" || exit 1
    GH_STUB_RUN_LIST_JSON='[]' GH_STUB_RUN_VIEW_CALLED_FILE="$ci_log_empty_marker" PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --out-dir="$ci_log_out_dir" > "$ci_log_human" 2>&1
  ) || ci_log_empty_status=$?
  if [ "$ci_log_empty_status" -ne 0 ] && grep -Eq '^STOP: no failed run found for repository i-schuyler/repo-automation-template$' "$ci_log_human" && [ ! -e "$ci_log_empty_marker" ]; then
    test_pass "ci-log-dump latest-failed stops when no failed runs exist"
  else
    test_fail "ci-log-dump latest-failed stops when no failed runs exist"
    status=1
  fi

  rm -f "$ci_log_human" "$ci_log_json" "$ci_log_empty_marker" >/dev/null 2>&1 || true
  find "$ci_log_out_dir" -maxdepth 1 -type f -name 'actions_run_222_*.log' -delete >/dev/null 2>&1 || true
  rmdir "$ci_log_out_dir" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_repo_doctor_contract() {
  local status=0
  local doctor_default_out="$smoke_test_base/repo-doctor-quick-default-$$.txt"
  local doctor_explain_out="$smoke_test_base/repo-doctor-quick-explain-$$.txt"
  local doctor_json_warn="$smoke_test_base/repo-doctor-quick-warn-$$.json"
  local doctor_log_file="$smoke_test_base/repo-doctor-log-$$.log"
  local doctor_no_log_file="$smoke_test_base/repo-doctor-no-log-$$.log"
  local doctor_no_log_out="$smoke_test_base/repo-doctor-no-log-$$.txt"
  local doctor_json="$smoke_test_base/repo-doctor-quick-$$.json"
  local doctor_config_out="$smoke_test_base/repo-doctor-config-$$.txt"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --quick --timeout 200 > "$doctor_default_out"
  ) && ! grep -Eq '^PASS:' "$doctor_default_out" && grep -Eq '^RESULT: pass=' "$doctor_default_out" && grep -Eq '^WARN:$' "$doctor_default_out" && grep -Eq '^- run-tests$' "$doctor_default_out" && grep -Eq '^Next: repo-automation/bin/repo-doctor --explain$' "$doctor_default_out"; then
    test_pass "repo-doctor quick default output is compact"
  else
    test_fail "repo-doctor quick default output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --quick --explain > "$doctor_explain_out"
  ) && grep -Eq '^PASS: git-branch - current branch:' "$doctor_explain_out"; then
    test_pass "repo-doctor quick explain output shows details"
  else
    test_fail "repo-doctor quick explain output shows details"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --json --quick --json-level=warn > "$doctor_json_warn"
  ) && python -m json.tool "$doctor_json_warn" >/dev/null && \
    smoke_json_assert "$doctor_json_warn" 'data.get("mode") == "quick" and data.get("json_level") == "warn" and any(check.get("status") == "warn" for check in data.get("checks", []))'; then
    test_pass "repo-doctor json quick warn is parseable"
  else
    test_fail "repo-doctor json quick warn is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --quick --timeout=200 --log-file="$doctor_log_file" >/dev/null
  ) && [ -f "$doctor_log_file" ]; then
    test_pass "repo-doctor log-file creates a log"
  else
    test_fail "repo-doctor log-file creates a log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --quick --timeout=200 --log-file="$doctor_no_log_file" --no-log > "$doctor_no_log_out"
  ) && [ ! -e "$doctor_no_log_file" ] && ! grep -Eq '^Log:' "$doctor_no_log_out"; then
    test_pass "repo-doctor no-log does not create a log"
  else
    test_fail "repo-doctor no-log does not create a log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check=config --timeout=200 --no-run-tests > "$doctor_config_out"
  ); then
    test_pass "repo-doctor config check succeeds"
  else
    test_fail "repo-doctor config check succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --json --quick > "$doctor_json"
  ) && python -m json.tool "$doctor_json" >/dev/null; then
    test_pass "repo-doctor json quick is parseable"
  else
    test_fail "repo-doctor json quick is parseable"
    status=1
  fi

  rm -f "$doctor_default_out" "$doctor_explain_out" "$doctor_json_warn" "$doctor_log_file" "$doctor_no_log_file" "$doctor_no_log_out" "$doctor_json" "$doctor_config_out" >/dev/null 2>&1 || true
  return "$status"
}


smoke_check_status_packet_contract() {
  local status=0
  local temp_root="$smoke_test_base/status-packet-root"
  local log_root="$temp_root/repo-automation-template"
  local status_human="$smoke_test_base/status-packet-human-$$.txt"
  local status_json="$smoke_test_base/status-packet-json-$$.json"
  local gh_stub_dir="$smoke_test_base/gh-stub-status-packet"

  smoke_write_gh_stub "$gh_stub_dir" || return 1
  mkdir -p "$log_root" || return 1
  cat > "$log_root/run-tests-20260512-140000.log" <<'EOF'
INFO: run-tests recent
EOF
  cat > "$log_root/repo-doctor-20260512-150000.log" <<'EOF'
INFO: repo-doctor recent
EOF
  touch -t 202605121400.00 "$log_root/run-tests-20260512-140000.log" || return 1
  touch -t 202605121500.00 "$log_root/repo-doctor-20260512-150000.log" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    printf '
status packet smoke
' >> README.md || return 1
    printf 'scratch
' > status-packet-scratch.txt || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet > "$status_human"
  ) && grep -Eq '^Branch: main$' "$status_human" && grep -Eq '^Git status --short:$' "$status_human" && grep -Eq '^ M README.md$' "$status_human" && grep -Eq '^\?\? status-packet-scratch\.txt$' "$status_human" && grep -Eq '^Tracked changed files:$' "$status_human" && grep -Eq '^- README.md$' "$status_human" && grep -Eq '^Untracked files:$' "$status_human" && grep -Eq '^- status-packet-scratch\.txt$' "$status_human" && grep -Eq '^Recent logs:$' "$status_human" && grep -Eq "^- run-tests: $log_root/run-tests-20260512-140000.log$" "$status_human" && grep -Eq "^- repo-doctor: $log_root/repo-doctor-20260512-150000.log$" "$status_human"; then
    test_pass "status-packet human output reports compact repo state"
  else
    test_fail "status-packet human output reports compact repo state"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --machine-json > "$status_json"
  ) && python -m json.tool "$status_json" >/dev/null &&     smoke_json_assert "$status_json" 'data.get("script") == "status-packet" and data.get("machine_json") is True and data.get("branch") == "main" and "README.md" in data.get("changed_tracked_files", []) and "status-packet-scratch.txt" in data.get("untracked_files", []) and data.get("recent_logs", {}).get("run_tests", "").endswith("run-tests-20260512-140000.log") and data.get("recent_logs", {}).get("repo_doctor", "").endswith("repo-doctor-20260512-150000.log") and data.get("overall_status") == "pass"'; then
    test_pass "status-packet machine-json reports compact repo state"
  else
    test_fail "status-packet machine-json reports compact repo state"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -- README.md >/dev/null 2>&1 || return 1
    rm -f status-packet-scratch.txt >/dev/null 2>&1 || return 1
  ); then
    :
  fi

  rm -f "$status_human" "$status_json" >/dev/null 2>&1 || true
  rm -f "$log_root"/run-tests-20260512-140000.log "$log_root"/repo-doctor-20260512-150000.log >/dev/null 2>&1 || true
  rmdir "$log_root" "$temp_root" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_post_codex_packet_contract() {
  local status=0
  local output_root=""
  local output_log=""
  local packet_dir=""
  local packet_zip=""
  local summary_file=""
  local skipped_file=""
  local index_file=""

  smoke_setup_temp_repo || return 1
  output_root="$smoke_test_base/post-codex-output"
  output_log="$smoke_test_base/post-codex-output.log"

  cd "$smoke_test_dir" || return 1
  printf '\npacket helper staged line\n' >> docs/testing.md || return 1
  git add docs/testing.md || return 1
  printf '\npacket helper unstaged line\n' >> README.md || return 1
  mkdir -p packet-safe-nested || return 1
  printf 'nested safe packet content\n' > packet-safe-nested/deep.txt || return 1
  printf 'sensitive env packet content\n' > .env || return 1
  mkdir -p secrets || return 1
  printf 'token packet content\n' > secrets/token.txt || return 1
  printf 'credential packet content\n' > credentials-note.txt || return 1
  python3 - <<'PY' > packet-oversized.bin
import sys
sys.stdout.write('x' * 262145)
PY

  if REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/post-codex-packet --label review --keep-dir --max-bytes 262144 > "$output_log"; then
    :
  else
    test_fail "post-codex-packet helper runs successfully"
    status=1
  fi

  packet_dir="$(sed -n 's/^INFO: packet dir: //p' "$output_log" | tail -n 1)"
  packet_zip="$(sed -n 's/^INFO: packet zip: //p' "$output_log" | tail -n 1)"
  summary_file="$packet_dir/summary.txt"
  skipped_file="$packet_dir/untracked/skipped.txt"
  index_file="$output_root/post-codex/index.tsv"

  if [ -d "$packet_dir" ] && [ -f "$packet_zip" ] && [ -f "$summary_file" ] && [ -f "$index_file" ]; then
    test_pass "post-codex-packet helper creates packet artifacts"
  else
    test_fail "post-codex-packet helper creates packet artifacts"
    status=1
  fi

  if grep -Eq '^Branch: main$' "$summary_file" && grep -Eq '^HEAD: [0-9a-f]{40}$' "$summary_file" && grep -Eq '^Tracked unstaged files: 1$' "$summary_file" && grep -Eq '^Staged files: 1$' "$summary_file" && grep -Eq '^Untracked files: 5$' "$summary_file" && grep -Eq '^Copied untracked files: 1$' "$summary_file" && grep -Eq '^Skipped untracked files: 4$' "$summary_file" && grep -Eq '^Max untracked copy bytes: 262144$' "$summary_file"; then
    test_pass "post-codex-packet summary reports packet metadata"
  else
    test_fail "post-codex-packet summary reports packet metadata"
    status=1
  fi

  if grep -Eq '^README.md$' "$packet_dir/tracked-unstaged/name-list.txt" && grep -Eq '^docs/testing.md$' "$packet_dir/staged/name-list.txt" && grep -Eq '^packet-safe-nested/deep.txt$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^\.env\t' "$skipped_file" && grep -Eq '^secrets/token.txt\t' "$skipped_file" && grep -Eq '^credentials-note.txt\t' "$skipped_file" && grep -Eq '^packet-oversized.bin\t' "$skipped_file" && [ -f "$packet_dir/untracked/copied/packet-safe-nested/deep.txt" ]; then
    test_pass "post-codex-packet packet contents include copied and skipped untracked files"
  else
    test_fail "post-codex-packet packet contents include copied and skipped untracked files"
    status=1
  fi

  if python3 - "$packet_zip" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
assert 'summary.txt' in names
assert 'tracked-unstaged/name-list.txt' in names
assert 'staged/name-list.txt' in names
assert 'untracked/copied/packet-safe-nested/deep.txt' in names
assert 'untracked/skipped.txt' in names
assert 'untracked/copied/.env' not in names
PY
  then
    test_pass "post-codex-packet zip archive contains packet files"
  else
    test_fail "post-codex-packet zip archive contains packet files"
    status=1
  fi

  if grep -Eq '^review$' "$index_file" && grep -Eq '^post-codex-' "$index_file"; then
    test_pass "post-codex-packet index records the packet"
  else
    test_fail "post-codex-packet index records the packet"
    status=1
  fi

  return "$status"
}


smoke_check_repo_zip_contract() {
  local status=0
  local output_root=""
  local output_log=""
  local zip_path=""
  local packet_dir=""
  local summary_file=""
  local files_file=""
  local zip_root=""

  smoke_setup_temp_repo || return 1
  output_root="$smoke_test_dir/repo-automation-output"
  output_log="$smoke_test_base/repo-zip-output.log"

  cd "$smoke_test_dir" || return 1
  printf 'tracked base\n' > tracked.txt || return 1
  git add tracked.txt || return 1
  git commit -m "add tracked snapshot file" >/dev/null || return 1
  printf '\ntracked update\n' >> tracked.txt || return 1
  printf 'ignored.log\n' > .gitignore || return 1
  git add .gitignore || return 1
  git commit -m "add ignore rule" >/dev/null || return 1
  printf 'untracked content\n' > untracked.txt || return 1
  printf 'ignored artifact\n' > ignored.log || return 1
  printf 'git internals\n' > .git/repo-zip-sentinel || return 1
  mkdir -p post-codex ci-log-dump repo-zip repo-automation-output/repo-zip || return 1
  printf 'tracked helper file\n' > repo-automation/bin/ci-log-dump || return 1
  git add repo-automation/bin/ci-log-dump || return 1
  git commit -m "add ci-log-dump helper file" >/dev/null || return 1
  printf 'post codex artifact\n' > post-codex/payload.txt || return 1
  printf 'ci log artifact\n' > ci-log-dump/actions_run_123.log || return 1
  printf 'repo zip artifact\n' > repo-zip/staging.txt || return 1
  printf 'self output artifact\n' > repo-automation-output/repo-zip/previous.txt || return 1
  mkdir -p nested/subdir || return 1

  if (
    cd nested/subdir || exit 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/repo-zip --label review
  ) > "$output_log"; then
    :
  else
    test_fail "repo-zip helper runs successfully"
    status=1
  fi

  zip_path="$(sed -n 's/^INFO: zip path: //p' "$output_log" | tail -n 1)"
  packet_dir="$(dirname "$zip_path")"
  summary_file="$packet_dir/summary.txt"
  files_file="$packet_dir/files.txt"
  zip_root="$(basename "$smoke_test_dir")"

  if [ -d "$packet_dir" ] && [ -f "$zip_path" ] && [ -f "$summary_file" ] && [ -f "$files_file" ]; then
    test_pass "repo-zip helper creates packet artifacts"
  else
    test_fail "repo-zip helper creates packet artifacts"
    status=1
  fi

  if grep -Eq '^Repo path: ' "$summary_file" && grep -Eq '^Branch: main$' "$summary_file" && grep -Eq '^HEAD: [0-9a-f]{40}$' "$summary_file" && grep -Eq '^Zip path: ' "$summary_file" && grep -Eq '^File count: [1-9][0-9]*$' "$summary_file" && grep -Eq '^Zip size: [1-9][0-9]* bytes$' "$summary_file" && grep -Eq '^Zip modified time: ' "$summary_file"; then
    test_pass "repo-zip summary reports zip metadata"
  else
    test_fail "repo-zip summary reports zip metadata"
    status=1
  fi

  if grep -Eq '^tracked\.txt$' "$files_file" && grep -Eq '^untracked\.txt$' "$files_file" && grep -Eq '^repo-automation/bin/repo-zip$' "$files_file" && grep -Eq '^repo-automation/bin/ci-log-dump$' "$files_file" && ! grep -Eq '^ignored\.log$' "$files_file" && ! grep -Eq '(^|/)\.git(/|$)' "$files_file" && ! grep -Eq '^post-codex/' "$files_file" && ! grep -Eq '^ci-log-dump/' "$files_file" && ! grep -Eq '^repo-zip/' "$files_file" && ! grep -Eq '^repo-automation-output/' "$files_file"; then
    test_pass "repo-zip file selection includes tracked and untracked non-ignored files only"
  else
    test_fail "repo-zip file selection includes tracked and untracked non-ignored files only"
    status=1
  fi

  if python3 - "$zip_path" "$zip_root" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
zip_root = sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    tracked_name = f'{zip_root}/tracked.txt'
    untracked_name = f'{zip_root}/untracked.txt'
    helper_name = f'{zip_root}/repo-automation/bin/repo-zip'
    ci_log_dump_name = f'{zip_root}/repo-automation/bin/ci-log-dump'
    ignored_name = f'{zip_root}/ignored.log'
    assert tracked_name in names
    assert untracked_name in names
    assert helper_name in names
    assert ci_log_dump_name in names
    assert ignored_name not in names
    assert not any(name == f'{zip_root}/.git' or name.startswith(f'{zip_root}/.git/') for name in names)
    assert not any('post-codex/' in name or 'ci-log-dump/' in name or 'repo-zip/' in name or 'repo-automation-output/' in name for name in names)
    assert archive.read(tracked_name).decode('utf-8').endswith('tracked update\n')
    assert archive.read(untracked_name).decode('utf-8') == 'untracked content\n'
PY
  then
    test_pass "repo-zip archive contains tracked and untracked files"
  else
    test_fail "repo-zip archive contains tracked and untracked files"
    status=1
  fi

  return "$status"
}


smoke_check_evidence_bundle_contract() {
  local status=0
  local output_root=""
  local failure_log_root=""
  local gh_stub_dir=""
  local nested_dir=""
  local default_output_log=""
  local default_bundle_dir=""
  local default_bundle_zip=""
  local default_summary_file=""
  local default_status_file=""
  local default_touched_file=""
  local default_failure_log_file=""
  local default_bundle_root=""
  local post_output_log=""
  local post_bundle_dir=""
  local post_bundle_zip=""
  local post_summary_file=""
  local post_bundle_root=""
  local pr_output_log=""
  local pr_bundle_dir=""
  local pr_bundle_zip=""
  local pr_summary_file=""
  local pr_bundle_root=""

  smoke_setup_temp_repo || return 1
  output_root="$smoke_test_base/evidence-bundle-output"
  failure_log_root="$smoke_test_base/evidence-bundle-tmp"
  gh_stub_dir="$smoke_test_base/gh-stub-evidence-bundle"
  nested_dir="$smoke_test_dir/nested/subdir"
  default_output_log="$smoke_test_base/evidence-bundle-default.log"
  post_output_log="$smoke_test_base/evidence-bundle-post.log"
  pr_output_log="$smoke_test_base/evidence-bundle-pr.log"

  mkdir -p "$failure_log_root/repo-automation-template" "$nested_dir" || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1

  cd "$smoke_test_dir" || return 1
  printf 'tracked base\n' > tracked.txt || return 1
  git add tracked.txt || return 1
  git commit -m "add tracked bundle file" >/dev/null || return 1
  printf '\ntracked update\n' >> tracked.txt || return 1
  printf 'ignored.log\n' > .gitignore || return 1
  git add .gitignore || return 1
  git commit -m "add bundle ignore rule" >/dev/null || return 1
  printf 'untracked content\n' > untracked.txt || return 1
  printf 'ignored artifact\n' > ignored.log || return 1
  printf 'latest failure line\n' > "$failure_log_root/repo-automation-template/run-tests-20260512-120000.log" || return 1

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label review
  ) > "$default_output_log"; then
    :
  else
    test_fail "evidence-bundle helper runs successfully"
    status=1
  fi

  default_bundle_dir="$(sed -n 's/^INFO: bundle dir: //p' "$default_output_log" | tail -n 1)"
  default_bundle_zip="$(sed -n 's/^INFO: bundle zip: //p' "$default_output_log" | tail -n 1)"
  default_summary_file="$default_bundle_dir/summary.txt"
  default_status_file="$default_bundle_dir/git-status-short.txt"
  default_touched_file="$default_bundle_dir/touched-files.json"
  default_failure_log_file="$default_bundle_dir/failure-log.txt"
  default_bundle_root="$(basename "$default_bundle_dir")"

  if [ -d "$default_bundle_dir" ] && [ -f "$default_bundle_zip" ] && [ -f "$default_summary_file" ] && [ -f "$default_status_file" ] && [ -f "$default_touched_file" ] && [ -f "$default_failure_log_file" ]; then
    test_pass "evidence-bundle helper creates bundle artifacts"
  else
    test_fail "evidence-bundle helper creates bundle artifacts"
    status=1
  fi

  if grep -Fqx "Repo path: $smoke_test_dir" "$default_summary_file" && grep -Eq '^Branch: main$' "$default_summary_file" && grep -Eq '^HEAD: [0-9a-f]{40}$' "$default_summary_file" && grep -Eq '^PR number: $' "$default_summary_file" && grep -Eq '^Bundle dir: ' "$default_summary_file" && grep -Eq '^Bundle zip: ' "$default_summary_file" && grep -Eq '^Included sections: .*git-status-short.*touched-files.*failure-log' "$default_summary_file" && grep -Eq '^Skipped sections: .*ci-log-dump \(no --pr\).*post-codex-packet \(not requested\).*repo-zip \(not requested\)' "$default_summary_file"; then
    test_pass "evidence-bundle summary reports core metadata"
  else
    test_fail "evidence-bundle summary reports core metadata"
    status=1
  fi

  if grep -Eq 'tracked\.txt' "$default_status_file" && grep -Eq 'untracked\.txt' "$default_status_file"; then
    test_pass "evidence-bundle status snapshot captures tracked and untracked files"
  else
    test_fail "evidence-bundle status snapshot captures tracked and untracked files"
    status=1
  fi

  if smoke_json_assert "$default_touched_file" 'data.get("mode") == "working-tree" and "tracked.txt" in data.get("working_tree_tracked_files", []) and "untracked.txt" in data.get("untracked_files", []) and "ignored.log" not in data.get("untracked_files", [])'; then
    test_pass "evidence-bundle touched-files output captures working tree evidence"
  else
    test_fail "evidence-bundle touched-files output captures working tree evidence"
    status=1
  fi

  if grep -Eq '^Latest failure log: ' "$default_failure_log_file" && ! grep -q 'gh stub unexpected command' "$default_output_log"; then
    test_pass "evidence-bundle default mode avoids network-only CI behavior"
  else
    test_fail "evidence-bundle default mode avoids network-only CI behavior"
    status=1
  fi

  if python3 - "$default_bundle_zip" "$default_bundle_root" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
bundle_root = sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    summary_name = f'{bundle_root}/summary.txt'
    status_name = f'{bundle_root}/git-status-short.txt'
    touched_name = f'{bundle_root}/touched-files.json'
    failure_name = f'{bundle_root}/failure-log.txt'
    ignored_name = f'{bundle_root}/ignored.log'
    assert summary_name in names
    assert status_name in names
    assert touched_name in names
    assert failure_name in names
    assert ignored_name not in names
    assert not any(name.startswith(f'{bundle_root}/ci-log-dump/') for name in names)
    assert not any(name.startswith(f'{bundle_root}/post-codex/') for name in names)
    assert not any(name.startswith(f'{bundle_root}/repo-zip/') for name in names)
PY
  then
    test_pass "evidence-bundle default archive contains only core sections"
  else
    test_fail "evidence-bundle default archive contains only core sections"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label review --post-codex --include-repo-zip
  ) > "$post_output_log"; then
    :
  else
    test_fail "evidence-bundle helper records optional artifact sections"
    status=1
  fi

  post_bundle_dir="$(sed -n 's/^INFO: bundle dir: //p' "$post_output_log" | tail -n 1)"
  post_bundle_zip="$(sed -n 's/^INFO: bundle zip: //p' "$post_output_log" | tail -n 1)"
  post_summary_file="$post_bundle_dir/summary.txt"
  post_bundle_root="$(basename "$post_bundle_dir")"

  if grep -Eq '^Included sections: .*post-codex-packet.*repo-zip' "$post_summary_file" && grep -Eq '^Post-codex packet zip: ' "$post_summary_file" && grep -Eq '^Repo snapshot zip: ' "$post_summary_file"; then
    test_pass "evidence-bundle summary records optional packet paths"
  else
    test_fail "evidence-bundle summary records optional packet paths"
    status=1
  fi

  if [ -f "$post_bundle_zip" ] && grep -q '^INFO: post-codex packet zip: ' "$post_output_log" && grep -q '^INFO: repo-zip zip path: ' "$post_output_log"; then
    test_pass "evidence-bundle optional artifact run reports packet zip paths"
  else
    test_fail "evidence-bundle optional artifact run reports packet zip paths"
    status=1
  fi

  if python3 - "$post_bundle_zip" "$post_bundle_root" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
bundle_root = sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    assert any(name.startswith(f'{bundle_root}/post-codex/') for name in names)
    assert any(name.startswith(f'{bundle_root}/repo-zip/') for name in names)
    assert f'{bundle_root}/summary.txt' in names
PY
  then
    test_pass "evidence-bundle archive contains optional packet directories"
  else
    test_fail "evidence-bundle archive contains optional packet directories"
    status=1
  fi

  (
    cd "$smoke_test_dir" || exit 1
    git remote set-url origin git@github.com:example/evidence-bundle-fixture.git
  ) || return 1

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_VIEW_HEAD_REF='feature/evidence-bundle' GH_STUB_RUN_LIST_JSON='[{"databaseId":222,"conclusion":"failure"}]' GH_STUB_RUN_VIEW_LOG='ci log line one
ci log line two' REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label pr --pr 123
  ) > "$pr_output_log"; then
    :
  else
    test_fail "evidence-bundle optional ci log dump run succeeds"
    status=1
  fi

  pr_bundle_dir="$(sed -n 's/^INFO: bundle dir: //p' "$pr_output_log" | tail -n 1)"
  pr_bundle_zip="$(sed -n 's/^INFO: bundle zip: //p' "$pr_output_log" | tail -n 1)"
  pr_summary_file="$pr_bundle_dir/summary.txt"
  pr_bundle_root="$(basename "$pr_bundle_dir")"

  if grep -Eq '^PR number: 123$' "$pr_summary_file" && grep -Eq '^Included sections: .*ci-log-dump' "$pr_summary_file" && grep -Eq '^CI log dump dir: ' "$pr_summary_file"; then
    test_pass "evidence-bundle PR mode records ci-log-dump metadata"
  else
    test_fail "evidence-bundle PR mode records ci-log-dump metadata"
    status=1
  fi

  if grep -q '^INFO: ci log dump saved log path: ' "$pr_output_log" && grep -q '^Saved log path: ' "$pr_bundle_dir/ci-log-dump/output.txt"; then
    test_pass "evidence-bundle PR mode saves CI log output"
  else
    test_fail "evidence-bundle PR mode saves CI log output"
    status=1
  fi

  if python3 - "$pr_bundle_zip" "$pr_bundle_root" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
bundle_root = sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    assert f'{bundle_root}/summary.txt' in names
    assert f'{bundle_root}/ci-log-dump/output.txt' in names
    assert any(name.startswith(f'{bundle_root}/ci-log-dump/') and name.endswith('.log') for name in names)
PY
  then
    test_pass "evidence-bundle archive includes CI log dump artifacts"
  else
    test_fail "evidence-bundle archive includes CI log dump artifacts"
    status=1
  fi

  return "$status"
}


smoke_check_github_settings_contract() {
  local status=0
  local github_settings_json="$smoke_test_base/github-settings-check-$$.json"
  local github_settings_doctor_json="$smoke_test_base/repo-doctor-github-settings-$$.json"
  local gh_stub_dir="$smoke_test_base/gh-stub-settings"

  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --machine-json > "$github_settings_json"
  ) && python -m json.tool "$github_settings_json" >/dev/null && \
    smoke_json_assert "$github_settings_json" 'data.get("overall_status") == "pass" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("default_branch") == "main" and data.get("actions_enabled") is True and data.get("pr_template_exists") is True and data.get("issue_templates_exist") is True and data.get("ci_workflow_exists") is True'; then
    test_pass "github-settings-check machine-json is parseable"
  else
    test_fail "github-settings-check machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/repo-doctor --check=github-settings-readiness --json --json-level=all > "$github_settings_doctor_json"
  ) && python -m json.tool "$github_settings_doctor_json" >/dev/null && \
    smoke_json_assert "$github_settings_doctor_json" 'data.get("overall_status") == "pass" and any(check.get("name") == "github-settings-readiness" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "repo-doctor github-settings-readiness check passes"
  else
    test_fail "repo-doctor github-settings-readiness check passes"
    status=1
  fi

  rm -f "$github_settings_json" "$github_settings_doctor_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_repo_doctor_artifact_guard() {
  local status=0
  local artifact_repo=""
  local artifact_pass_json="$smoke_test_base/repo-doctor-artifact-pass-$$.json"
  local artifact_fail_json="$smoke_test_base/repo-doctor-artifact-fail-$$.json"

  artifact_repo="$(smoke_setup_subset_repo)" || {
    test_fail "repo-doctor artifact guard fixture creates a repo"
    return 1
  }

  if (
    cd "$artifact_repo" || return 1
    printf 'tracked scratch file\n' > scratch.txt || return 1
    git add scratch.txt >/dev/null 2>&1 || return 1
    git commit -m "track scratch file" >/dev/null 2>&1 || return 1
    repo-automation/bin/repo-doctor --check=artifact-guard --json --json-level=all > "$artifact_pass_json"
  ) && python -m json.tool "$artifact_pass_json" >/dev/null && \
    smoke_json_assert "$artifact_pass_json" 'data.get("overall_status") == "pass" and any(check.get("name") == "artifact-guard" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "repo-doctor artifact guard ignores tracked root files"
  else
    test_fail "repo-doctor artifact guard ignores tracked root files"
    status=1
  fi

  if (
    cd "$artifact_repo" || return 1
    mkdir -p .cache tmp temp || return 1
    printf 'generated root artifact\n' > touched.json || return 1
    printf 'generated root artifact\n' > range.json || return 1
    printf 'generated root artifact\n' > .tmp-guard || return 1
    printf 'generated root artifact\n' > tmp-guard.tmp || return 1
    printf 'generated root artifact\n' > root.log || return 1
    printf 'generated root artifact\n' > tmp-guard.log || return 1
    repo-automation/bin/repo-doctor --check=artifact-guard --json > "$artifact_fail_json"
    result=$?
    [ "$result" -ne 0 ]
  ) && python -m json.tool "$artifact_fail_json" >/dev/null && \
    smoke_json_assert "$artifact_fail_json" 'data.get("overall_status") == "fail" and any(check.get("name") == "artifact-guard" and check.get("status") == "fail" and ".cache/" in check.get("message", "") and "tmp/" in check.get("message", "") and "temp/" in check.get("message", "") and "touched.json" in check.get("message", "") and "range.json" in check.get("message", "") and ".tmp-guard" in check.get("message", "") and "tmp-guard.tmp" in check.get("message", "") and "root.log" in check.get("message", "") and "tmp-guard.log" in check.get("message", "") and "scratch.txt" not in check.get("message", "") for check in data.get("checks", []))'; then
    test_pass "repo-doctor artifact guard detects repo-root artifacts"
  else
    test_fail "repo-doctor artifact guard detects repo-root artifacts"
    status=1
  fi

  rm -f "$artifact_pass_json" "$artifact_fail_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_prepare_release_contract() {
  local status=0
  local prepare_release_help_out="$smoke_test_base/prepare-release-help-$$.txt"
  local prepare_release_check_json="$smoke_test_base/prepare-release-check-$$.json"
  local prepare_release_dry_run_json="$smoke_test_base/prepare-release-dry-run-$$.json"
  local prepare_release_apply_json="$smoke_test_base/prepare-release-apply-$$.json"
  local pre_dry_run_status="$smoke_test_base/prepare-release-pre-dry-run-status-$$.txt"
  local post_dry_run_status="$smoke_test_base/prepare-release-post-dry-run-status-$$.txt"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --help > "$prepare_release_help_out"
  ) && grep -q '^Usage: repo-automation/bin/prepare-release ' "$prepare_release_help_out"; then
    test_pass "prepare-release help succeeds"
  else
    test_fail "prepare-release help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --check --machine-json > "$prepare_release_check_json"
  ) && python -m json.tool "$prepare_release_check_json" >/dev/null && \
    smoke_json_assert "$prepare_release_check_json" 'data.get("mode") == "check" and data.get("overall_status") == "pass" and data.get("source_version") == "0.1.0" and data.get("target_version") == "0.1.0"'; then
    test_pass "prepare-release check passes"
  else
    test_fail "prepare-release check passes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git status --short > "$pre_dry_run_status" &&
      repo-automation/bin/prepare-release --version=0.2.0 --dry-run --machine-json > "$prepare_release_dry_run_json" &&
      git status --short > "$post_dry_run_status"
  ) && cmp -s "$pre_dry_run_status" "$post_dry_run_status" && python -m json.tool "$prepare_release_dry_run_json" >/dev/null && \
    smoke_json_assert "$prepare_release_dry_run_json" 'data.get("mode") == "dry-run" and data.get("overall_status") == "pass" and data.get("target_version") == "0.2.0" and data.get("planned_count", 0) > 0 and data.get("updated_count", 0) == 0'; then
    test_pass "prepare-release dry-run reports planned changes"
  else
    test_fail "prepare-release dry-run reports planned changes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --version=0.2.0 --apply --machine-json > "$prepare_release_apply_json"
  ) && python -m json.tool "$prepare_release_apply_json" >/dev/null && \
    smoke_json_assert "$prepare_release_apply_json" 'data.get("mode") == "apply" and data.get("overall_status") == "pass" and data.get("target_version") == "0.2.0" and data.get("updated_count", 0) > 0'; then
    test_pass "prepare-release apply updates files"
  else
    test_fail "prepare-release apply updates files"
    status=1
  fi

  if python -m json.tool "$prepare_release_apply_json" >/dev/null &&     smoke_json_assert "$prepare_release_apply_json" 'data.get("mode") == "apply" and data.get("overall_status") == "pass" and data.get("updated_count", 0) == 11 and any(entry.get("path", "").endswith("docs/VERSIONING.md") and entry.get("status") == "updated" for entry in data.get("results", [])) and any(entry.get("path", "").endswith("docs/DECISIONS.md") and entry.get("status") == "updated" for entry in data.get("results", [])) and any(entry.get("path", "").endswith("examples/downstream/.repo-automation.conf.example") and entry.get("status") == "updated" for entry in data.get("results", [])) and any(entry.get("path", "").endswith("docs/DOWNSTREAM_FEEDBACK.md") and entry.get("status") == "updated" for entry in data.get("results", []))'; then
    test_pass "prepare-release updates managed version placements"
  else
    test_fail "prepare-release updates managed version placements"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --check >/dev/null
  ); then
    test_pass "prepare-release check passes after apply"
  else
    test_fail "prepare-release check passes after apply"
    status=1
  fi

  rm -f "$prepare_release_help_out" "$prepare_release_check_json" "$prepare_release_dry_run_json" "$prepare_release_apply_json" "$pre_dry_run_status" "$post_dry_run_status" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_automation_freshness_contract() {
  local status=0
  local freshness_default_out="$smoke_test_base/automation-freshness-default-$$.txt"
  local freshness_json="$smoke_test_base/automation-freshness-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/automation-freshness > "$freshness_default_out"
  ) && grep -Eq '^RESULT: pass=' "$freshness_default_out" && ! grep -Eq '^FAIL:$' "$freshness_default_out"; then
    test_pass "automation-freshness human default output is compact"
  else
    test_fail "automation-freshness human default output is compact"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/automation-freshness --machine-json --source-root="$smoke_test_dir" > "$freshness_json"
  ) && python -m json.tool "$freshness_json" >/dev/null && \
    smoke_json_assert "$freshness_json" 'data.get("overall_status") == "pass" and data.get("source_root") == "'"$smoke_test_dir"'" and data.get("manifest_path", "").endswith("repo-automation/manifest.json") and any(item.get("path") == "repo-automation/bin/automation-freshness" and item.get("present") for item in data.get("managed_files", []))'; then
    test_pass "automation-freshness machine-json is parseable"
  else
    test_fail "automation-freshness machine-json is parseable"
    status=1
  fi

  rm -f "$freshness_default_out" "$freshness_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_repo_doctor_missing_config() {
  local status=0
  local doctor_missing_json="$smoke_test_base/repo-doctor-missing-config-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    mv .repo-automation.conf .repo-automation.conf.bak || return 1
    repo-automation/bin/repo-doctor --json --quick > "$doctor_missing_json"
    result=$?
    mv .repo-automation.conf.bak .repo-automation.conf || return 1
    [ "$result" -ne 0 ]
  ) && python -m json.tool "$doctor_missing_json" >/dev/null && \
    smoke_json_assert "$doctor_missing_json" 'data.get("overall_status") == "fail"'; then
    test_pass "repo-doctor missing config fails safely"
  else
    test_fail "repo-doctor missing config fails safely"
    status=1
    (
      cd "$smoke_test_dir" || true
      [ -f .repo-automation.conf ] || mv .repo-automation.conf.bak .repo-automation.conf >/dev/null 2>&1 || true
    )
  fi

  rm -f "$doctor_missing_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_installer_starter_template_profile() {
  local status=0
  local starter_plan_json="$smoke_test_base/repo-install-starter-plan-$$.json"
  local starter_target="$smoke_test_base/install-starter-target-$$"
  local starter_remote="$smoke_test_base/install-starter-target-$$-remote.git"
  local starter_ready_json="$smoke_test_base/starter-template-ready-install-$$.json"
  local starter_doctor_json="$smoke_test_base/repo-doctor-starter-install-$$.json"
  local starter_artifact_json="$smoke_test_base/repo-doctor-starter-source-artifact-$$.json"

  mkdir -p "$starter_target" || return 1
  (
    cd "$starter_target" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-install-test" || return 1
    git config user.email "repo-automation-install-test@example.com" || return 1
    cp "$smoke_repo_root/README.md" README.md || return 1
    cp "$smoke_repo_root/VERSION" VERSION || return 1
    cp "$smoke_repo_root/CHANGELOG.md" CHANGELOG.md || return 1
    cp -R "$smoke_repo_root/docs" . || return 1
    cp -R "$smoke_repo_root/examples" . || return 1
    git add -A || return 1
    git commit -m "init starter target" >/dev/null || return 1
    git init --bare --initial-branch=main "$starter_remote" >/dev/null || return 1
    git remote add origin "$starter_remote" || return 1
    git push -u origin main >/dev/null || return 1
  ) || status=1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target "$starter_target" --starter-template --json > "$starter_plan_json"
  ) && python -m json.tool "$starter_plan_json" >/dev/null && \
    smoke_json_assert "$starter_plan_json" 'data.get("mode") == "install" and data.get("profile") == "starter-template" and ".github/pull_request_template.md" in data.get("files_to_add", []) and ".github/ISSUE_TEMPLATE/automation-bug.yml" in data.get("files_to_add", []) and ".github/ISSUE_TEMPLATE/automation-feature.yml" in data.get("files_to_add", []) and ".github/workflows/ci.yml" not in data.get("files_to_add", []) and data.get("target_remote_status") in ("missing", "unsupported", "present")'; then
    test_pass "repo-automation-install starter-template plan/json includes template files"
  else
    test_fail "repo-automation-install starter-template plan/json includes template files"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target "$starter_target" --starter-template --apply >/dev/null
  ) && [ -f "$starter_target/.repo-automation.conf" ] && [ -f "$starter_target/.github/pull_request_template.md" ] && [ -f "$starter_target/.github/ISSUE_TEMPLATE/automation-bug.yml" ] && [ -f "$starter_target/.github/ISSUE_TEMPLATE/automation-feature.yml" ] && [ ! -f "$starter_target/.github/workflows/ci.yml" ] && grep -qx 'CHECK_PROFILE_DEFAULT="starter-template"' "$starter_target/.repo-automation.conf"; then
    test_pass "repo-automation-install starter-template apply creates templates without CI"
  else
    test_fail "repo-automation-install starter-template apply creates templates without CI"
    status=1
  fi

  if (
    cd "$starter_target" || return 1
    repo-automation/bin/starter-template-ready --check-current --machine-json > "$starter_ready_json"
  ) && python -m json.tool "$starter_ready_json" >/dev/null && \
    smoke_json_assert "$starter_ready_json" 'data.get("overall_status") == "pass" and data.get("source_root") == "'"$starter_target"'"'; then
    test_pass "starter-template-ready passes for installed starter target"
  else
    test_fail "starter-template-ready passes for installed starter target"
    status=1
  fi

  if (
    cd "$starter_target" || return 1
    repo-automation/bin/repo-doctor --quick --no-run-tests --json --json-level=warn > "$starter_doctor_json"
  ) && python -m json.tool "$starter_doctor_json" >/dev/null && \
    smoke_json_assert "$starter_doctor_json" 'data.get("mode") == "quick" and data.get("overall_status") in ("pass", "warn") and not any(check.get("status") == "fail" for check in data.get("checks", []))'; then
    test_pass "repo-doctor quick/no-run-tests passes for installed starter target"
  else
    test_fail "repo-doctor quick/no-run-tests passes for installed starter target"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/repo-doctor --check=artifact-guard --json --json-level=all > "$starter_artifact_json"
  ) && python -m json.tool "$starter_artifact_json" >/dev/null && \
    smoke_json_assert "$starter_artifact_json" 'data.get("overall_status") == "pass" and any(check.get("name") == "artifact-guard" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "source repo artifact guard remains clean after starter-template smoke"
  else
    test_fail "source repo artifact guard remains clean after starter-template smoke"
    status=1
  fi

  return "$status"
}

smoke_check_starter_template_readiness() {
  local status=0
  local readiness_json="$smoke_test_base/starter-template-ready-$$.json"
  local readiness_missing_json="$smoke_test_base/starter-template-ready-missing-$$.json"
  local readiness_doctor_out="$smoke_test_base/repo-doctor-starter-template-readiness-$$.txt"
  local readiness_missing_template="$smoke_test_dir/.github/pull_request_template.md"
  local readiness_missing_backup="$smoke_test_base/pull_request_template.md.bak"
  local readiness_human="$smoke_test_base/starter-template-ready-human-$$.txt"

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/starter-template-ready --machine-json --source-root="$smoke_test_dir" > "$readiness_json"
  ) && python -m json.tool "$readiness_json" >/dev/null &&     smoke_json_assert "$readiness_json" 'data.get("overall_status") == "pass" and data.get("source_root") == "'"$smoke_test_dir"'"'; then
    test_pass "starter-template-ready source-root machine-json passes"
  else
    test_fail "starter-template-ready source-root machine-json passes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/starter-template-ready --check-current > "$readiness_human"
  ) && grep -Eq '^RUNNING starter-template readiness\.\.\.$' "$readiness_human" && grep -Eq '^RESULT: pass=[0-9]+ warn=0 fail=0 skipped=0$' "$readiness_human"; then
    test_pass "starter-template-ready default human output passes"
  else
    test_fail "starter-template-ready default human output passes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check=starter-template-readiness --no-run-tests > "$readiness_doctor_out"
  ) && grep -Eq '^RESULT: pass=[0-9]+ warn=0 fail=0 skipped=0$' "$readiness_doctor_out"; then
    test_pass "repo-doctor starter-template-readiness check passes"
  else
    test_fail "repo-doctor starter-template-readiness check passes"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    mv "$readiness_missing_template" "$readiness_missing_backup" || return 1
    repo-automation/bin/starter-template-ready --machine-json --source-root="$smoke_test_dir" > "$readiness_missing_json"
    result=$?
    mv "$readiness_missing_backup" "$readiness_missing_template" || return 1
    [ "$result" -ne 0 ]
  ) && python -m json.tool "$readiness_missing_json" >/dev/null &&     smoke_json_assert "$readiness_missing_json" 'data.get("overall_status") == "fail" and ".github/pull_request_template.md" in (data.get("stop_reason") or "")'; then
    test_pass "starter-template-ready reports missing starter-template files"
  else
    test_fail "starter-template-ready reports missing starter-template files"
    status=1
    (
      cd "$smoke_repo_root" || true
      [ -f "$readiness_missing_template" ] || mv "$readiness_missing_backup" "$readiness_missing_template" >/dev/null 2>&1 || true
    )
  fi

  rm -f "$readiness_json" "$readiness_missing_json" "$readiness_human" "$readiness_doctor_out" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_installer_apply_contract() {
  local status=0
  local install_plan_json="$smoke_test_base/repo-install-plan-$$.json"
  local install_target="$smoke_test_base/install-target-$$"
  local install_target_remote="$smoke_test_base/install-target-$$-remote.git"
  local install_status_before
  local install_status_after
  local install_commit_count_before
  local install_commit_count_after
  local install_remote_head_before
  local install_remote_head_after
  local install_doctor_json="$smoke_test_base/repo-doctor-install-$$.json"

  mkdir -p "$install_target" || return 1
  (
    cd "$install_target" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-install-test" || return 1
    git config user.email "repo-automation-install-test@example.com" || return 1
    cp "$smoke_repo_root/README.md" README.md || return 1
    cp "$smoke_repo_root/VERSION" VERSION || return 1
    cp "$smoke_repo_root/CHANGELOG.md" CHANGELOG.md || return 1
    cp -R "$smoke_repo_root/docs" . || return 1
    cp -R "$smoke_repo_root/.github" . || return 1
    cp -R "$smoke_repo_root/examples" . || return 1
    git add -A || return 1
    git commit -m "init target" >/dev/null || return 1
    git init --bare --initial-branch=main "$install_target_remote" >/dev/null || return 1
    git remote add origin "$install_target_remote" || return 1
    git push -u origin main >/dev/null || return 1
  ) || status=1
  install_commit_count_before="$(git -C "$install_target" rev-list --count HEAD)"
  install_remote_head_before="$(git -C "$install_target_remote" rev-parse refs/heads/main)"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target "$install_target" --json --include-tests > "$install_plan_json"
  ) && python -m json.tool "$install_plan_json" >/dev/null; then
    if smoke_json_assert "$install_plan_json" 'data.get("profile") == "default" and "repo-automation/bin/branch-cleanup" in data.get("files_to_add", []) and "repo-automation/bin/post-codex-packet" in data.get("files_to_add", []) and "repo-automation/bin/repo-zip" in data.get("files_to_add", []) and "repo-automation/bin/evidence-bundle" in data.get("files_to_add", []) and "repo-automation/docs/post-codex-packet.md" in data.get("files_to_add", []) and "repo-automation/docs/repo-zip.md" in data.get("files_to_add", []) and "repo-automation/docs/evidence-bundle.md" in data.get("files_to_add", []) and "repo-automation/tests/lib/test-common.sh" in data.get("files_to_add", []) and "repo-automation/tests/lib/smoke-common.sh" in data.get("files_to_add", []) and "repo-automation/tests/smoke.sh" in data.get("files_to_add", []) and len([path for path in data.get("files_to_add", []) if path.startswith("repo-automation/tests/contracts/")]) == 19 and ".github/pull_request_template.md" not in data.get("files_to_add", []) and data.get("target_remote_status") == "unsupported"'; then
      test_pass "repo-automation-install plan/json is parseable"
    else
      test_fail "repo-automation-install plan/json is parseable"
      status=1
    fi
  else
    test_fail "repo-automation-install plan/json is parseable"
    status=1
  fi

  if grep -Fq "$install_target_remote" "$install_plan_json"; then
    test_fail "repo-automation-install JSON does not leak raw target origin"
    status=1
  else
    test_pass "repo-automation-install JSON does not leak raw target origin"
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target "$install_target" --apply --dry-run >/dev/null
  ) && [ ! -f "$install_target/.repo-automation.conf" ]; then
    test_pass "repo-automation-install dry-run does not write files"
  else
    test_fail "repo-automation-install dry-run does not write files"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target "$install_target" --apply --include-tests >/dev/null
  ) && [ -f "$install_target/AGENTS.md" ] && [ -f "$install_target/.repo-automation.conf" ] && [ -f "$install_target/repo-automation/docs/README.md" ] && [ -f "$install_target/repo-automation/docs/local-overrides.md" ] && [ -f "$install_target/repo-automation/docs/post-codex-packet.md" ] && [ -f "$install_target/repo-automation/docs/repo-zip.md" ] && [ -f "$install_target/repo-automation/docs/evidence-bundle.md" ] && [ -f "$install_target/repo-automation/bin/repo-doctor" ] && [ -f "$install_target/repo-automation/bin/failure-log" ] && [ -f "$install_target/repo-automation/bin/status-packet" ] && [ -f "$install_target/repo-automation/bin/post-codex-packet" ] && [ -f "$install_target/repo-automation/bin/repo-zip" ] && [ -f "$install_target/repo-automation/bin/evidence-bundle" ] && [ -f "$install_target/repo-automation/bin/run-tests" ] && [ -f "$install_target/repo-automation/tests/lib/test-common.sh" ] && [ -f "$install_target/repo-automation/tests/smoke.sh" ] && [ -x "$install_target/repo-automation/bin/repo-doctor" ] && [ -x "$install_target/repo-automation/bin/failure-log" ] && [ -x "$install_target/repo-automation/bin/status-packet" ] && [ -x "$install_target/repo-automation/bin/post-codex-packet" ] && [ -x "$install_target/repo-automation/bin/repo-zip" ] && [ -x "$install_target/repo-automation/bin/evidence-bundle" ] && [ -x "$install_target/repo-automation/bin/run-tests" ] && [ -x "$install_target/repo-automation/tests/smoke.sh" ] && cmp -s "$smoke_repo_root/AGENTS.md" "$install_target/AGENTS.md"; then
    test_pass "repo-automation-install apply creates managed files"
  else
    test_fail "repo-automation-install apply creates managed files"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    [ -f repo-automation/tests/lib/smoke-common.sh ] || return 1
    [ -f repo-automation/tests/contracts/add-doc-pr.sh ] || return 1
    [ -f repo-automation/tests/contracts/report-upstream.sh ] || return 1
    [ -f repo-automation/tests/contracts/failure-log.sh ] || return 1
    [ -f repo-automation/tests/contracts/run-tests.sh ] || return 1
    [ -f repo-automation/tests/contracts/touched-files.sh ] || return 1
    [ -f repo-automation/tests/contracts/ci-log-dump.sh ] || return 1
    [ -f repo-automation/tests/contracts/repo-doctor.sh ] || return 1
    [ -f repo-automation/tests/contracts/status-packet.sh ] || return 1
    [ -f repo-automation/tests/contracts/post-codex-packet.sh ] || return 1
    [ -f repo-automation/tests/contracts/repo-zip.sh ] || return 1
    [ -f repo-automation/tests/contracts/evidence-bundle.sh ] || return 1
    [ -f repo-automation/tests/contracts/github-settings-check.sh ] || return 1
    [ -f repo-automation/tests/contracts/installer.sh ] || return 1
    [ -f repo-automation/tests/contracts/starter-template.sh ] || return 1
    [ -f repo-automation/tests/contracts/branch-cleanup-preflight.sh ] || return 1
    [ -f repo-automation/tests/contracts/prepare-release.sh ] || return 1
    [ -f repo-automation/tests/contracts/automation-freshness.sh ] || return 1
    [ -x repo-automation/tests/contracts/add-doc-pr.sh ] || return 1
    [ -x repo-automation/tests/contracts/report-upstream.sh ] || return 1
    [ -x repo-automation/tests/contracts/failure-log.sh ] || return 1
    [ -x repo-automation/tests/contracts/run-tests.sh ] || return 1
    [ -x repo-automation/tests/contracts/touched-files.sh ] || return 1
    [ -x repo-automation/tests/contracts/ci-log-dump.sh ] || return 1
    [ -x repo-automation/tests/contracts/repo-doctor.sh ] || return 1
    [ -x repo-automation/tests/contracts/status-packet.sh ] || return 1
    [ -x repo-automation/tests/contracts/post-codex-packet.sh ] || return 1
    [ -x repo-automation/tests/contracts/repo-zip.sh ] || return 1
    [ -x repo-automation/tests/contracts/evidence-bundle.sh ] || return 1
    [ -x repo-automation/tests/contracts/github-settings-check.sh ] || return 1
    [ -x repo-automation/tests/contracts/installer.sh ] || return 1
    [ -x repo-automation/tests/contracts/starter-template.sh ] || return 1
    [ -x repo-automation/tests/contracts/branch-cleanup-preflight.sh ] || return 1
    [ -x repo-automation/tests/contracts/prepare-release.sh ] || return 1
    [ -x repo-automation/tests/contracts/automation-freshness.sh ] || return 1
  ); then
    test_pass "repo-automation-install include-tests bundle installs smoke contracts"
  else
    test_fail "repo-automation-install include-tests bundle installs smoke contracts"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    # shellcheck disable=SC1091
    source repo-automation/lib/common.sh && repo_auto_load_config >/dev/null && repo_auto_validate_required_config >/dev/null
  ); then
    test_pass "repo-automation-install installed config loads and validates"
  else
    test_fail "repo-automation-install installed config loads and validates"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    repo-automation/bin/repo-doctor --quick --no-run-tests >/dev/null
  ); then
    test_pass "repo-automation-install target repo-doctor quick/no-run-tests succeeds"
  else
    test_fail "repo-automation-install target repo-doctor quick/no-run-tests succeeds"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    repo-automation/bin/repo-doctor --json --quick --no-run-tests > "$install_doctor_json"
  ) && python -m json.tool "$install_doctor_json" >/dev/null && \
    smoke_json_assert "$install_doctor_json" 'data.get("overall_status") in ("pass", "warn") and any(check.get("status") == "warn" for check in data.get("checks", [])) and not any(check.get("status") == "fail" for check in data.get("checks", []))'; then
    test_pass "repo-automation-install target repo-doctor json audit succeeds"
  else
    test_fail "repo-automation-install target repo-doctor json audit succeeds"
    status=1
  fi

  if grep -qx 'EXPECTED_REMOTE_URL=""' "$install_target/.repo-automation.conf"; then
    test_pass "repo-automation-install uses empty EXPECTED_REMOTE_URL fallback for unsupported target origin"
  else
    test_fail "repo-automation-install uses empty EXPECTED_REMOTE_URL fallback for unsupported target origin"
    status=1
  fi

  install_status_before="$(git -C "$install_target" status --porcelain)"
  if [ -n "$install_status_before" ]; then
    test_pass "repo-automation-install does not commit or push in target repo"
  else
    test_fail "repo-automation-install does not commit or push in target repo"
    status=1
  fi
  install_commit_count_after="$(git -C "$install_target" rev-list --count HEAD)"
  install_remote_head_after="$(git -C "$install_target_remote" rev-parse refs/heads/main)"
  if [ "$install_commit_count_before" = "$install_commit_count_after" ] && [ "$install_remote_head_before" = "$install_remote_head_after" ]; then
    test_pass "repo-automation-install leaves target history and remote untouched"
  else
    test_fail "repo-automation-install leaves target history and remote untouched"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    printf '# local override\n' > repo-automation/docs/local-overrides.md
  ); then
    :
  else
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target "$install_target" --json > "$install_plan_json"
  ) && python -m json.tool "$install_plan_json" >/dev/null && \
    smoke_json_assert "$install_plan_json" 'data.get("mode") == "update"'; then
    test_pass "repo-automation-install second plan infers update mode"
  else
    test_fail "repo-automation-install second plan infers update mode"
    status=1
  fi

  if grep -q '^# local override$' "$install_target/repo-automation/docs/local-overrides.md"; then
    test_pass "repo-automation-install preserves existing local overrides"
  else
    test_fail "repo-automation-install preserves existing local overrides"
    status=1
  fi

  install_status_after="$(git -C "$install_target" status --porcelain)"
  if [ -n "$install_status_after" ]; then
    :
  else
    test_fail "repo-automation-install target repo remains unchanged in git history"
    status=1
  fi

  rm -f "$install_plan_json" >/dev/null 2>&1 || true
  rm -f "$install_doctor_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_branch_cleanup_json() {
  local status=0
  local branch_json="$smoke_test_dir/branch-cleanup.json"
  local start_branch=""

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/branch-cleanup --json --plan > "$branch_json"
  ) && python -m json.tool "$branch_json" >/dev/null; then
    test_pass "branch-cleanup json is parseable"
  else
    test_fail "branch-cleanup json is parseable"
    status=1
  fi

  (
    cd "$smoke_test_dir" || return 1
    git checkout -b docs/merged-branch >/dev/null || return 1
    echo "merged" >> README.md
    git add README.md || return 1
    git commit -m "merged branch commit" >/dev/null || return 1
    git checkout main >/dev/null || return 1
    git merge --no-ff docs/merged-branch -m "merge docs branch" >/dev/null || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    git checkout -b feature/unique-branch >/dev/null || return 1
    echo "unique" >> README.md
    git add README.md || return 1
    git commit -m "unique branch commit" >/dev/null || return 1
    start_branch="$(git branch --show-current)"
    [ "$start_branch" = "feature/unique-branch" ]
  ) || status=1

  (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/branch-cleanup --json --plan > "$branch_json"
  ) || status=1

  if smoke_json_assert "$branch_json" '"docs/merged-branch" in data.get("candidates", [])'; then
    test_pass "merged local branch classified as candidate"
  else
    test_fail "merged local branch classified as candidate"
    status=1
  fi

  if smoke_json_assert "$branch_json" 'any(item.get("branch") == "feature/unique-branch" and item.get("reason") == "current-branch" for item in data.get("skipped", []))'; then
    test_pass "current branch skipped with current-branch reason"
  else
    test_fail "current branch skipped with current-branch reason"
    status=1
  fi

  if smoke_json_assert "$branch_json" 'any(item.get("branch") == "main" and item.get("reason") == "default-branch" for item in data.get("skipped", []))'; then
    test_pass "default branch skipped with default-branch reason"
  else
    test_fail "default branch skipped with default-branch reason"
    status=1
  fi

  if smoke_json_assert "$branch_json" 'any(item.get("branch") == "feature/unique-branch" and item.get("reason") in ("current-branch", "has-unique-commits", "not-merged-into-origin-default") for item in data.get("skipped", []))'; then
    test_pass "unique branch shows expected non-candidate reason"
  else
    test_fail "unique branch shows expected non-candidate reason"
    status=1
  fi

  return "$status"
}


smoke_check_pr_finish_watch_exit() {
  local status=0
  local blocked_stderr="$smoke_test_dir/pr-finish-watch-blocked.log"
  local green_stderr="$smoke_test_dir/pr-finish-watch-green.log"
  local gh_stub_dir="$smoke_test_base/gh-stub"
  local local_bash_path=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"fail","state":"FAILURE","workflow":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --pr 123 >/dev/null 2> "$blocked_stderr"
  ); then
    test_fail "pr-finish watch exits nonzero when checks are blocked"
    status=1
  else
    if grep -q 'watch completed with checks status: blocked' "$blocked_stderr"; then
      test_pass "pr-finish watch exits nonzero when checks are blocked"
    else
      test_fail "pr-finish watch exits nonzero when checks are blocked"
      status=1
    fi
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --pr 123 >/dev/null 2> "$green_stderr"
  ); then
    test_pass "pr-finish watch exits zero when checks are green"
  else
    test_fail "pr-finish watch exits zero when checks are green"
    status=1
  fi

  return "$status"
}

smoke_check_preflight_json() {
  local status=0
  local preflight_json="$smoke_test_dir/preflight.json"
  local finish_stderr="$smoke_test_dir/pr-finish-stderr.log"
  local local_bash_path=""
  local shim_dir=""

  if (
    cd "$smoke_test_dir" || return 1
    git checkout main >/dev/null || return 1
    repo-automation/bin/codex-slice-preflight --check-only --branch feature/preflight-smoke >/dev/null
  ); then
    test_pass "preflight check-only succeeds"
  else
    test_fail "preflight check-only succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --json --check-only --branch feature/preflight-smoke > "$preflight_json"
  ) && python -m json.tool "$preflight_json" >/dev/null; then
    test_pass "preflight json is parseable"
  else
    test_fail "preflight json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    local_bash_path="$(command -v bash)" || return 1
    git rev-parse HEAD > "$smoke_test_dir/pre-head.txt" || return 1
    git branch --show-current > "$smoke_test_dir/pre-branch.txt" || return 1
    git status --porcelain --untracked-files=no > "$smoke_test_dir/pre-status.txt" || return 1
    shim_dir="$smoke_test_dir/no-gh-bin"
    mkdir -p "$shim_dir" || return 1
    ln -sf "$(command -v git)" "$shim_dir/git" || return 1
    ln -sf "$(command -v dirname)" "$shim_dir/dirname" || return 1
    ln -sf "$(command -v grep)" "$shim_dir/grep" || return 1
    PATH="$shim_dir" "$local_bash_path" repo-automation/bin/pr-finish --plan >/dev/null 2> "$finish_stderr"
    return 1
  ); then
    test_fail "pr-finish no-auth/no-gh safe-failure path"
    status=1
  else
    if (
      cd "$smoke_test_dir" || return 1
      git rev-parse HEAD > "$smoke_test_dir/post-head.txt" || return 1
      git branch --show-current > "$smoke_test_dir/post-branch.txt" || return 1
      git status --porcelain --untracked-files=no > "$smoke_test_dir/post-status.txt" || return 1
      cmp -s "$smoke_test_dir/pre-head.txt" "$smoke_test_dir/post-head.txt" &&
        cmp -s "$smoke_test_dir/pre-branch.txt" "$smoke_test_dir/post-branch.txt" &&
        cmp -s "$smoke_test_dir/pre-status.txt" "$smoke_test_dir/post-status.txt" &&
        grep -q 'STOP: gh is required for pr-finish' "$finish_stderr"
    ); then
      test_pass "pr-finish no-auth/no-gh failure is safe and non-mutating"
    else
      test_fail "pr-finish no-auth/no-gh failure is safe and non-mutating"
      status=1
    fi
  fi

  return "$status"
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
