# repo-automation/tests/lib/contracts/pr-workflow.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



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

smoke_write_preflight_ssh_stub() {
  local ssh_stub_dir="$1"

  mkdir -p "$ssh_stub_dir" || return 1
  cat > "$ssh_stub_dir/ssh" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "-G" ]; then
  case "${2:-}" in
    github-alias)
      printf 'hostname github.com\n'
      ;;
    *)
      printf 'hostname example.com\n'
      ;;
  esac
  exit 0
fi
printf 'ssh stub unexpected args\n' >&2
exit 1
EOF
  chmod +x "$ssh_stub_dir/ssh" || return 1
}

smoke_check_add_doc_pr_docs_only() {
  local status=0
  local add_doc_pr_json="$smoke_test_base/add-doc-pr-plan-$$.json"
  local add_doc_pr_stderr="$smoke_test_base/add-doc-pr-plan-$$.stderr"
  local add_doc_pr_help="$smoke_test_base/add-doc-pr-help-$$.txt"
  local add_doc_pr_branch_format_stderr="$smoke_test_base/add-doc-pr-branch-format-$$.stderr"
  local add_doc_pr_branch_missing_stderr="$smoke_test_base/add-doc-pr-branch-missing-$$.stderr"
  local add_doc_pr_branch_empty_stderr="$smoke_test_base/add-doc-pr-branch-empty-$$.stderr"
  local add_doc_pr_unknown_stderr="$smoke_test_base/add-doc-pr-unknown-$$.stderr"
  local add_doc_pr_repo_automation_stderr="$smoke_test_base/add-doc-pr-repo-automation-$$.stderr"
  local add_doc_pr_create_json="$smoke_test_base/add-doc-pr-create-$$.json"
  local add_doc_pr_create_stderr="$smoke_test_base/add-doc-pr-create-$$.stderr"
  local add_doc_pr_create_body="$smoke_test_base/add-doc-pr-create-body.md"
  local add_doc_pr_create_repo="$smoke_test_base/add-doc-pr-create-repo"
  local add_doc_pr_plan_stdout="$smoke_test_base/add-doc-pr-plan.out"
  local add_doc_pr_plan_stderr="$smoke_test_base/add-doc-pr-plan.err"
  local add_doc_pr_run_tests_marker="$smoke_test_base/add-doc-pr-run-tests-called"
  local add_doc_pr_docs_check_marker="$smoke_test_base/add-doc-pr-docs-check-called"
  local add_doc_pr_failure_details=""
  local repo_doctor_help="$smoke_test_base/repo-doctor-help-$$.txt"
  local ci_log_dump_help="$smoke_test_base/ci-log-dump-help-$$.txt"
  local report_upstream_help="$smoke_test_base/report-upstream-help-$$.txt"
  local install_help="$smoke_test_base/repo-install-help-$$.txt"
  local pr_create_plan_stdout="$smoke_test_base/pr-create-plan.out"
  local pr_create_plan_stderr="$smoke_test_base/pr-create-plan.err"
  local pr_finish_help="$smoke_test_base/pr-finish-help-$$.txt"
  local branch_cleanup_help="$smoke_test_base/branch-cleanup-help-$$.txt"
  local preflight_explain_stdout="$smoke_test_base/preflight-explain.out"
  local preflight_explain_stderr="$smoke_test_base/preflight-explain.err"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/branch-cleanup --help > "$branch_cleanup_help"
  ) && grep -Fq -- '--explain' "$branch_cleanup_help"; then
    test_pass "branch-cleanup help succeeds"
  else
    test_fail "branch-cleanup help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-finish --help > "$pr_finish_help"
  ) && grep -Fq -- '--explain' "$pr_finish_help"; then
    test_pass "pr-finish help succeeds"
  else
    test_fail "pr-finish help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/add-doc-pr --help > "$add_doc_pr_help"
  ) && \
    grep -Fq -- '--branch=<name>' "$add_doc_pr_help" && \
    grep -Fq -- '--title=<text>' "$add_doc_pr_help" && \
    grep -Fq -- '--body-file=<path>' "$add_doc_pr_help" && \
    grep -Fq -- '--body=<text>' "$add_doc_pr_help" && \
    grep -Fq -- '--commit-message=<text>' "$add_doc_pr_help" && \
    grep -Fq -- '--allow=<path-prefix>' "$add_doc_pr_help" && \
    grep -Fq -- '--base=<branch>' "$add_doc_pr_help" && \
    grep -Fq -- '--explain' "$add_doc_pr_help" && \
    ! grep -Fq -- '--branch BRANCH' "$add_doc_pr_help" && \
    ! grep -Fq -- '--title TITLE' "$add_doc_pr_help" && \
    ! grep -Fq -- '--body-file FILE' "$add_doc_pr_help" && \
    ! grep -Fq -- '--body TEXT' "$add_doc_pr_help" && \
    ! grep -Fq -- '--commit-message MESSAGE' "$add_doc_pr_help" && \
    ! grep -Fq -- '--allow FILE_OR_DIR' "$add_doc_pr_help" && \
    ! grep -Fq -- '--base BRANCH' "$add_doc_pr_help"; then
    test_pass "add-doc-pr help shows strict value syntax"
  else
    test_fail "add-doc-pr help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --help > "$report_upstream_help"
  ) && grep -Fq -- '--type=<bug|feature>' "$report_upstream_help" && \
    grep -Fq -- '--explain' "$report_upstream_help" && \
    grep -Fq -- '--title=<text>' "$report_upstream_help" && \
    grep -Fq -- '--command=<text>' "$report_upstream_help" && \
    grep -Fq -- '--logs-file=<path>' "$report_upstream_help" && \
    ! grep -Fq -- '--type bug|feature' "$report_upstream_help" && \
    ! grep -Fq -- '--title TITLE' "$report_upstream_help" && \
    ! grep -Fq -- '--logs-file FILE' "$report_upstream_help"; then
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
    repo-automation/bin/repo-automation-install --help > "$install_help"
  ) && grep -Fq -- '--target=<path>' "$install_help" && \
    grep -Fq -- '--explain' "$install_help" && \
    grep -Fq -- '--installed-version=<ref>' "$install_help" && \
    grep -Fq -- '--source-root=<path>' "$install_help" && \
    ! grep -Fq -- '--target PATH' "$install_help" && \
    ! grep -Fq -- '--installed-version REF' "$install_help" && \
    ! grep -Fq -- '--source-root PATH' "$install_help"; then
    test_pass "repo-automation-install help succeeds"
  else
    test_fail "repo-automation-install help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --help > "$ci_log_dump_help"
  ) && grep -q 'Usage: repo-automation/bin/ci-log-dump' "$ci_log_dump_help" && grep -Fq -- '--quiet' "$ci_log_dump_help" && grep -Fq -- '--explain' "$ci_log_dump_help"; then
    test_pass "ci-log-dump help succeeds"
  else
    test_fail "ci-log-dump help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    mkdir -p docs || return 1
    printf 'docs only change\n' > docs/plan-doc.md || return 1
    repo-automation/bin/add-doc-pr \
      --plan \
      --json \
      --branch=docs/my-doc-update \
      --title=Docs \
      --body-file="$smoke_test_base/add-doc-pr-body.md" \
      --body=inline \
      --commit-message=docs:update \
      --allow=templates/ \
      --base=main \
      > "$add_doc_pr_json" 2> "$add_doc_pr_stderr"
  ) && python3 -m json.tool "$add_doc_pr_json" >/dev/null; then
    if smoke_json_assert "$add_doc_pr_json" 'data.get("branch") == "docs/my-doc-update" and data.get("base_branch") == "main" and "docs/plan-doc.md" in data.get("changed_files", []) and len(data.get("blocked_files", [])) == 0'; then
      test_pass "add-doc-pr docs-only plan/json succeeds"
    else
      if [ -s "$add_doc_pr_json" ]; then
        add_doc_pr_failure_details="$(python3 -c 'import json, pathlib, sys; data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")); print(" (changed_files=" + json.dumps(data.get("changed_files", [])) + "; blocked_files=" + json.dumps(data.get("blocked_files", [])) + ")")' "$add_doc_pr_json")"
      elif [ -s "$add_doc_pr_stderr" ]; then
        add_doc_pr_failure_details=" (stderr=$(tr '\n' ' ' < "$add_doc_pr_stderr"))"
      fi
      test_fail "add-doc-pr docs-only plan/json succeeds${add_doc_pr_failure_details}"
      status=1
    fi
  else
    if [ -s "$add_doc_pr_json" ]; then
      add_doc_pr_failure_details="$(python3 -c 'import json, pathlib, sys; data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")); print(" (changed_files=" + json.dumps(data.get("changed_files", [])) + "; blocked_files=" + json.dumps(data.get("blocked_files", [])) + ")")' "$add_doc_pr_json")"
    elif [ -s "$add_doc_pr_stderr" ]; then
      add_doc_pr_failure_details=" (stderr=$(tr '\n' ' ' < "$add_doc_pr_stderr"))"
    fi
    test_fail "add-doc-pr docs-only plan/json succeeds${add_doc_pr_failure_details}"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/add-doc-pr --plan > "$add_doc_pr_plan_stdout" 2> "$add_doc_pr_plan_stderr"
  ) && [ "$(cat "$add_doc_pr_plan_stdout")" = "plan" ] && [ ! -s "$add_doc_pr_plan_stderr" ]; then
    test_pass "add-doc-pr plan output is compact"
  else
    test_fail "add-doc-pr plan output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    mkdir -p repo-automation/docs || return 1
    printf 'smoke coverage review\n' > repo-automation/docs/add-doc-pr-coverage-smoke.md || return 1
    repo-automation/bin/add-doc-pr \
      --plan \
      --json \
      --allow=repo-automation/ \
      > "$add_doc_pr_json" 2> "$add_doc_pr_repo_automation_stderr"
  ); then
    test_fail "add-doc-pr blocks new repo-automation paths without coverage review"
    status=1
  elif grep -Fq 'coverage review required for repo-automation path changes' "$add_doc_pr_repo_automation_stderr"; then
    test_pass "add-doc-pr blocks new repo-automation paths without coverage review"
  else
    test_fail "add-doc-pr blocks new repo-automation paths without coverage review"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f repo-automation/docs/add-doc-pr-coverage-smoke.md || return 1
    cp -R "$smoke_test_dir" "$add_doc_pr_create_repo" || return 1
    (
      cd "$add_doc_pr_create_repo" || return 1
      git config user.name "repo-automation-test" || return 1
      git config user.email "repo-automation-test@example.com" || return 1
      cat > repo-automation/tests/docs-check.sh <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail
printf 'docs-check output\\n'
: > "$add_doc_pr_docs_check_marker"
exit 0
EOF
      chmod +x repo-automation/tests/docs-check.sh || return 1
      cat > repo-automation/bin/run-tests <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail
: > "$add_doc_pr_run_tests_marker"
exit 1
EOF
      chmod +x repo-automation/bin/run-tests || return 1
      git add repo-automation/tests/docs-check.sh repo-automation/bin/run-tests || return 1
      git commit -m "test: stub docs-check and run-tests" >/dev/null 2>&1 || return 1
      mkdir -p docs || return 1
      printf 'docs only change\n' > docs/plan-doc.md || return 1
      printf 'body text\n' > "$add_doc_pr_create_body" || return 1
      repo-automation/bin/add-doc-pr \
        --dry-run \
        --create-pr \
        --json \
        --branch=docs/my-doc-update-create \
        --title=Docs \
        --body-file="$add_doc_pr_create_body" \
        --commit-message=docs:update \
        --base=main \
        > "$add_doc_pr_create_json" 2> "$add_doc_pr_create_stderr"
    )
  ) && python3 -m json.tool "$add_doc_pr_create_json" >/dev/null && \
    smoke_json_assert "$add_doc_pr_create_json" 'data.get("checks_run") is True' && \
    ! grep -Fq 'docs-check output' "$add_doc_pr_create_stderr" && \
    [ -f "$add_doc_pr_docs_check_marker" ] && \
    [ ! -e "$add_doc_pr_run_tests_marker" ]; then
    test_pass "add-doc-pr dry-run create-pr validates docs-only changes"
  else
    if [ -s "$add_doc_pr_create_json" ]; then
      add_doc_pr_failure_details="$(python3 -c 'import json, pathlib, sys; data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")); print(" (checks_run=" + json.dumps(data.get("checks_run")) + "; action_taken=" + json.dumps(data.get("action_taken")) + "; stop_reason=" + json.dumps(data.get("stop_reason")) + "; changed_files=" + json.dumps(data.get("changed_files", [])) + "; blocked_files=" + json.dumps(data.get("blocked_files", [])) + ")")' "$add_doc_pr_create_json")"
    elif [ -s "$add_doc_pr_create_stderr" ]; then
      add_doc_pr_failure_details=" (stderr=$(tr '\n' ' ' < "$add_doc_pr_create_stderr"))"
    fi
    test_fail "add-doc-pr dry-run create-pr validates docs-only changes"
    status=1
  fi

  rm -rf "$add_doc_pr_create_repo" >/dev/null 2>&1 || true
  rm -f "$add_doc_pr_docs_check_marker" "$add_doc_pr_run_tests_marker" "$add_doc_pr_create_body" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    rm -f repo-automation/docs/add-doc-pr-coverage-smoke.md || return 1
  ); then
    :
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/add-doc-pr --branch docs/my-doc-update >/dev/null 2> "$add_doc_pr_branch_format_stderr"
  ); then
    test_fail "add-doc-pr rejects --branch <name>"
    status=1
  elif smoke_assert_flag_error_shape "$add_doc_pr_branch_format_stderr" "flag format not accepted" "--branch" "use --branch=<name>"; then
    test_pass "add-doc-pr rejects --branch <name>"
  else
    test_fail "add-doc-pr rejects --branch <name>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/add-doc-pr --branch >/dev/null 2> "$add_doc_pr_branch_missing_stderr"
  ); then
    test_fail "add-doc-pr rejects missing --branch value"
    status=1
  elif smoke_assert_flag_error_shape "$add_doc_pr_branch_missing_stderr" "missing flag value" "--branch" "use --branch=<name>"; then
    test_pass "add-doc-pr rejects missing --branch value"
  else
    test_fail "add-doc-pr rejects missing --branch value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/add-doc-pr --branch= >/dev/null 2> "$add_doc_pr_branch_empty_stderr"
  ); then
    test_fail "add-doc-pr rejects empty --branch value"
    status=1
  elif smoke_assert_flag_error_shape "$add_doc_pr_branch_empty_stderr" "empty flag value" "--branch" "use --branch=<name>"; then
    test_pass "add-doc-pr rejects empty --branch value"
  else
    test_fail "add-doc-pr rejects empty --branch value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/add-doc-pr --whatever >/dev/null 2> "$add_doc_pr_unknown_stderr"
  ); then
    test_fail "add-doc-pr rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$add_doc_pr_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/add-doc-pr --help"; then
    test_pass "add-doc-pr rejects unknown flags"
  else
    test_fail "add-doc-pr rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f docs/plan-doc.md || return 1
  ); then
    :
  fi

  rm -f "$add_doc_pr_json" "$add_doc_pr_stderr" "$add_doc_pr_create_json" "$add_doc_pr_create_stderr" "$add_doc_pr_plan_stdout" "$add_doc_pr_plan_stderr" "$branch_cleanup_help" "$pr_finish_help" "$repo_doctor_help" "$ci_log_dump_help" "$report_upstream_help" "$install_help" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_add_doc_pr_blocked_file() {
  local status=0
  local add_doc_pr_block_json="$smoke_test_base/add-doc-pr-blocked-$$.json"
  local add_doc_pr_block_stderr="$smoke_test_base/add-doc-pr-blocked-$$.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    printf '0.1.1\n' > VERSION || return 1
    repo-automation/bin/add-doc-pr --plan --json > "$add_doc_pr_block_json" 2> "$add_doc_pr_block_stderr"
    return 1
  ); then
    test_fail "add-doc-pr blocks repo-automation/ boundary changes in plan mode"
    status=1
  else
    if python3 -m json.tool "$add_doc_pr_block_json" >/dev/null && \
      smoke_json_assert "$add_doc_pr_block_json" '"VERSION" in data.get("blocked_files", [])' && \
      grep -Fq 'STOP: docs-only boundary violation' "$add_doc_pr_block_stderr"; then
      test_pass "add-doc-pr blocks repo-automation/ boundary changes in plan mode"
    else
      test_fail "add-doc-pr blocks repo-automation/ boundary changes in plan mode"
      status=1
    fi
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -- VERSION >/dev/null 2>&1 || return 1
  ); then
    :
  fi

  rm -f "$add_doc_pr_block_json" "$add_doc_pr_block_stderr" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_pr_create_body_file() {
  local status=0
  local branch_name="feature/pr-create-body-file"
  local helper_json="$smoke_test_base/pr-create-body-file.json"
  local helper_log="$smoke_test_base/pr-create-body-file.log"
  local helper_body="$smoke_test_base/pr-create-body-file-body.md"
  local helper_body_copy="$smoke_test_base/pr-create-body-file-body-copy.md"
  local helper_help="$smoke_test_base/pr-create-help-$$.txt"
  local branch_format_stderr="$smoke_test_base/pr-create-branch-format-$$.stderr"
  local branch_missing_stderr="$smoke_test_base/pr-create-branch-missing-$$.stderr"
  local branch_empty_stderr="$smoke_test_base/pr-create-branch-empty-$$.stderr"
  local unknown_stderr="$smoke_test_base/pr-create-unknown-$$.stderr"
  local pr_create_plan_stdout="$smoke_test_base/pr-create-plan.out"
  local pr_create_plan_stderr="$smoke_test_base/pr-create-plan.err"
  local pr_create_explain_stderr="$smoke_test_base/pr-create-explain.err"
  local gh_stub_dir="$smoke_test_base/gh-pr-create-stub"
  local body_text=$'## Scope\n\nMixed change body-file scope.\n\n## What changed\n\n- Updated the tracked fixture.\n\n## What did not change\n\n- No unrelated files.\n\n## Verification status\n\n- pr-create contract smoke check\n\n## User-visible behavior changes\n\nNone\n\n## Stop conditions encountered\n\nNone\n\n## Re-entry hint\n\nUse the PR URL, watch CI, and finish with pr-finish after checks pass.\n'

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-create --help > "$helper_help"
  ) && \
    grep -Fq -- '--branch=<name>' "$helper_help" && \
    grep -Fq -- '--base=<branch>' "$helper_help" && \
    grep -Fq -- '--title=<text>' "$helper_help" && \
    grep -Fq -- '--body-file=<path>' "$helper_help" && \
    grep -Fq -- '--explain' "$helper_help" && \
    grep -Fq -- '--body=<text>' "$helper_help" && \
    ! grep -Fq -- '--branch BRANCH' "$helper_help" && \
    ! grep -Fq -- '--base BRANCH' "$helper_help" && \
    ! grep -Fq -- '--title TITLE' "$helper_help" && \
    ! grep -Fq -- '--body-file FILE' "$helper_help" && \
    ! grep -Fq -- '--body TEXT' "$helper_help"; then
    test_pass "pr-create help shows strict value syntax"
  else
    test_fail "pr-create help shows strict value syntax"
    status=1
  fi

  smoke_pr_create_prepare_branch "$branch_name" repo-automation/tests/pr-create-body-file.txt "body file fixture" || return 1
  printf '%s' "$body_text" > "$helper_body" || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$helper_log" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$helper_body_copy" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/321' \
    GH_STUB_PR_VIEW_NUMBER=321 \
    repo-automation/bin/pr-create --json --branch="$branch_name" --base=main --title="Mixed change body file" --body-file="$helper_body" > "$helper_json"
  ) && python3 -m json.tool "$helper_json" >/dev/null && \
    smoke_json_assert "$helper_json" 'data.get("action_taken") == "created-pr" and data.get("pr_number") == "321" and data.get("pr_url") == "https://github.com/i-schuyler/repo-automation-template/pull/321" and data.get("branch") == "feature/pr-create-body-file" and data.get("base_branch") == "main"'; then
    if grep -Fq 'gh pr create title=Mixed change body file base=main head=feature/pr-create-body-file body_file=' "$helper_log" && cmp -s "$helper_body" "$helper_body_copy" && repo-automation/bin/pr-body-check --quiet --body-file="$helper_body" >/dev/null; then
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
    repo-automation/bin/pr-create --dry-run --branch="$branch_name" --base=main --title="Mixed change body file" --body-file="$helper_body" > "$pr_create_plan_stdout" 2> "$pr_create_plan_stderr"
  ) && [ "$(cat "$pr_create_plan_stdout")" = "plan" ] && [ ! -s "$pr_create_plan_stderr" ]; then
    test_pass "pr-create dry-run output is compact"
  else
    test_fail "pr-create dry-run output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-create --dry-run --explain --branch="$branch_name" --base=main --title="Mixed change body file" --body-file="$helper_body" > /dev/null 2> "$pr_create_explain_stderr"
  ) && grep -Fxq '===== FINAL SUMMARY =====' "$pr_create_explain_stderr" && grep -Eq '^branch=feature/pr-create-body-file$' "$pr_create_explain_stderr" && grep -Eq '^rc=0$' "$pr_create_explain_stderr" && grep -Eq '^url_or_stop=dry-run$' "$pr_create_explain_stderr" && grep -Fxq '===== END =====' "$pr_create_explain_stderr"; then
    test_pass "pr-create explain output ends with FINAL SUMMARY"
  else
    test_fail "pr-create explain output ends with FINAL SUMMARY"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-create --branch "$branch_name" --title="Mixed change body file" --body-file="$helper_body" >/dev/null 2> "$branch_format_stderr"
  ); then
    test_fail "pr-create rejects --branch <name>"
    status=1
  elif smoke_assert_flag_error_shape "$branch_format_stderr" "flag format not accepted" "--branch" "use --branch=<name>"; then
    test_pass "pr-create rejects --branch <name>"
  else
    test_fail "pr-create rejects --branch <name>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-create --branch --title="Mixed change body file" --body-file="$helper_body" >/dev/null 2> "$branch_missing_stderr"
  ); then
    test_fail "pr-create rejects missing --branch value"
    status=1
  elif smoke_assert_flag_error_shape "$branch_missing_stderr" "missing flag value" "--branch" "use --branch=<name>"; then
    test_pass "pr-create rejects missing --branch value"
  else
    test_fail "pr-create rejects missing --branch value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-create --branch= --title="Mixed change body file" --body-file="$helper_body" >/dev/null 2> "$branch_empty_stderr"
  ); then
    test_fail "pr-create rejects empty --branch value"
    status=1
  elif smoke_assert_flag_error_shape "$branch_empty_stderr" "empty flag value" "--branch" "use --branch=<name>"; then
    test_pass "pr-create rejects empty --branch value"
  else
    test_fail "pr-create rejects empty --branch value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-create --whatever >/dev/null 2> "$unknown_stderr"
  ); then
    test_fail "pr-create rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/pr-create --help"; then
    test_pass "pr-create rejects unknown flags"
  else
    test_fail "pr-create rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git checkout main >/dev/null 2>&1 || return 1
    git branch -D "$branch_name" >/dev/null 2>&1 || return 1
  ); then
    :
  fi

  rm -f "$helper_json" "$helper_log" "$helper_body" "$helper_body_copy" "$helper_help" "$branch_format_stderr" "$branch_missing_stderr" "$branch_empty_stderr" "$unknown_stderr" "$pr_create_plan_stdout" "$pr_create_plan_stderr" >/dev/null 2>&1 || true
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
  local body_text=$'## Scope\n\nMixed inline body scope.\n\n## What changed\n\n- Updated the tracked fixture.\n\n## What did not change\n\n- No unrelated files.\n\n## Verification status\n\n- pr-create contract smoke check\n\n## User-visible behavior changes\n\nNone\n\n## Stop conditions encountered\n\nNone\n\n## Re-entry hint\n\nUse the PR URL, watch CI, and finish with pr-finish after checks pass.\n'

  smoke_pr_create_prepare_branch "$branch_name" repo-automation/tests/pr-create-body-text.txt "body text fixture" || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$helper_log" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$helper_body_copy" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/322' \
    GH_STUB_PR_VIEW_NUMBER=322 \
    repo-automation/bin/pr-create --json --branch="$branch_name" --base=main --title="Mixed change body text" --body="$body_text" > "$helper_json"
  ) && python3 -m json.tool "$helper_json" >/dev/null && \
    smoke_json_assert "$helper_json" 'data.get("action_taken") == "created-pr" and data.get("pr_number") == "322" and data.get("pr_url") == "https://github.com/i-schuyler/repo-automation-template/pull/322" and data.get("branch") == "feature/pr-create-body-text" and data.get("base_branch") == "main"'; then
    if grep -Fq 'gh pr create title=Mixed change body text base=main head=feature/pr-create-body-text body_file=' "$helper_log" && printf '%s\n' "$body_text" | cmp -s - "$helper_body_copy" && repo-automation/bin/pr-body-check --quiet --body-file="$helper_body_copy" >/dev/null; then
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

