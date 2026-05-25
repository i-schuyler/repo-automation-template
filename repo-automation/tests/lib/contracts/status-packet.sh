# repo-automation/tests/lib/contracts/status-packet.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_status_packet_contract() {
  local status=0
  local temp_root="$smoke_test_base/status-packet-root"
  local log_root="$temp_root/repo-automation-template"
  local status_human="$smoke_test_base/status-packet-human-$$.txt"
  local status_json="$smoke_test_base/status-packet-json-$$.json"
  local status_final_summary="$smoke_test_base/status-packet-final-summary-$$.txt"
  local status_final_summary_hooks="$smoke_test_base/status-packet-final-summary-hooks-$$.txt"
  local status_explain="$smoke_test_base/status-packet-explain-$$.txt"
  local gh_stub_dir="$smoke_test_base/gh-stub-status-packet"
  local status_unknown_stderr="$smoke_test_base/status-packet-unknown-$$.txt"
  local status_packet_local_config="$smoke_test_dir/.repo-automation.local.conf"

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
  ) && python3 -m json.tool "$status_json" >/dev/null &&     smoke_json_assert "$status_json" 'data.get("script") == "status-packet" and data.get("machine_json") is True and data.get("branch") == "main" and "README.md" in data.get("changed_tracked_files", []) and "status-packet-scratch.txt" in data.get("untracked_files", []) and data.get("recent_logs", {}).get("run_tests", "").endswith("run-tests-20260512-140000.log") and data.get("recent_logs", {}).get("repo_doctor", "").endswith("repo-doctor-20260512-150000.log") and data.get("overall_status") == "pass"'; then
    test_pass "status-packet machine-json reports compact repo state"
  else
    test_fail "status-packet machine-json reports compact repo state"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --explain > "$status_explain"
  ) && [ "$(wc -l < "$status_explain" | tr -d '[:space:]')" -eq 7 ] && grep -Fxq '===== FINAL SUMMARY =====' "$status_explain" && grep -Eq '^branch=main$' "$status_explain" && grep -Eq '^rc=0$' "$status_explain" && grep -Eq '^output_lines=[0-9]+$' "$status_explain" && awk -F= '$1=="output_lines" { exit !($2 <= 25) }' "$status_explain" && grep -Eq '^url_or_stop=pass$' "$status_explain" && grep -Eq '^status_count=[0-9]+$' "$status_explain" && grep -Fxq '===== END =====' "$status_explain"; then
    test_pass "status-packet explain output uses the compact marker contract"
  else
    test_fail "status-packet explain output uses the compact marker contract"
    status=1
  fi

  cat > "$status_packet_local_config" <<'EOF'
FINAL_SUMMARY_AFTER_START_HOOK="mark"
FINAL_SUMMARY_BEFORE_END_HOOK="recap"
EOF

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --explain > "$status_final_summary_hooks"
  ) && [ "$(wc -l < "$status_final_summary_hooks" | tr -d '[:space:]')" -eq 9 ] && [ "$(sed -n '2p' "$status_final_summary_hooks")" = 'mark' ] && [ "$(sed -n '8p' "$status_final_summary_hooks")" = 'recap' ] && grep -Fxq '===== FINAL SUMMARY =====' "$status_final_summary_hooks" && grep -Eq '^branch=main$' "$status_final_summary_hooks" && grep -Eq '^rc=0$' "$status_final_summary_hooks" && grep -Eq '^output_lines=[0-9]+$' "$status_final_summary_hooks" && awk -F= '$1=="output_lines" { exit !($2 <= 25) }' "$status_final_summary_hooks" && grep -Eq '^url_or_stop=pass$' "$status_final_summary_hooks" && grep -Eq '^status_count=[0-9]+$' "$status_final_summary_hooks" && grep -Fxq '===== END =====' "$status_final_summary_hooks"; then
    test_pass "status-packet explain hook lines render in the contract"
  else
    test_fail "status-packet explain hook lines render in the contract"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --whatever >/dev/null 2> "$status_unknown_stderr"
  ); then
    test_fail "status-packet rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$status_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/status-packet --help"; then
    test_pass "status-packet rejects unknown flags"
  else
    test_fail "status-packet rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -- README.md >/dev/null 2>&1 || return 1
    rm -f status-packet-scratch.txt >/dev/null 2>&1 || return 1
  ); then
    :
  fi

  rm -f "$status_human" "$status_json" "$status_final_summary" "$status_final_summary_hooks" "$status_explain" "$status_unknown_stderr" "$status_packet_local_config" >/dev/null 2>&1 || true
  rm -f "$log_root"/run-tests-20260512-140000.log "$log_root"/repo-doctor-20260512-150000.log >/dev/null 2>&1 || true
  rmdir "$log_root" "$temp_root" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/status-packet.sh EOF
