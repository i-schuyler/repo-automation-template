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
  local add_doc_pr_run_tests_marker="$smoke_test_base/add-doc-pr-run-tests-called"
  local add_doc_pr_docs_check_marker="$smoke_test_base/add-doc-pr-docs-check-called"
  local add_doc_pr_failure_details=""
  local repo_doctor_help="$smoke_test_base/repo-doctor-help-$$.txt"
  local ci_log_dump_help="$smoke_test_base/ci-log-dump-help-$$.txt"
  local report_upstream_help="$smoke_test_base/report-upstream-help-$$.txt"
  local install_help="$smoke_test_base/repo-install-help-$$.txt"

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
    repo-automation/bin/add-doc-pr --help > "$add_doc_pr_help"
  ) && \
    grep -Fq -- '--branch=<name>' "$add_doc_pr_help" && \
    grep -Fq -- '--title=<text>' "$add_doc_pr_help" && \
    grep -Fq -- '--body-file=<path>' "$add_doc_pr_help" && \
    grep -Fq -- '--body=<text>' "$add_doc_pr_help" && \
    grep -Fq -- '--commit-message=<text>' "$add_doc_pr_help" && \
    grep -Fq -- '--allow=<path-prefix>' "$add_doc_pr_help" && \
    grep -Fq -- '--base=<branch>' "$add_doc_pr_help" && \
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
  ) && python -m json.tool "$add_doc_pr_json" >/dev/null; then
    if smoke_json_assert "$add_doc_pr_json" 'data.get("branch") == "docs/my-doc-update" and data.get("base_branch") == "main" and "docs/plan-doc.md" in data.get("changed_files", []) and len(data.get("blocked_files", [])) == 0'; then
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
  ) && python -m json.tool "$add_doc_pr_create_json" >/dev/null && \
    smoke_json_assert "$add_doc_pr_create_json" 'data.get("checks_run") is True' && \
    ! grep -Fq 'docs-check output' "$add_doc_pr_create_stderr" && \
    [ -f "$add_doc_pr_docs_check_marker" ] && \
    [ ! -e "$add_doc_pr_run_tests_marker" ]; then
    test_pass "add-doc-pr dry-run create-pr validates docs-only changes"
  else
    if [ -s "$add_doc_pr_create_json" ]; then
      add_doc_pr_failure_details="$(python -c 'import json, pathlib, sys; data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")); print(" (checks_run=" + json.dumps(data.get("checks_run")) + "; action_taken=" + json.dumps(data.get("action_taken")) + "; stop_reason=" + json.dumps(data.get("stop_reason")) + "; changed_files=" + json.dumps(data.get("changed_files", [])) + "; blocked_files=" + json.dumps(data.get("blocked_files", [])) + ")")' "$add_doc_pr_create_json")"
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

  rm -f "$add_doc_pr_json" "$add_doc_pr_stderr" "$add_doc_pr_create_json" "$add_doc_pr_create_stderr" "$repo_doctor_help" "$ci_log_dump_help" "$report_upstream_help" "$install_help" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_add_doc_pr_blocked_file() {
  local status=0
  local add_doc_pr_block_json="$smoke_test_base/add-doc-pr-blocked-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    printf '0.1.1\n' > VERSION || return 1
    repo-automation/bin/add-doc-pr --plan --json > "$add_doc_pr_block_json"
    return 1
  ); then
    test_fail "add-doc-pr blocks repo-automation/ boundary changes in plan mode"
    status=1
  else
    if python -m json.tool "$add_doc_pr_block_json" >/dev/null && \
      smoke_json_assert "$add_doc_pr_block_json" '"VERSION" in data.get("blocked_files", [])'; then
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

  rm -f "$add_doc_pr_block_json" >/dev/null 2>&1 || true
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
  local gh_stub_dir="$smoke_test_base/gh-pr-create-stub"
  local body_text="Mixed PR body from file"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-create --help > "$helper_help"
  ) && \
    grep -Fq -- '--branch=<name>' "$helper_help" && \
    grep -Fq -- '--base=<branch>' "$helper_help" && \
    grep -Fq -- '--title=<text>' "$helper_help" && \
    grep -Fq -- '--body-file=<path>' "$helper_help" && \
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
  printf '%s\n' "$body_text" > "$helper_body" || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$helper_log" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$helper_body_copy" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/321' \
    GH_STUB_PR_VIEW_NUMBER=321 \
    repo-automation/bin/pr-create --json --branch="$branch_name" --base=main --title="Mixed change body file" --body-file="$helper_body" > "$helper_json"
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

  rm -f "$helper_json" "$helper_log" "$helper_body" "$helper_body_copy" "$helper_help" "$branch_format_stderr" "$branch_missing_stderr" "$branch_empty_stderr" "$unknown_stderr" >/dev/null 2>&1 || true
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
    repo-automation/bin/pr-create --json --branch="$branch_name" --base=main --title="Mixed change body text" --body="$body_text" > "$helper_json"
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