smoke_check_pr_body_check_contract() {
  local status=0
  local valid_body="$smoke_test_base/pr-body-check-valid.md"
  local scaffold_body="$smoke_test_base/pr-body-check-scaffold.md"
  local duplicate_body="$smoke_test_base/pr-body-check-duplicate.md"
  local order_body="$smoke_test_base/pr-body-check-order.md"
  local passive_body="$smoke_test_base/pr-body-check-passive.md"
  local missing_body="$smoke_test_base/pr-body-check-missing.md"
  local helper_help="$smoke_test_base/pr-body-check-help-$$.txt"
  local helper_stdout="$smoke_test_base/pr-body-check.out"
  local helper_stderr="$smoke_test_base/pr-body-check.err"

  cat > "$valid_body" <<'EOF'
## Scope

Mixed change scope.

## What changed

- Updated the tracked fixture.

## What did not change

- No unrelated files.

## Verification status

- pr-body-check contract smoke check

## User-visible behavior changes

None

## Stop conditions encountered

None

## Re-entry hint

Use the PR URL, watch CI, and finish with pr-finish after checks pass.
EOF

  cat > "$scaffold_body" <<'EOF'
## Scope

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## What changed

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## What did not change

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## Verification status

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## User-visible behavior changes

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## Stop conditions encountered

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## Re-entry hint

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0
EOF

  cat > "$duplicate_body" <<'EOF'
## Scope

Duplicate scope.

## Scope

Duplicate scope again.

## What changed

- Duplicate heading fixture.

## What did not change

- No unrelated files.

## Verification status

- pr-body-check contract smoke check

## User-visible behavior changes

None

## Stop conditions encountered

None

## Re-entry hint

Use the PR URL, watch CI, and finish with pr-finish after checks pass.
EOF

  cat > "$order_body" <<'EOF'
## What changed

- Out of order fixture.

## Scope

Out of order scope.

## What did not change

- No unrelated files.

## Verification status

- pr-body-check contract smoke check

## User-visible behavior changes

None

## Stop conditions encountered

None

## Re-entry hint

Use the PR URL, watch CI, and finish with pr-finish after checks pass.
EOF

  cat > "$passive_body" <<'EOF'
## Scope

Mixed change scope.

## What changed

- Updated the tracked fixture.

## What did not change

- No unrelated files.

## Verification status

- pr-body-check contract smoke check

## User-visible behavior changes

None

## Stop conditions encountered

None

## Re-entry hint

Use the PR URL, watch CI, and finish with pr-finish after checks pass.

## Passive monetization angle

None
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --help > "$helper_help"
  ) && grep -Fq -- '--body-file=<path>' "$helper_help" && grep -Fq -- '--quiet' "$helper_help"; then
    test_pass "pr-body-check help shows strict syntax"
  else
    test_fail "pr-body-check help shows strict syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$valid_body" > "$helper_stdout" 2> "$helper_stderr"
  ) && [ "$(cat "$helper_stdout")" = "pass" ] && [ ! -s "$helper_stderr" ]; then
    test_pass "pr-body-check default output is compact"
  else
    test_fail "pr-body-check default output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --quiet --body-file="$valid_body" > "$helper_stdout" 2> "$helper_stderr"
  ) && [ ! -s "$helper_stdout" ] && [ ! -s "$helper_stderr" ]; then
    test_pass "pr-body-check quiet success is silent"
  else
    test_fail "pr-body-check quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file "$valid_body" > "$helper_stdout" 2> "$helper_stderr"
  ); then
    test_fail "pr-body-check rejects space-separated body-file syntax"
    status=1
  elif grep -Fxq 'fail: flag format not accepted: --body-file' "$helper_stderr" && grep -Fxq 'fix: use --body-file=<path>' "$helper_stderr"; then
    test_pass "pr-body-check rejects space-separated body-file syntax"
  else
    test_fail "pr-body-check rejects space-separated body-file syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file= > "$helper_stdout" 2> "$helper_stderr"
  ); then
    test_fail "pr-body-check rejects empty body-file values"
    status=1
  elif grep -Fxq 'fail: empty flag value: --body-file' "$helper_stderr" && grep -Fxq 'fix: use --body-file=<path>' "$helper_stderr"; then
    test_pass "pr-body-check rejects empty body-file values"
  else
    test_fail "pr-body-check rejects empty body-file values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$missing_body" > "$helper_stdout" 2> "$helper_stderr"
  ); then
    test_fail "pr-body-check rejects missing body files"
    status=1
  elif grep -Fxq "fail: body file does not exist: $missing_body" "$helper_stderr" && grep -Fxq 'fix: provide an existing PR body file' "$helper_stderr"; then
    test_pass "pr-body-check rejects missing body files"
  else
    test_fail "pr-body-check rejects missing body files"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$scaffold_body" > "$helper_stdout" 2> "$helper_stderr"
  ); then
    test_fail "pr-body-check rejects placeholder-only bodies"
    status=1
  elif grep -Fxq 'fail: body is placeholder-only' "$helper_stderr" && grep -Fxq 'fix: replace branch/base/ahead/behind scaffolding with real PR body content' "$helper_stderr"; then
    test_pass "pr-body-check rejects placeholder-only bodies"
  else
    test_fail "pr-body-check rejects placeholder-only bodies"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$duplicate_body" > "$helper_stdout" 2> "$helper_stderr"
  ); then
    test_fail "pr-body-check rejects duplicate headings"
    status=1
  elif grep -Fxq 'fail: heading appears more than once: ## Scope' "$helper_stderr" && grep -Fxq 'fix: keep each required heading exactly once' "$helper_stderr"; then
    test_pass "pr-body-check rejects duplicate headings"
  else
    test_fail "pr-body-check rejects duplicate headings"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$order_body" > "$helper_stdout" 2> "$helper_stderr"
  ); then
    test_fail "pr-body-check rejects out-of-order headings"
    status=1
  elif grep -Fxq 'fail: required headings are out of order' "$helper_stderr" && grep -Fxq 'fix: reorder the headings to match the canonical contract' "$helper_stderr"; then
    test_pass "pr-body-check rejects out-of-order headings"
  else
    test_fail "pr-body-check rejects out-of-order headings"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$passive_body" > "$helper_stdout" 2> "$helper_stderr"
  ); then
    test_fail "pr-body-check rejects passive monetization headings"
    status=1
  elif grep -Fxq 'fail: forbidden heading present: ## Passive monetization angle' "$helper_stderr" && grep -Fxq 'fix: remove the passive monetization section' "$helper_stderr"; then
    test_pass "pr-body-check rejects passive monetization headings"
  else
    test_fail "pr-body-check rejects passive monetization headings"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --quiet --body-file=.github/pull_request_template.md > "$helper_stdout" 2> "$helper_stderr"
  ) && [ ! -s "$helper_stdout" ] && [ ! -s "$helper_stderr" ]; then
    test_pass "pr-body-check accepts the committed PR template"
  else
    test_fail "pr-body-check accepts the committed PR template"
    status=1
  fi

  rm -f "$valid_body" "$scaffold_body" "$duplicate_body" "$order_body" "$passive_body" "$missing_body" "$helper_help" "$helper_stdout" "$helper_stderr" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_branch_cleanup_json() {
  local status=0
  local branch_json="$smoke_test_dir/branch-cleanup.json"
  local branch_plan_stdout="$smoke_test_base/branch-cleanup-plan-$$.txt"
  local unknown_flag_stderr="$smoke_test_base/branch-cleanup-unknown.stderr"
  local start_branch=""

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/branch-cleanup --json --plan > "$branch_json"
  ) && python3 -m json.tool "$branch_json" >/dev/null; then
    test_pass "branch-cleanup json is parseable"
  else
    test_fail "branch-cleanup json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/branch-cleanup --plan > "$branch_plan_stdout"
  ) && [ "$(cat "$branch_plan_stdout")" = "plan" ]; then
    test_pass "branch-cleanup plan output is compact"
  else
    test_fail "branch-cleanup plan output is compact"
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

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/branch-cleanup --whatever >/dev/null 2> "$unknown_flag_stderr"
  ); then
    test_fail "branch-cleanup rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_flag_stderr" "unknown flag" "--whatever" "run repo-automation/bin/branch-cleanup --help"; then
    test_pass "branch-cleanup rejects unknown flags"
  else
    test_fail "branch-cleanup rejects unknown flags"
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

  rm -f "$branch_json" "$branch_plan_stdout" "$unknown_flag_stderr" >/dev/null 2>&1 || true

  return "$status"
}

