#!/usr/bin/env bash
# tests/smoke.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/tests/lib/test-common.sh"

smoke_timeout_seconds=120

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

timeout() {
  local timeout_spec="${1:-0}"
  local command_string=""
  local arg

  shift || true
  timeout_spec="${timeout_spec%s}"

  for arg in "$@"; do
    command_string+="$(printf '%q ' "$arg")"
  done

  test_run_with_timeout "$timeout_spec" "${command_string% }"
}

smoke_main() {
  local repo_root
  local test_base
  local test_dir=""
  local remote_dir
  local expected_origin_url="git@github.com:i-schuyler/repo-automation-template.git"
  local start_branch
  local branch_json
  local preflight_json
  local add_doc_pr_json
  local add_doc_pr_block_json
  local report_bug_json
  local report_feature_json
  local report_secret_json
  local report_preview_bug
  local report_preview_feature
  local run_tests_default_out
  local run_tests_explain_out
  local run_tests_json
  local run_tests_log_file
  local run_tests_no_log_file
  local run_tests_no_log_out
  local doctor_default_out
  local doctor_explain_out
  local doctor_json_warn
  local doctor_log_file
  local doctor_no_log_file
  local doctor_no_log_out
  local doctor_json
  local doctor_missing_json
  local install_plan_json
  local install_target=""
  local install_target_remote=""
  local install_status_before
  local install_status_after
  local install_commit_count_before
  local install_commit_count_after
  local install_remote_head_before
  local install_remote_head_after
  local install_doctor_json
  local finish_stderr
  local shim_dir
  local local_bash_path
  local status=0

  if [ "$smoke_timeout_seconds" -gt 0 ] && ! test_have_timeout; then
    test_warn_timeout_once
  fi

  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  mkdir -p "$TEST_TEMP_ROOT" || return 1
  test_base="$(mktemp -d "${TEST_TEMP_ROOT}/smoke.XXXXXX")" || return 1
  test_register_temp_dir "$test_base" || return 1
  test_dir="$test_base/smoke"
  remote_dir="$test_base/smoke-remote.git"
  mkdir -p "$test_dir" || return 1
  trap 'test_cleanup' EXIT INT TERM

  mkdir -p "$test_dir/scripts/lib" "$test_dir/tests/lib" "$test_dir/tests" || return 1
  cp "$repo_root/scripts/lib/repo-automation-common.sh" "$test_dir/scripts/lib/repo-automation-common.sh" || return 1
  cp "$repo_root/scripts/branch-cleanup" "$test_dir/scripts/branch-cleanup" || return 1
  cp "$repo_root/scripts/codex-slice-preflight" "$test_dir/scripts/codex-slice-preflight" || return 1
  cp "$repo_root/scripts/pr-finish" "$test_dir/scripts/pr-finish" || return 1
  cp "$repo_root/scripts/add-doc-pr" "$test_dir/scripts/add-doc-pr" || return 1
  cp "$repo_root/scripts/repo-automation-report-upstream" "$test_dir/scripts/repo-automation-report-upstream" || return 1
  cp "$repo_root/scripts/repo-doctor" "$test_dir/scripts/repo-doctor" || return 1
  cp "$repo_root/scripts/repo-automation-install" "$test_dir/scripts/repo-automation-install" || return 1
  cp "$repo_root/scripts/run-tests" "$test_dir/scripts/run-tests" || return 1
  cp "$repo_root/tests/lib/test-common.sh" "$test_dir/tests/lib/test-common.sh" || return 1
  cp "$repo_root/tests/smoke.sh" "$test_dir/tests/smoke.sh" || return 1
  cp "$repo_root/tests/version-consistency.sh" "$test_dir/tests/version-consistency.sh" || return 1
  chmod +x "$test_dir/scripts/branch-cleanup" "$test_dir/scripts/codex-slice-preflight" "$test_dir/scripts/pr-finish" "$test_dir/scripts/add-doc-pr" "$test_dir/scripts/repo-automation-report-upstream" "$test_dir/scripts/repo-doctor" "$test_dir/scripts/repo-automation-install" "$test_dir/scripts/run-tests" "$test_dir/tests/smoke.sh" "$test_dir/tests/version-consistency.sh" || return 1

  (
    cd "$test_dir" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-test" || return 1
    git config user.email "repo-automation-test@example.com" || return 1
    cat > README.md <<EOF
# smoke

Current version: 0.1.0
EOF
    cat > VERSION <<EOF
0.1.0
EOF
    cat > CHANGELOG.md <<EOF
# Changelog

## [0.1.0] - Unreleased
EOF
    mkdir -p docs .github/workflows .github/ISSUE_TEMPLATE || return 1
    cp -R "$repo_root/docs/repo-automation" docs/ || return 1
    cat > docs/DECISIONS.md <<EOF
# Decisions

| Current version line | starts at 0.1.0 |
EOF
    cat > docs/VERSIONING.md <<EOF
# Versioning

Version numbers must stay aligned in these places:
- VERSION
- .repo-automation.conf
- REPO_AUTOMATION_VERSION
- tests/version-consistency.sh
- examples/downstream/.repo-automation.conf.example
EOF
    cat > docs/INDEX.md <<EOF
# Docs Index

- repo-automation/branch-cleanup.md
- repo-automation/codex-slice-preflight.md
- repo-automation/pr-finish.md
- repo-automation/add-doc-pr.md
- repo-automation/repo-automation-report-upstream.md
- repo-automation/repo-doctor.md
- repo-automation/repo-automation-install.md
- repo-automation/testing.md
EOF
    mkdir -p examples/downstream || return 1
    cat > examples/downstream/.repo-automation.conf.example <<EOF
INSTALLED_VERSION_OR_REF="0.1.0-EXAMPLE"
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
    git init --bare --initial-branch=main "$remote_dir" >/dev/null || return 1
    git remote add origin "$remote_dir" || return 1
    git push -u origin main >/dev/null || return 1
    git remote set-url origin "$expected_origin_url" || return 1
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
LOCAL_OVERRIDES_DOC="docs/repo-automation/local-overrides.md"
DEFAULT_BRANCH="main"
DOCS_DIR="docs"
DOCS_INDEX="docs/INDEX.md"
STATE_DIR_NAME="repo-automation-template-tests"
REMOTE_NAME="origin"
EXPECTED_REMOTE_URL="$expected_origin_url"
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

  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/branch-cleanup --plan >/dev/null
  ); then
    test_pass "branch-cleanup plan succeeds"
  else
    test_fail "branch-cleanup plan succeeds"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    scripts/pr-finish --help >/dev/null
  ); then
    test_pass "pr-finish help succeeds"
  else
    test_fail "pr-finish help succeeds"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    scripts/add-doc-pr --help >/dev/null
  ); then
    test_pass "add-doc-pr help succeeds"
  else
    test_fail "add-doc-pr help succeeds"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    scripts/repo-automation-report-upstream --help >/dev/null
  ); then
    test_pass "report-upstream help succeeds"
  else
    test_fail "report-upstream help succeeds"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    scripts/repo-doctor --help >/dev/null
  ); then
    test_pass "repo-doctor help succeeds"
  else
    test_fail "repo-doctor help succeeds"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    scripts/repo-automation-install --help >/dev/null
  ); then
    test_pass "repo-automation-install help succeeds"
  else
    test_fail "repo-automation-install help succeeds"
    status=1
  fi

  test_run_named_check "smoke:add-doc-pr-docs-only"
  add_doc_pr_json="$test_base/add-doc-pr-plan-$$.json"
  if (
    cd "$test_dir" || return 1
    mkdir -p docs || return 1
    printf 'docs only change\n' > docs/plan-doc.md || return 1
    scripts/add-doc-pr --plan --json > "$add_doc_pr_json"
  ) && python -m json.tool "$add_doc_pr_json" >/dev/null; then
    if smoke_json_assert "$add_doc_pr_json" '"docs/plan-doc.md" in data.get("changed_files", []) and len(data.get("blocked_files", [])) == 0'; then
      test_pass "add-doc-pr docs-only plan/json succeeds"
    else
      test_fail "add-doc-pr docs-only plan/json succeeds"
      status=1
    fi
  else
    test_fail "add-doc-pr docs-only plan/json succeeds"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    rm -f docs/plan-doc.md || return 1
  ); then
    :
  fi

  test_run_named_check "smoke:add-doc-pr-blocked-file"
  add_doc_pr_block_json="$test_base/add-doc-pr-blocked-$$.json"
  if (
    cd "$test_dir" || return 1
    printf '#!/usr/bin/env bash\n' > scripts/blocked-change.sh || return 1
    scripts/add-doc-pr --plan --json > "$add_doc_pr_block_json"
    return 1
  ); then
    test_fail "add-doc-pr blocks scripts/ changes in plan mode"
    status=1
  else
    if python -m json.tool "$add_doc_pr_block_json" >/dev/null && \
      smoke_json_assert "$add_doc_pr_block_json" '"scripts/blocked-change.sh" in data.get("blocked_files", [])'; then
      test_pass "add-doc-pr blocks scripts/ changes in plan mode"
    else
      test_fail "add-doc-pr blocks scripts/ changes in plan mode"
      status=1
    fi
  fi

  if (
    cd "$test_dir" || return 1
    rm -f scripts/blocked-change.sh || return 1
  ); then
    :
  fi

  rm -f "$add_doc_pr_json" "$add_doc_pr_block_json" >/dev/null 2>&1 || true

  test_run_named_check "smoke:report-upstream-preview"
  report_bug_json="$test_base/report-upstream-bug-$$.json"
  report_preview_bug="$test_base/report-upstream-bug-preview-$$.md"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-report-upstream \
      --type bug \
      --title "Bug smoke" \
      --command "scripts/example --flag" \
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

  report_feature_json="$test_base/report-upstream-feature-$$.json"
  report_preview_feature="$test_base/report-upstream-feature-preview-$$.md"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-report-upstream \
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
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-report-upstream --type bug --dry-run >/dev/null 2>&1
  ); then
    test_fail "report-upstream missing title fails safely"
    status=1
  else
    test_pass "report-upstream missing title fails safely"
  fi

  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-report-upstream --type wrong --title "Invalid type" --dry-run >/dev/null 2>&1
  ); then
    test_fail "report-upstream invalid type fails safely"
    status=1
  else
    test_pass "report-upstream invalid type fails safely"
  fi

  test_run_named_check "smoke:report-upstream-secret-scan"
  report_secret_json="$test_base/report-upstream-secret-$$.json"
  if (
    cd "$test_dir" || return 1
    printf 'token=supersecret\n' > logs-secret.txt || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-report-upstream \
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
    cd "$test_dir" || return 1
    rm -f logs-secret.txt || return 1
  ); then
    :
  fi

  rm -f "$report_bug_json" "$report_feature_json" "$report_secret_json" "$report_preview_bug" "$report_preview_feature" >/dev/null 2>&1 || true

  test_run_named_check "smoke:run-tests-contract"
  run_tests_default_out="$test_base/run-tests-default-$$.txt"
  if (
    cd "$repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 timeout "${smoke_timeout_seconds}s" scripts/run-tests > "$run_tests_default_out"
  ) && ! grep -Eq '^PASS:' "$run_tests_default_out" && grep -Eq '^RESULT: pass=' "$run_tests_default_out"; then
    test_pass "run-tests default output is compact"
  else
    test_fail "run-tests default output is compact"
    status=1
  fi

  run_tests_explain_out="$test_base/run-tests-explain-$$.txt"
  if (
    cd "$repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 timeout "${smoke_timeout_seconds}s" scripts/run-tests --explain > "$run_tests_explain_out"
  ) && grep -Eq '^PASS: bash syntax scripts/run-tests - passed' "$run_tests_explain_out"; then
    test_pass "run-tests explain output shows details"
  else
    test_fail "run-tests explain output shows details"
    status=1
  fi

  run_tests_json="$test_base/run-tests-warn-$$.json"
  if (
    cd "$repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 timeout "${smoke_timeout_seconds}s" scripts/run-tests --json --json-level warn > "$run_tests_json"
  ) && python -m json.tool "$run_tests_json" >/dev/null && \
    smoke_json_assert "$run_tests_json" 'data.get("script") == "run-tests" and data.get("json_level") == "warn" and data.get("overall_status") in ("pass", "warn", "fail")'; then
    test_pass "run-tests json warn is parseable"
  else
    test_fail "run-tests json warn is parseable"
    status=1
  fi

  run_tests_log_file="$test_base/run-tests-log-$$.log"
  if (
    cd "$repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 timeout "${smoke_timeout_seconds}s" scripts/run-tests --log-file "$run_tests_log_file" >/dev/null
  ) && [ -f "$run_tests_log_file" ]; then
    test_pass "run-tests log-file creates a log"
  else
    test_fail "run-tests log-file creates a log"
    status=1
  fi

  run_tests_no_log_file="$test_base/run-tests-no-log-$$.log"
  run_tests_no_log_out="$test_base/run-tests-no-log-$$.txt"
  if (
    cd "$repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 timeout "${smoke_timeout_seconds}s" scripts/run-tests --log-file "$run_tests_no_log_file" --no-log > "$run_tests_no_log_out"
  ) && [ ! -e "$run_tests_no_log_file" ] && ! grep -Eq '^Log:' "$run_tests_no_log_out"; then
    test_pass "run-tests no-log does not create a log"
  else
    test_fail "run-tests no-log does not create a log"
    status=1
  fi

  test_run_named_check "smoke:repo-doctor-contract"
  doctor_default_out="$test_base/repo-doctor-quick-default-$$.txt"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --quick > "$doctor_default_out"
  ) && ! grep -Eq '^PASS:' "$doctor_default_out" && grep -Eq '^RESULT: pass=' "$doctor_default_out" && grep -Eq '^WARN:$' "$doctor_default_out" && grep -Eq '^- git-remote-match$' "$doctor_default_out"; then
    test_pass "repo-doctor quick default output is compact"
  else
    test_fail "repo-doctor quick default output is compact"
    status=1
  fi

  doctor_explain_out="$test_base/repo-doctor-quick-explain-$$.txt"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --quick --explain > "$doctor_explain_out"
  ) && grep -Eq '^PASS: git-branch - current branch:' "$doctor_explain_out"; then
    test_pass "repo-doctor quick explain output shows details"
  else
    test_fail "repo-doctor quick explain output shows details"
    status=1
  fi

  doctor_json_warn="$test_base/repo-doctor-quick-warn-$$.json"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --json --quick --json-level warn > "$doctor_json_warn"
  ) && python -m json.tool "$doctor_json_warn" >/dev/null && \
    smoke_json_assert "$doctor_json_warn" 'data.get("mode") == "quick" and data.get("json_level") == "warn" and any(check.get("status") == "warn" for check in data.get("checks", []))'; then
    test_pass "repo-doctor json quick warn is parseable"
  else
    test_fail "repo-doctor json quick warn is parseable"
    status=1
  fi

  doctor_log_file="$test_base/repo-doctor-log-$$.log"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --quick --log-file "$doctor_log_file" >/dev/null
  ) && [ -f "$doctor_log_file" ]; then
    test_pass "repo-doctor log-file creates a log"
  else
    test_fail "repo-doctor log-file creates a log"
    status=1
  fi

  doctor_no_log_file="$test_base/repo-doctor-no-log-$$.log"
  doctor_no_log_out="$test_base/repo-doctor-no-log-$$.txt"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --quick --log-file "$doctor_no_log_file" --no-log > "$doctor_no_log_out"
  ) && [ ! -e "$doctor_no_log_file" ] && ! grep -Eq '^Log:' "$doctor_no_log_out"; then
    test_pass "repo-doctor no-log does not create a log"
  else
    test_fail "repo-doctor no-log does not create a log"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --quick >/dev/null
  ); then
    test_pass "repo-doctor quick succeeds"
  else
    test_fail "repo-doctor quick succeeds"
    status=1
  fi

  doctor_json="$test_base/repo-doctor-quick-$$.json"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --json --quick > "$doctor_json"
  ) && python -m json.tool "$doctor_json" >/dev/null; then
    test_pass "repo-doctor json quick is parseable"
  else
    test_fail "repo-doctor json quick is parseable"
    status=1
  fi

  test_run_named_check "smoke:repo-doctor-missing-config"
  doctor_missing_json="$test_base/repo-doctor-missing-config-$$.json"
  if (
    cd "$test_dir" || return 1
    mv .repo-automation.conf .repo-automation.conf.bak || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --json --quick > "$doctor_missing_json"
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
      cd "$test_dir" || true
      [ -f .repo-automation.conf ] || mv .repo-automation.conf.bak .repo-automation.conf >/dev/null 2>&1 || true
    )
  fi
  rm -f "$doctor_json" "$doctor_missing_json" >/dev/null 2>&1 || true

  test_run_named_check "smoke:installer-apply-contract"
  install_target="$test_base/install-target-$$"
  install_target_remote="$test_base/install-target-$$-remote.git"
  mkdir -p "$install_target" || return 1
  (
    cd "$install_target" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-install-test" || return 1
    git config user.email "repo-automation-install-test@example.com" || return 1
    cp "$repo_root/README.md" README.md || return 1
    cp "$repo_root/VERSION" VERSION || return 1
    cp "$repo_root/CHANGELOG.md" CHANGELOG.md || return 1
    cp -R "$repo_root/docs" . || return 1
    cp -R "$repo_root/.github" . || return 1
    cp -R "$repo_root/examples" . || return 1
    git add -A || return 1
    git commit -m "init target" >/dev/null || return 1
    git init --bare --initial-branch=main "$install_target_remote" >/dev/null || return 1
    git remote add origin "$install_target_remote" || return 1
    git push -u origin main >/dev/null || return 1
  ) || status=1
  install_commit_count_before="$(git -C "$install_target" rev-list --count HEAD)"
  install_remote_head_before="$(git -C "$install_target_remote" rev-parse refs/heads/main)"

  install_plan_json="$test_base/repo-install-plan-$$.json"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-install --target "$install_target" --json > "$install_plan_json"
  ) && python -m json.tool "$install_plan_json" >/dev/null; then
    if smoke_json_assert "$install_plan_json" '"scripts/branch-cleanup" in data.get("files_to_add", []) and data.get("target_remote_status") == "unsupported"'; then
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
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-install --target "$install_target" --apply --dry-run >/dev/null
  ) && [ ! -f "$install_target/.repo-automation.conf" ]; then
    test_pass "repo-automation-install dry-run does not write files"
  else
    test_fail "repo-automation-install dry-run does not write files"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-install --target "$install_target" --apply --include-tests >/dev/null
  ) && [ -f "$install_target/.repo-automation.conf" ] && [ -f "$install_target/docs/repo-automation/README.md" ] && [ -f "$install_target/docs/repo-automation/local-overrides.md" ] && [ -f "$install_target/scripts/repo-doctor" ] && [ -f "$install_target/scripts/run-tests" ] && [ -f "$install_target/tests/smoke.sh" ] && [ -x "$install_target/scripts/repo-doctor" ] && [ -x "$install_target/scripts/run-tests" ] && [ -x "$install_target/tests/smoke.sh" ]; then
    test_pass "repo-automation-install apply creates managed files"
  else
    test_fail "repo-automation-install apply creates managed files"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    # shellcheck disable=SC1091
    source scripts/lib/repo-automation-common.sh && repo_auto_load_config >/dev/null && repo_auto_validate_required_config >/dev/null
  ); then
    test_pass "repo-automation-install installed config loads and validates"
  else
    test_fail "repo-automation-install installed config loads and validates"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --quick --no-run-tests >/dev/null
  ); then
    test_pass "repo-automation-install target repo-doctor quick/no-run-tests succeeds"
  else
    test_fail "repo-automation-install target repo-doctor quick/no-run-tests succeeds"
    status=1
  fi

  install_doctor_json="$test_base/repo-doctor-install-$$.json"
  if (
    cd "$install_target" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-doctor --json --quick --no-run-tests > "$install_doctor_json"
  ) && python -m json.tool "$install_doctor_json" >/dev/null && \
    smoke_json_assert "$install_doctor_json" 'data.get("overall_status") in ("pass", "warn") and any(check.get("status") == "warn" for check in data.get("checks", [])) and all(check.get("status") != "pass" for check in data.get("checks", []))'; then
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
    printf '# local override\n' > docs/repo-automation/local-overrides.md
  ); then
    :
  else
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/repo-automation-install --target "$install_target" --json > "$install_plan_json"
  ) && python -m json.tool "$install_plan_json" >/dev/null && \
    smoke_json_assert "$install_plan_json" 'data.get("mode") == "update"'; then
    test_pass "repo-automation-install second plan infers update mode"
  else
    test_fail "repo-automation-install second plan infers update mode"
    status=1
  fi

  if grep -q '^# local override$' "$install_target/docs/repo-automation/local-overrides.md"; then
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

  test_run_named_check "smoke:branch-cleanup-json"
  branch_json="$test_dir/branch-cleanup.json"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/branch-cleanup --json --plan > "$branch_json"
  ) && python -m json.tool "$branch_json" >/dev/null; then
    test_pass "branch-cleanup json is parseable"
  else
    test_fail "branch-cleanup json is parseable"
    status=1
  fi

  (
    cd "$test_dir" || return 1
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
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/branch-cleanup --json --plan > "$branch_json"
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

  if (
    cd "$test_dir" || return 1
    git checkout main >/dev/null || return 1
    timeout "${smoke_timeout_seconds}s" scripts/codex-slice-preflight --check-only --branch feature/preflight-smoke >/dev/null
  ); then
    test_pass "preflight check-only succeeds"
  else
    test_fail "preflight check-only succeeds"
    status=1
  fi

  test_run_named_check "smoke:preflight-json"
  preflight_json="$test_dir/preflight.json"
  if (
    cd "$test_dir" || return 1
    timeout "${smoke_timeout_seconds}s" scripts/codex-slice-preflight --json --check-only --branch feature/preflight-smoke > "$preflight_json"
  ) && python -m json.tool "$preflight_json" >/dev/null; then
    test_pass "preflight json is parseable"
  else
    test_fail "preflight json is parseable"
    status=1
  fi

  finish_stderr="$test_dir/pr-finish-stderr.log"
  if (
    cd "$test_dir" || return 1
    local_bash_path="$(command -v bash)" || return 1
    git rev-parse HEAD > "$test_dir/pre-head.txt" || return 1
    git branch --show-current > "$test_dir/pre-branch.txt" || return 1
    git status --porcelain --untracked-files=no > "$test_dir/pre-status.txt" || return 1
    shim_dir="$test_dir/no-gh-bin"
    mkdir -p "$shim_dir" || return 1
    ln -sf "$(command -v git)" "$shim_dir/git" || return 1
    ln -sf "$(command -v dirname)" "$shim_dir/dirname" || return 1
    ln -sf "$(command -v grep)" "$shim_dir/grep" || return 1
    PATH="$shim_dir" "$local_bash_path" scripts/pr-finish --plan >/dev/null 2> "$finish_stderr"
    return 1
  ); then
    test_fail "pr-finish no-auth/no-gh safe-failure path"
    status=1
  else
    if (
      cd "$test_dir" || return 1
      git rev-parse HEAD > "$test_dir/post-head.txt" || return 1
      git branch --show-current > "$test_dir/post-branch.txt" || return 1
      git status --porcelain --untracked-files=no > "$test_dir/post-status.txt" || return 1
      cmp -s "$test_dir/pre-head.txt" "$test_dir/post-head.txt" &&
        cmp -s "$test_dir/pre-branch.txt" "$test_dir/post-branch.txt" &&
        cmp -s "$test_dir/pre-status.txt" "$test_dir/post-status.txt" &&
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

smoke_main "$@"
# tests/smoke.sh EOF
