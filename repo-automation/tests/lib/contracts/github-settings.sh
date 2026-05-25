# repo-automation/tests/lib/contracts/github-settings.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_github_settings_contract() {
  local status=0
  local github_settings_json="$smoke_test_base/github-settings-check-$$.json"
  local github_settings_repo_json="$smoke_test_base/github-settings-check-repo-$$.json"
  local github_settings_help="$smoke_test_base/github-settings-check-help-$$.txt"
  local github_settings_pass_human="$smoke_test_base/github-settings-check-pass-$$.txt"
  local github_settings_quiet_human="$smoke_test_base/github-settings-check-quiet-$$.txt"
  local github_settings_explain_human="$smoke_test_base/github-settings-check-explain-$$.txt"
  local github_settings_repo_format_stderr="$smoke_test_base/github-settings-check-repo-format.stderr"
  local github_settings_repo_missing_stderr="$smoke_test_base/github-settings-check-repo-missing.stderr"
  local github_settings_repo_empty_stderr="$smoke_test_base/github-settings-check-repo-empty.stderr"
  local github_settings_unknown_stderr="$smoke_test_base/github-settings-check-unknown.stderr"
  local github_settings_doctor_json="$smoke_test_base/repo-doctor-github-settings-$$.json"
  local gh_stub_dir="$smoke_test_base/gh-stub-settings"

  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --help > "$github_settings_help"
  ) && grep -Fq -- '--repo=<owner/repo>' "$github_settings_help" && grep -Fq -- '--quiet' "$github_settings_help" && grep -Fq -- '--explain' "$github_settings_help" && ! grep -Fq -- '--repo OWNER/REPO' "$github_settings_help"; then
    test_pass "github-settings-check help shows strict repo syntax"
  else
    test_fail "github-settings-check help shows strict repo syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check > "$github_settings_pass_human" 2>&1
  ) && [ "$(cat "$github_settings_pass_human")" = "pass" ]; then
    test_pass "github-settings-check default human output is compact"
  else
    test_fail "github-settings-check default human output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --quiet > "$github_settings_quiet_human" 2>&1
  ) && [ ! -s "$github_settings_quiet_human" ]; then
    test_pass "github-settings-check quiet success is silent"
  else
    test_fail "github-settings-check quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --explain > "$github_settings_explain_human" 2>&1
  ) && grep -Eq '^pass=[0-9]+ warn=[0-9]+ fail=[0-9]+ skipped=[0-9]+$' "$github_settings_explain_human" && grep -Eq '^PASS: github-context - ' "$github_settings_explain_human"; then
    test_pass "github-settings-check explain output is detailed"
  else
    test_fail "github-settings-check explain output is detailed"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --repo=i-schuyler/repo-automation-template --machine-json > "$github_settings_repo_json"
  ) && python3 -m json.tool "$github_settings_repo_json" >/dev/null && \
    smoke_json_assert "$github_settings_repo_json" 'data.get("overall_status") == "pass" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("repo_source") == "flag"'; then
    test_pass "github-settings-check accepts explicit repo syntax"
  else
    test_fail "github-settings-check accepts explicit repo syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --repo i-schuyler/repo-automation-template >/dev/null 2> "$github_settings_repo_format_stderr"
  ); then
    test_fail "github-settings-check rejects --repo <owner/repo>"
    status=1
  elif smoke_assert_flag_error_shape "$github_settings_repo_format_stderr" "flag format not accepted" "--repo" "use --repo=<owner/repo>"; then
    test_pass "github-settings-check rejects --repo <owner/repo>"
  else
    test_fail "github-settings-check rejects --repo <owner/repo>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --repo >/dev/null 2> "$github_settings_repo_missing_stderr"
  ); then
    test_fail "github-settings-check rejects missing --repo value"
    status=1
  elif smoke_assert_flag_error_shape "$github_settings_repo_missing_stderr" "missing flag value" "--repo" "use --repo=<owner/repo>"; then
    test_pass "github-settings-check rejects missing --repo value"
  else
    test_fail "github-settings-check rejects missing --repo value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --repo= >/dev/null 2> "$github_settings_repo_empty_stderr"
  ); then
    test_fail "github-settings-check rejects empty --repo value"
    status=1
  elif smoke_assert_flag_error_shape "$github_settings_repo_empty_stderr" "empty flag value" "--repo" "use --repo=<owner/repo>"; then
    test_pass "github-settings-check rejects empty --repo value"
  else
    test_fail "github-settings-check rejects empty --repo value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --whatever >/dev/null 2> "$github_settings_unknown_stderr"
  ); then
    test_fail "github-settings-check rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$github_settings_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/github-settings-check --help"; then
    test_pass "github-settings-check rejects unknown flags"
  else
    test_fail "github-settings-check rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --machine-json > "$github_settings_json"
  ) && python3 -m json.tool "$github_settings_json" >/dev/null && \
    smoke_json_assert "$github_settings_json" 'data.get("overall_status") == "pass" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("default_branch") == "main" and data.get("actions_enabled") is True and data.get("pr_template_exists") is True and data.get("issue_templates_exist") is True and data.get("ci_workflow_exists") is True'; then
    test_pass "github-settings-check machine-json is parseable"
  else
    test_fail "github-settings-check machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/repo-doctor --check=github-settings-readiness --json --json-level=all > "$github_settings_doctor_json"
  ) && python3 -m json.tool "$github_settings_doctor_json" >/dev/null && \
    smoke_json_assert "$github_settings_doctor_json" 'data.get("overall_status") == "pass" and any(check.get("name") == "github-settings-readiness" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "repo-doctor github-settings-readiness check passes"
  else
    test_fail "repo-doctor github-settings-readiness check passes"
    status=1
  fi

  rm -f "$github_settings_json" "$github_settings_repo_json" "$github_settings_help" "$github_settings_pass_human" "$github_settings_quiet_human" "$github_settings_explain_human" "$github_settings_repo_format_stderr" "$github_settings_repo_missing_stderr" "$github_settings_repo_empty_stderr" "$github_settings_unknown_stderr" "$github_settings_doctor_json" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/github-settings.sh EOF