smoke_check_preflight_json() {
  local status=0
  local preflight_json="$smoke_test_dir/preflight.json"
  local preflight_help="$smoke_test_dir/preflight-help.txt"
  local finish_stderr="$smoke_test_dir/pr-finish-stderr.log"
  local branch_format_stderr="$smoke_test_dir/preflight-branch-format.stderr"
  local branch_missing_stderr="$smoke_test_dir/preflight-branch-missing.stderr"
  local branch_empty_stderr="$smoke_test_dir/preflight-branch-empty.stderr"
  local branch_unknown_stderr="$smoke_test_dir/preflight-branch-unknown.stderr"
  local preflight_explain_stdout="$smoke_test_dir/preflight-explain.out"
  local preflight_explain_stderr="$smoke_test_dir/preflight-explain.err"
  local preflight_alias_explain_stderr="$smoke_test_dir/preflight-alias-explain.err"
  local preflight_stale_branch="feature/preflight-stale"
  local preflight_stale_branch_explain_stderr="$smoke_test_dir/preflight-stale-branch-explain.err"
  local preflight_stale_repo="$smoke_test_base/preflight-stale-repo-$$"
  local preflight_low_disk_stub_dir="$smoke_test_base/preflight-low-disk-stub"
  local preflight_low_disk_explain_stderr="$smoke_test_base/preflight-low-disk.err"
  local preflight_clean_tmpdir="$smoke_test_base/preflight-clean-tmp"
  local preflight_clean_home="$smoke_test_base/preflight-clean-home"
  local preflight_clean_stdout="$smoke_test_base/preflight-clean.out"
  local preflight_clean_stderr="$smoke_test_base/preflight-clean.err"
  local preflight_clean_branch="feature/preflight-clean-cache-branch"
  local preflight_clean_branch_stderr="$smoke_test_base/preflight-clean-branch.err"
  local preflight_clean_branch_repo="$smoke_test_base/preflight-clean-repo-$$"
  local local_bash_path=""
  local shim_dir=""
  local ssh_stub_dir="$smoke_test_base/preflight-ssh-stub"

  if (
    cd "$smoke_test_dir" || return 1
    git checkout main >/dev/null || return 1
    repo-automation/bin/codex-slice-preflight --check-only --branch=feature/preflight-smoke >/dev/null
  ); then
    test_pass "preflight check-only succeeds"
  else
    test_fail "preflight check-only succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --json --check-only --branch=feature/preflight-smoke > "$preflight_json"
  ) && python3 -m json.tool "$preflight_json" >/dev/null; then
    test_pass "preflight json is parseable"
  else
    test_fail "preflight json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --help > "$preflight_help"
  ) && grep -Fq -- '--branch=<name>' "$preflight_help" && grep -Fq -- '--explain' "$preflight_help" && ! grep -Fq -- '--branch BRANCH' "$preflight_help"; then
    test_pass "preflight help shows strict branch syntax"
  else
    test_fail "preflight help shows strict branch syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git reset --hard >/dev/null 2>&1 || return 1
    git clean -fd >/dev/null 2>&1 || return 1
    repo-automation/bin/codex-slice-preflight --check-only --branch=feature/preflight-smoke > "$preflight_explain_stdout" 2> "$preflight_explain_stderr"
  ) && [ "$(cat "$preflight_explain_stdout")" = "pass" ]; then
    test_pass "preflight default human output is compact"
  else
    test_fail "preflight default human output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cp -R "$smoke_test_dir" "$preflight_stale_repo" || return 1
    cd "$preflight_stale_repo" || return 1
    git reset --hard >/dev/null 2>&1 || return 1
    git clean -fd >/dev/null 2>&1 || return 1
    git checkout main >/dev/null 2>&1 || return 1
    git branch -D "$preflight_stale_branch" >/dev/null 2>&1 || true
    git switch -c "$preflight_stale_branch" >/dev/null 2>&1 || return 1
    printf '\nstale branch note\n' >> README.md || return 1
    git add README.md || return 1
    git commit -m "test: stale preflight branch" >/dev/null 2>&1 || return 1
    git checkout main >/dev/null 2>&1 || return 1
    printf '\nmain advances after branch creation\n' >> README.md || return 1
    git add README.md || return 1
    git commit -m "test: advance main after stale branch" >/dev/null 2>&1 || return 1
    git update-index --skip-worktree .repo-automation.conf || return 1
    python3 - "$smoke_expected_origin_url" .repo-automation.conf <<'PY' || return 1