smoke_check_branch_cleanup_json() {
  local status=0
  local branch_json="$smoke_test_dir/branch-cleanup.json"
  local unknown_flag_stderr="$smoke_test_base/branch-cleanup-unknown.stderr"
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
  local local_bash_path=""
  local shim_dir=""

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
  ) && python -m json.tool "$preflight_json" >/dev/null; then
    test_pass "preflight json is parseable"
  else
    test_fail "preflight json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --help > "$preflight_help"
  ) && grep -Fq -- '--branch=<name>' "$preflight_help" && ! grep -Fq -- '--branch BRANCH' "$preflight_help"; then
    test_pass "preflight help shows strict branch syntax"
  else
    test_fail "preflight help shows strict branch syntax"
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

  return "$status"
}

smoke_check_pr_finish_watch_exit() {
  local status=0
  local blocked_stderr="$smoke_test_dir/pr-finish-watch-blocked.log"
  local green_stderr="$smoke_test_dir/pr-finish-watch-green.log"
  local diagnose_stderr="$smoke_test_dir/pr-finish-watch-diagnose.log"
  local diagnose_fail_stderr="$smoke_test_dir/pr-finish-watch-diagnose-fail.log"
  local missing_stderr="$smoke_test_dir/pr-finish-watch-missing.log"
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
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --pr=123 >/dev/null 2> "$blocked_stderr"
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
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --pr=123 >/dev/null 2> "$green_stderr"
  ); then
    test_pass "pr-finish watch exits zero when checks are green"
  else
    test_fail "pr-finish watch exits zero when checks are green"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"fail","state":"FAILURE","workflow":"ci"}]' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/demo","status":"completed","workflowName":"ci"}]' \
    GH_STUB_RUN_VIEW_FAILED_LOG='shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting.
ci log line two
tail one
tail two' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --diagnose-on-fail --pr=123 >/dev/null 2> "$diagnose_stderr"
  ); then
    test_fail "pr-finish watch diagnoses blocked checks"
    status=1
  elif grep -q 'watch completed with checks status: blocked' "$diagnose_stderr" &&
    grep -q 'diagnosis label: fail: shellcheck' "$diagnose_stderr" &&
    grep -q 'diagnosis log path: ' "$diagnose_stderr" &&
    grep -q 'diagnosis excerpt: shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting\.' "$diagnose_stderr" &&
    grep -q 'diagnosis recommended fix: run shellcheck on the reported file and line' "$diagnose_stderr"; then
    test_pass "pr-finish watch diagnoses blocked checks"
  else
    test_fail "pr-finish watch diagnoses blocked checks"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"fail","state":"FAILURE","workflow":"ci"}]' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/demo","status":"completed","workflowName":"ci"}]' \
    GH_STUB_RUN_VIEW_ALWAYS_FAIL_STDERR='net/http: TLS handshake timeout' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --diagnose-on-fail --pr=123 >/dev/null 2> "$diagnose_fail_stderr"
  ); then
    test_fail "pr-finish watch reports diagnosis failures without hiding blocked checks"
    status=1
  elif grep -q 'watch completed with checks status: blocked' "$diagnose_fail_stderr" &&
    grep -q 'diagnosis access failure: BLOCKER: GitHub API failure while fetching failed log for run 222 after 3 attempts: net/http: TLS handshake timeout' "$diagnose_fail_stderr"; then
    test_pass "pr-finish watch reports diagnosis failures without hiding blocked checks"
  else
    test_fail "pr-finish watch reports diagnosis failures without hiding blocked checks"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    printf '%s\n%s\n' \
      '[]' \
      '[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' > "$smoke_test_base/pr-checks-sequence.json"
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_CHECKS_SEQUENCE_FILE="$smoke_test_base/pr-checks-sequence.json" \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --watch --diagnose-on-fail --pr=123 >/dev/null 2> "$missing_stderr"
  ); then
    test_pass "pr-finish watch retries missing checks before failing"
  else
    test_fail "pr-finish watch retries missing checks before failing"
    status=1
  fi

  if grep -q 'watch completed with checks status: green' "$missing_stderr" && ! grep -q 'diagnosis ' "$missing_stderr"; then
    :
  else
    test_fail "pr-finish watch retries missing checks without diagnosis"
    status=1
  fi

  return "$status"
}

# repo-automation/tests/lib/contracts/pr-workflow.sh EOF
