# repo-automation/tests/lib/contracts/parser-args.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_parser_args_contract() {
  local status=0
  local touched_args_base=""
  local touched_args_head=""
  local touched_args_empty_stderr="$smoke_test_base/touched-files-args-empty-$$.txt"
  local strict_empty_stderr="$smoke_test_base/strict-parser-empty-$$.txt"
  local touched_args_format_stderr="$smoke_test_base/touched-files-args-format-$$.txt"
  local touched_args_missing_stderr="$smoke_test_base/touched-files-args-missing-$$.txt"
  local strict_value=""

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    repo_auto_parse_value_flag_equals "--base=feature/demo" "--base" "use --base=<ref>" touched_args_base || return 1
    repo_auto_parse_value_flag_equals "--head=release/demo" "--head" "use --head=<ref>" touched_args_head || return 1
    [ "$touched_args_base" = "feature/demo" ] && [ "$touched_args_head" = "release/demo" ]
  ); then
    test_pass "touched-files parser seam preserves equals-form values"
  else
    test_fail "touched-files parser seam preserves equals-form values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    repo_auto_parse_value_flag_strict "--kind=" "--kind" "use --kind=<run-tests|repo-doctor|any>" strict_value
  ) 2>"$strict_empty_stderr"; then
    test_fail "strict parser seam rejects empty equals-form values"
    status=1
  elif smoke_assert_flag_error_shape "$strict_empty_stderr" "empty flag value" "--kind" "use --kind=<run-tests|repo-doctor|any>"; then
    test_pass "strict parser seam rejects empty equals-form values"
  else
    test_fail "strict parser seam rejects empty equals-form values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    repo_auto_parse_value_flag_strict "--kind=run-tests" "--kind" "use --kind=<run-tests|repo-doctor|any>" strict_value "ignored-next" || return 1
    [ "$strict_value" = "run-tests" ]
  ); then
    test_pass "strict parser seam preserves equals-form values"
  else
    test_fail "strict parser seam preserves equals-form values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    repo_auto_parse_value_flag_equals "--base=" "--base" "use --base=<ref>" touched_args_base
  ) 2>"$touched_args_empty_stderr"; then
    test_fail "touched-files parser seam rejects empty equals-form values"
    status=1
  elif smoke_assert_flag_error_shape "$touched_args_empty_stderr" "empty flag value" "--base" "use --base=<ref>"; then
    test_pass "touched-files parser seam rejects empty equals-form values"
  else
    test_fail "touched-files parser seam rejects empty equals-form values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    repo_auto_parse_value_flag_strict "--kind" "--kind" "use --kind=<run-tests|repo-doctor|any>" strict_value "run-tests"
  ) 2>"$touched_args_format_stderr"; then
    test_fail "strict parser seam rejects positional value form"
    status=1
  elif smoke_assert_flag_error_shape "$touched_args_format_stderr" "flag format not accepted" "--kind" "use --kind=<run-tests|repo-doctor|any>"; then
    test_pass "strict parser seam rejects positional value form"
  else
    test_fail "strict parser seam rejects positional value form"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    repo_auto_parse_value_flag_strict "--kind" "--kind" "use --kind=<run-tests|repo-doctor|any>" strict_value "--quiet"
  ) 2>"$touched_args_missing_stderr"; then
    test_fail "strict parser seam rejects missing values"
    status=1
  elif smoke_assert_flag_error_shape "$touched_args_missing_stderr" "missing flag value" "--kind" "use --kind=<run-tests|repo-doctor|any>"; then
    test_pass "strict parser seam rejects missing values"
  else
    test_fail "strict parser seam rejects missing values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    repo_auto_parse_value_flag_strict "--other=value" "--kind" "use --kind=<run-tests|repo-doctor|any>" strict_value "ignored-next"
    [ "$?" -eq 2 ]
  ); then
    test_pass "strict parser seam reports unmatched flags"
  else
    test_fail "strict parser seam reports unmatched flags"
    status=1
  fi

  rm -f "$touched_args_empty_stderr" "$strict_empty_stderr" "$touched_args_format_stderr" "$touched_args_missing_stderr" >/dev/null 2>&1 || true
  return "$status"
}