import pathlib
import sys

expected = sys.argv[1]
config_path = pathlib.Path(sys.argv[2])
text = config_path.read_text(encoding="utf-8")
old = f'EXPECTED_REMOTE_URL="{expected}"'
new = 'EXPECTED_REMOTE_URL=""'
if old not in text:
    raise SystemExit(1)
config_path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
    git remote set-url origin "$smoke_remote_dir" >/dev/null 2>&1 || return 1
    git push origin main >/dev/null 2>&1 || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    git checkout "$preflight_stale_branch" >/dev/null 2>&1 || return 1
    repo-automation/bin/codex-slice-preflight --branch="$preflight_stale_branch" --explain > /dev/null 2> "$preflight_stale_branch_explain_stderr"
  ); then
    test_fail "preflight stops on an existing branch behind origin/main"
    status=1
  elif grep -Fxq '===== FINAL SUMMARY =====' "$preflight_stale_branch_explain_stderr" &&
    grep -Fxq 'script=codex-slice-preflight' "$preflight_stale_branch_explain_stderr" &&
    grep -Eq '^rc=1$' "$preflight_stale_branch_explain_stderr" &&
    grep -Fq 'STOP: existing branch is behind origin/main:' "$preflight_stale_branch_explain_stderr" &&
    grep -Fq 'recreate, reset, or rebase it' "$preflight_stale_branch_explain_stderr" &&
    grep -Fxq '===== END =====' "$preflight_stale_branch_explain_stderr"; then
    test_pass "preflight stops on an existing branch behind origin/main"
  else
    test_fail "preflight stops on an existing branch behind origin/main"
    status=1
  fi

  smoke_write_preflight_ssh_stub "$ssh_stub_dir" || return 1
  if (
    cd "$smoke_test_dir" || return 1
    git remote set-url origin 'git@github-alias:i-schuyler/repo-automation-template.git' >/dev/null 2>&1 || return 1
    PATH="$ssh_stub_dir:$PATH" repo-automation/bin/codex-slice-preflight --check-only --branch=feature/preflight-smoke --explain > /dev/null 2> "$preflight_alias_explain_stderr"
  ) && disk_free_line="$(grep -n -m1 '^disk_free=' "$preflight_alias_explain_stderr" | cut -d: -f1)" &&
    disk_threshold_line="$(grep -n -m1 '^disk_threshold=' "$preflight_alias_explain_stderr" | cut -d: -f1)" &&
    url_line="$(grep -n -m1 '^url_or_stop=' "$preflight_alias_explain_stderr" | cut -d: -f1)" &&
    grep -Fxq '===== FINAL SUMMARY =====' "$preflight_alias_explain_stderr" && grep -Fxq 'script=codex-slice-preflight' "$preflight_alias_explain_stderr" && grep -Eq '^mode=check-only$' "$preflight_alias_explain_stderr" && grep -Eq '^rc=0$' "$preflight_alias_explain_stderr" && grep -Fxq 'disk=pass' "$preflight_alias_explain_stderr" && grep -Eq '^disk_free=[0-9]+(\.[0-9])?(B|KiB|MiB|GiB|TiB|PiB|EiB)$' "$preflight_alias_explain_stderr" && grep -Fxq 'disk_threshold=1.5GiB' "$preflight_alias_explain_stderr" && grep -Eq '^disk_used=[0-9]+%$' "$preflight_alias_explain_stderr" && grep -Eq '^disk_available=[0-9]+%$' "$preflight_alias_explain_stderr" && ! grep -Fq 'cleanup_command=' "$preflight_alias_explain_stderr" && [ "$disk_free_line" -lt "$url_line" ] && [ "$disk_threshold_line" -lt "$url_line" ] && grep -Eq '^branch_before=main$' "$preflight_alias_explain_stderr" && grep -Eq '^branch_after=main$' "$preflight_alias_explain_stderr" && grep -Eq '^default_branch=main$' "$preflight_alias_explain_stderr" && grep -Eq '^divergence=[0-9]+[[:space:]][0-9]+$|^divergence=unknown$' "$preflight_alias_explain_stderr" && grep -Eq '^status_count=[0-9]+$' "$preflight_alias_explain_stderr" && grep -Eq '^url_or_stop=pass$' "$preflight_alias_explain_stderr" && grep -Fxq '===== END =====' "$preflight_alias_explain_stderr"; then
    test_pass "preflight explain output ends with FINAL SUMMARY"
  else
    test_fail "preflight explain output ends with FINAL SUMMARY"
    status=1
  fi

  mkdir -p "$preflight_low_disk_stub_dir" || return 1
  cat > "$preflight_low_disk_stub_dir/df" <<'EOF'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  -P*) shift ;;
esac
if [ "${1:-}" = "-k" ]; then
  shift
fi
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
printf 'stubfs %s %s %s %s%% %s\n' \
  "${PREFLIGHT_DF_BLOCKS:-1000000}" \
  "${PREFLIGHT_DF_USED:-840000}" \
  "${PREFLIGHT_DF_AVAILABLE:-1024}" \
  "${PREFLIGHT_DF_USE_PERCENT:-84}" \
  "${1:-${PREFLIGHT_DF_MOUNTPOINT:-/}}"
EOF
  chmod +x "$preflight_low_disk_stub_dir/df" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_DF_BIN="$preflight_low_disk_stub_dir/df" \
      PREFLIGHT_DF_BLOCKS=1000000 \
      PREFLIGHT_DF_USED=840000 \
      PREFLIGHT_DF_AVAILABLE=1048576 \
      PREFLIGHT_DF_USE_PERCENT=84 \
      repo-automation/bin/codex-slice-preflight --check-only --branch=feature/preflight-smoke --explain > /dev/null 2> "$preflight_low_disk_explain_stderr"
  ); then
    test_fail "preflight stops before branch setup on low disk"
    status=1
  elif grep -Fxq '===== FINAL SUMMARY =====' "$preflight_low_disk_explain_stderr" &&
    grep -Fxq 'script=codex-slice-preflight' "$preflight_low_disk_explain_stderr" &&
    grep -Eq '^mode=check-only$' "$preflight_low_disk_explain_stderr" &&
    grep -Eq '^rc=1$' "$preflight_low_disk_explain_stderr" &&
    grep -Eq '^disk=fail$' "$preflight_low_disk_explain_stderr" &&
    low_disk_free_line="$(grep -n -m1 '^disk_free=' "$preflight_low_disk_explain_stderr" | cut -d: -f1)" &&
    low_disk_threshold_line="$(grep -n -m1 '^disk_threshold=' "$preflight_low_disk_explain_stderr" | cut -d: -f1)" &&
    low_disk_url_line="$(grep -n -m1 '^url_or_stop=' "$preflight_low_disk_explain_stderr" | cut -d: -f1)" &&
    [ "$low_disk_free_line" -lt "$low_disk_url_line" ] &&
    [ "$low_disk_threshold_line" -lt "$low_disk_url_line" ] &&
    grep -Eq '^disk_free_bytes=[0-9]+$' "$preflight_low_disk_explain_stderr" &&
    grep -Fxq 'disk_threshold_bytes=1610612736' "$preflight_low_disk_explain_stderr" &&
    grep -Fxq 'disk_free=1.0GiB' "$preflight_low_disk_explain_stderr" &&
    grep -Fxq 'disk_threshold=1.5GiB' "$preflight_low_disk_explain_stderr" &&
    grep -Eq '^disk_used=84%$' "$preflight_low_disk_explain_stderr" &&
    grep -Eq '^disk_available=16%$' "$preflight_low_disk_explain_stderr" &&
    grep -Fq 'fix: repo-automation/bin/codex-slice-preflight --clean-test-cache --explain' "$preflight_low_disk_explain_stderr" &&
    grep -Fq 'STOP: available disk space below threshold' "$preflight_low_disk_explain_stderr" &&
    ! grep -Fq 'cleanup_command=' "$preflight_low_disk_explain_stderr" &&
    ! grep -Eq '^branch_before=' "$preflight_low_disk_explain_stderr" &&
    ! grep -Eq '^branch_after=' "$preflight_low_disk_explain_stderr" &&
    grep -Fxq 'url_or_stop=available disk space below threshold' "$preflight_low_disk_explain_stderr" &&
    grep -Fxq '===== END =====' "$preflight_low_disk_explain_stderr" &&
    ( cd "$smoke_test_dir" && [ "$(git branch --show-current)" = "main" ] ); then
    test_pass "preflight stops before branch setup on low disk"
  else
    test_fail "preflight stops before branch setup on low disk"
    status=1
  fi

  mkdir -p "$preflight_clean_tmpdir/repo-automation-template-tests" \
    "$preflight_clean_tmpdir/repo-automation-template" \
    "$preflight_clean_tmpdir/repo-automation" \
    "$preflight_clean_tmpdir/repo-automation-log-dump" \
    "$preflight_clean_home/.cache/repo-automation-template-tests" \
    "$preflight_clean_home/.cache/repo-automation-template" \
    "$preflight_clean_home/.cache/repo-automation" \
    "$preflight_clean_home/.cache/repo-automation-log-dump" \
    "$preflight_clean_home/projects/repo-automation-template" \
    "$preflight_clean_home/Downloads" || return 1
  printf 'tmp cache marker\n' > "$preflight_clean_tmpdir/repo-automation-template-tests/marker.txt" || return 1
  printf 'tmp cache marker\n' > "$preflight_clean_tmpdir/repo-automation-template/marker.txt" || return 1
  printf 'tmp cache marker\n' > "$preflight_clean_tmpdir/repo-automation/marker.txt" || return 1
  printf 'tmp cache marker\n' > "$preflight_clean_tmpdir/repo-automation-log-dump/marker.txt" || return 1
  printf 'home cache marker\n' > "$preflight_clean_home/.cache/repo-automation-template-tests/marker.txt" || return 1
  printf 'home cache marker\n' > "$preflight_clean_home/.cache/repo-automation-template/marker.txt" || return 1
  printf 'home cache marker\n' > "$preflight_clean_home/.cache/repo-automation/marker.txt" || return 1
  printf 'home cache marker\n' > "$preflight_clean_home/.cache/repo-automation-log-dump/marker.txt" || return 1
  printf 'keep me\n' > "$preflight_clean_home/projects/repo-automation-template/keep.txt" || return 1
  printf 'keep me\n' > "$preflight_clean_home/Downloads/keep.txt" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$preflight_clean_tmpdir" HOME="$preflight_clean_home" \
      repo-automation/bin/codex-slice-preflight --clean-test-cache --explain > "$preflight_clean_stdout" 2> "$preflight_clean_stderr"
  ) && grep -Fxq '===== FINAL SUMMARY =====' "$preflight_clean_stderr" &&
    grep -Fxq 'script=codex-slice-preflight' "$preflight_clean_stderr" &&
    grep -Eq '^mode=clean-test-cache$' "$preflight_clean_stderr" &&
    grep -Eq '^rc=0$' "$preflight_clean_stderr" &&
    grep -Fxq 'disk=pass' "$preflight_clean_stderr" &&
    grep -Fq 'clean-test-cache removed:' "$preflight_clean_stderr" &&
    grep -Fq 'clean-test-cache free: before=' "$preflight_clean_stderr" &&
    grep -Fq 'repo-automation-template-tests' "$preflight_clean_stderr" &&
    grep -Fq 'repo-automation-template' "$preflight_clean_stderr" &&
    grep -Fq 'repo-automation-log-dump' "$preflight_clean_stderr" &&
    grep -Eq '^cleanup_free_before_bytes=[0-9]+$' "$preflight_clean_stderr" &&
    grep -Eq '^cleanup_free_before=[0-9]+(\.[0-9])?(B|KiB|MiB|GiB|TiB|PiB|EiB)$' "$preflight_clean_stderr" &&
    grep -Eq '^cleanup_free_after_bytes=[0-9]+$' "$preflight_clean_stderr" &&
    grep -Eq '^cleanup_free_after=[0-9]+(\.[0-9])?(B|KiB|MiB|GiB|TiB|PiB|EiB)$' "$preflight_clean_stderr" &&
    ! grep -Fq 'cleanup_command=' "$preflight_clean_stderr" &&
    ! grep -Eq '^branch_before=' "$preflight_clean_stderr" &&
    ! grep -Eq '^branch_after=' "$preflight_clean_stderr" &&
    grep -Fxq '===== END =====' "$preflight_clean_stderr" &&
    [ ! -e "$preflight_clean_tmpdir/repo-automation-template-tests/marker.txt" ] &&
    [ ! -e "$preflight_clean_tmpdir/repo-automation-template/marker.txt" ] &&
    [ ! -e "$preflight_clean_tmpdir/repo-automation/marker.txt" ] &&
    [ ! -e "$preflight_clean_tmpdir/repo-automation-log-dump/marker.txt" ] &&
    [ ! -e "$preflight_clean_home/.cache/repo-automation-template-tests/marker.txt" ] &&
    [ ! -e "$preflight_clean_home/.cache/repo-automation-template/marker.txt" ] &&
    [ ! -e "$preflight_clean_home/.cache/repo-automation/marker.txt" ] &&
    [ ! -e "$preflight_clean_home/.cache/repo-automation-log-dump/marker.txt" ] &&
    [ -e "$preflight_clean_home/projects/repo-automation-template/keep.txt" ] &&
    [ -e "$preflight_clean_home/Downloads/keep.txt" ]; then
    test_pass "preflight clean-test-cache removes only safe cache roots"
  else
    test_fail "preflight clean-test-cache removes only safe cache roots"
    status=1
  fi

  mkdir -p "$preflight_clean_tmpdir/repo-automation-template-tests" \
    "$preflight_clean_tmpdir/repo-automation-template" \
    "$preflight_clean_tmpdir/repo-automation" \
    "$preflight_clean_tmpdir/repo-automation-log-dump" \
    "$preflight_clean_home/.cache/repo-automation-template-tests" \
    "$preflight_clean_home/.cache/repo-automation-template" \
    "$preflight_clean_home/.cache/repo-automation" \
    "$preflight_clean_home/.cache/repo-automation-log-dump" \
    "$preflight_clean_home/projects/repo-automation-template" \
    "$preflight_clean_home/Downloads" || return 1
  printf 'tmp cache marker\n' > "$preflight_clean_tmpdir/repo-automation-template-tests/marker.txt" || return 1
  printf 'tmp cache marker\n' > "$preflight_clean_tmpdir/repo-automation-template/marker.txt" || return 1
  printf 'tmp cache marker\n' > "$preflight_clean_tmpdir/repo-automation/marker.txt" || return 1
  printf 'tmp cache marker\n' > "$preflight_clean_tmpdir/repo-automation-log-dump/marker.txt" || return 1
  printf 'home cache marker\n' > "$preflight_clean_home/.cache/repo-automation-template-tests/marker.txt" || return 1
  printf 'home cache marker\n' > "$preflight_clean_home/.cache/repo-automation-template/marker.txt" || return 1
  printf 'home cache marker\n' > "$preflight_clean_home/.cache/repo-automation/marker.txt" || return 1
  printf 'home cache marker\n' > "$preflight_clean_home/.cache/repo-automation-log-dump/marker.txt" || return 1
  printf 'keep me\n' > "$preflight_clean_home/projects/repo-automation-template/keep.txt" || return 1
  printf 'keep me\n' > "$preflight_clean_home/Downloads/keep.txt" || return 1

  if (
    cp -R "$smoke_test_dir" "$preflight_clean_branch_repo" || return 1
    cd "$preflight_clean_branch_repo" || return 1
    git reset --hard >/dev/null 2>&1 || return 1
    git clean -fd >/dev/null 2>&1 || return 1
    git checkout main >/dev/null 2>&1 || return 1
    git update-index --skip-worktree .repo-automation.conf || return 1
    python3 - "$smoke_expected_origin_url" .repo-automation.conf <<'PY' || return 1
import pathlib
import sys

expected = sys.argv[1]
config_path = pathlib.Path(sys.argv[2])
text = config_path.read_text(encoding="utf-8")
old = f'EXPECTED_REMOTE_URL="{expected}"'
new = 'EXPECTED_REMOTE_URL=""'
if old not in text:
    raise SystemExit(1)
config_path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
    git remote set-url origin "$smoke_remote_dir" >/dev/null 2>&1 || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    git pull --ff-only >/dev/null 2>&1 || return 1
    git branch -D "$preflight_clean_branch" >/dev/null 2>&1 || true
    git switch -c "$preflight_clean_branch" >/dev/null 2>&1 || return 1
    git checkout main >/dev/null 2>&1 || return 1
    TMPDIR="$preflight_clean_tmpdir" HOME="$preflight_clean_home" \
    repo-automation/bin/codex-slice-preflight --clean-test-cache --branch="$preflight_clean_branch" --explain > "$preflight_clean_stdout" 2> "$preflight_clean_branch_stderr"
  ) && grep -Fxq '===== FINAL SUMMARY =====' "$preflight_clean_branch_stderr" &&
    grep -Fxq 'script=codex-slice-preflight' "$preflight_clean_branch_stderr" &&
    grep -Eq '^mode=(run|preflight)$' "$preflight_clean_branch_stderr" &&
    grep -Eq '^rc=0$' "$preflight_clean_branch_stderr" &&
    grep -Fxq 'disk=pass' "$preflight_clean_branch_stderr" &&
    grep -Eq '^branch_before=main$' "$preflight_clean_branch_stderr" &&
    grep -Fxq "branch_after=$preflight_clean_branch" "$preflight_clean_branch_stderr" &&
    grep -Fxq 'default_branch=main' "$preflight_clean_branch_stderr" &&
    grep -Eq '^divergence=[0-9]+[[:space:]][0-9]+$|^divergence=unknown$' "$preflight_clean_branch_stderr" &&
    grep -Fxq 'status_count=0' "$preflight_clean_branch_stderr" &&
    grep -Fxq 'cleanup=cleaned' "$preflight_clean_branch_stderr" &&
    grep -Eq '^cleanup_deleted_count=8$' "$preflight_clean_branch_stderr" &&
    ! grep -Fq 'cleanup_deleted_paths=' "$preflight_clean_branch_stderr" &&
    ! grep -Eq '^cleanup_free_before_bytes=' "$preflight_clean_branch_stderr" &&
    ! grep -Eq '^cleanup_free_before=' "$preflight_clean_branch_stderr" &&
    ! grep -Eq '^cleanup_free_after_bytes=' "$preflight_clean_branch_stderr" &&
    ! grep -Eq '^cleanup_free_after=' "$preflight_clean_branch_stderr" &&
    grep -Fxq '===== END =====' "$preflight_clean_branch_stderr" &&
    ( cd "$preflight_clean_branch_repo" && [ "$(git branch --show-current)" = "$preflight_clean_branch" ] ); then
    test_pass "preflight clean-test-cache can continue into branch setup"
  else
    test_fail "preflight clean-test-cache can continue into branch setup"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --branch feature/preflight-smoke >/dev/null 2> "$branch_format_stderr"
  ); then
    test_fail "preflight rejects --branch <name>"
    status=1
  elif smoke_assert_flag_error_shape "$branch_format_stderr" "flag format not accepted" "--branch" "use --branch=<name>"; then
    test_pass "preflight rejects --branch <name>"
  else
    test_fail "preflight rejects --branch <name>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --branch >/dev/null 2> "$branch_missing_stderr"
  ); then
    test_fail "preflight rejects missing --branch value"
    status=1
  elif smoke_assert_flag_error_shape "$branch_missing_stderr" "missing flag value" "--branch" "use --branch=<name>"; then
    test_pass "preflight rejects missing --branch value"
  else
    test_fail "preflight rejects missing --branch value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --branch= >/dev/null 2> "$branch_empty_stderr"
  ); then
    test_fail "preflight rejects empty --branch value"
    status=1
  elif smoke_assert_flag_error_shape "$branch_empty_stderr" "empty flag value" "--branch" "use --branch=<name>"; then
    test_pass "preflight rejects empty --branch value"
  else
    test_fail "preflight rejects empty --branch value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --whatever >/dev/null 2> "$branch_unknown_stderr"
  ); then
    test_fail "preflight rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$branch_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/codex-slice-preflight --help"; then
    test_pass "preflight rejects unknown flags"
  else
    test_fail "preflight rejects unknown flags"
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

  rm -f "$preflight_explain_stdout" "$preflight_explain_stderr" >/dev/null 2>&1 || true

  return "$status"
}

smoke_check_pr_finish_watch_exit() {
  local status=0
  local blocked_stderr="$smoke_test_dir/pr-finish-watch-blocked.log"
  local blocked_stdout="$smoke_test_dir/pr-finish-watch-blocked.out"
  local green_stderr="$smoke_test_dir/pr-finish-watch-green.log"
  local green_stdout="$smoke_test_dir/pr-finish-watch-green.out"
  local green_explain_stderr="$smoke_test_dir/pr-finish-watch-green-explain.log"
  local diagnose_stderr="$smoke_test_dir/pr-finish-watch-diagnose.log"
  local diagnose_fail_stderr="$smoke_test_dir/pr-finish-watch-diagnose-fail.log"
  local missing_stderr="$smoke_test_dir/pr-finish-watch-missing.log"
  local missing_stdout="$smoke_test_dir/pr-finish-watch-missing.out"
  local gh_stub_dir="$smoke_test_base/gh-stub"
  local local_bash_path=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-123' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":123,"conclusion":"failure","createdAt":"2026-05-12T12:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-123","status":"completed","workflowName":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --pr=123 >/dev/null 2> "$blocked_stderr"
  ); then
    test_fail "pr-finish watch exits nonzero when checks are blocked"
    status=1
  else
    if grep -q 'STOP: CI failed for PR #123' "$blocked_stderr" &&
      grep -q 'fail: CI checks failed' "$blocked_stderr"; then
      test_pass "pr-finish watch exits nonzero when checks are blocked"
    else
      test_fail "pr-finish watch exits nonzero when checks are blocked"
      status=1
    fi
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-123' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":123,"conclusion":"success","createdAt":"2026-05-12T12:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-123","status":"completed","workflowName":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --pr=123 > "$green_stdout" 2> "$green_stderr"
  ) && [ "$(cat "$green_stdout")" = "pass" ] && [ ! -s "$green_stderr" ]; then
    test_pass "pr-finish watch exits zero when checks are green"
  else
    test_fail "pr-finish watch exits zero when checks are green"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-123' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":123,"conclusion":"success","createdAt":"2026-05-12T12:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-123","status":"completed","workflowName":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --explain --pr=123 > /dev/null 2> "$green_explain_stderr"
  ) && grep -q 'mode: watch' "$green_explain_stderr" && grep -q 'checks status: green' "$green_explain_stderr" && grep -Fxq '===== FINAL SUMMARY =====' "$green_explain_stderr" && grep -Fxq '===== END =====' "$green_explain_stderr"; then
    test_pass "pr-finish watch explain output is detailed"
  else
    test_fail "pr-finish watch explain output is detailed"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-123' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-123","status":"completed","workflowName":"ci"}]' \
    GH_STUB_RUN_VIEW_FAILED_LOG='shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting.
ci log line two
tail one
tail two' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --diagnose-on-fail --pr=123 >/dev/null 2> "$diagnose_stderr"
  ); then
    test_fail "pr-finish watch diagnoses blocked checks"
    status=1
  elif grep -q 'STOP: CI failed for PR #123' "$diagnose_stderr" &&
    grep -q 'fail: CI checks failed' "$diagnose_stderr"; then
    test_pass "pr-finish watch diagnoses blocked checks"
  else
    test_fail "pr-finish watch diagnoses blocked checks"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-123' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-123","status":"completed","workflowName":"ci"}]' \
    GH_STUB_RUN_VIEW_ALWAYS_FAIL_STDERR='net/http: TLS handshake timeout' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --diagnose-on-fail --pr=123 >/dev/null 2> "$diagnose_fail_stderr"
  ); then
    test_fail "pr-finish watch reports diagnosis failures without hiding blocked checks"
    status=1
  elif grep -q 'STOP: CI failed for PR #123' "$diagnose_fail_stderr" &&
    grep -q 'fail: CI checks failed' "$diagnose_fail_stderr"; then
    test_pass "pr-finish watch reports diagnosis failures without hiding blocked checks"
  else
    test_fail "pr-finish watch reports diagnosis failures without hiding blocked checks"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    printf '%s\n%s\n' \
      '[]' \
      '[{"databaseId":123,"conclusion":"success","createdAt":"2026-05-12T12:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-123","status":"completed","workflowName":"ci"}]' > "$smoke_test_base/run-list-sequence.json"
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-123' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":123,"conclusion":"success","createdAt":"2026-05-12T12:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-123","status":"completed","workflowName":"ci"}]' \
    GH_STUB_RUN_LIST_SEQUENCE_FILE="$smoke_test_base/run-list-sequence.json" \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --diagnose-on-fail --pr=123 > "$missing_stdout" 2> "$missing_stderr"
  ); then
    test_pass "pr-finish watch retries missing checks before failing"
  else
    test_fail "pr-finish watch retries missing checks before failing"
    status=1
  fi

  if [ "$(cat "$missing_stdout")" = "pass" ] && [ ! -s "$missing_stderr" ]; then
    :
  else
    test_fail "pr-finish watch retries missing checks without diagnosis"
    status=1
  fi

  rm -f "$blocked_stdout" "$green_stdout" "$green_explain_stderr" >/dev/null 2>&1 || true

  return "$status"
}

# repo-automation/tests/lib/contracts/pr-workflow.sh EOF
