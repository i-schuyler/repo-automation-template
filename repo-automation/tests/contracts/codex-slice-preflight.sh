#!/usr/bin/env bash
# repo-automation/tests/contracts/codex-slice-preflight.sh
# shellcheck disable=SC2154

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/pr-workflow.sh"

smoke_main_impl() {
  smoke_setup_temp_repo || return 1
  smoke_run_named_check "smoke:preflight-preserve-path-json" smoke_check_preflight_preserve_path_json || return 1
  smoke_run_named_check "smoke:preflight-clean-test-cache-json" smoke_check_preflight_clean_test_cache_json || return 1
  smoke_run_named_check "smoke:preflight-json" smoke_check_preflight_json || return 1
  smoke_run_named_check "smoke:preflight-repair" smoke_check_preflight_repair
}

smoke_check_preflight_preserve_path_json() {
  local json_out="$smoke_test_base/preflight-preserve-path.json"
  local json_err="$smoke_test_base/preflight-preserve-path.stderr"
  local missing_path="$smoke_test_base/missing-preserve-path"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/codex-slice-preflight --json --clean-test-cache --branch=feature/preflight-smoke --preserve-path="$missing_path" >"$json_out" 2>"$json_err"
  ); then
    test_fail "preflight preserve-path JSON failure includes stop_reason"
    return 1
  elif python3 -m json.tool "$json_out" >/dev/null &&
    smoke_json_assert "$json_out" 'data.get("result") == "fail" and data.get("mode") == "clean-test-cache" and data.get("rc") == 1 and data.get("stop_reason") and "preserve path does not exist" in data.get("stop_reason", "")'; then
    test_pass "preflight preserve-path JSON failure includes stop_reason"
  else
    test_fail "preflight preserve-path JSON failure includes stop_reason"
    return 1
  fi
}

smoke_check_preflight_clean_test_cache_json() {
  local json_out="$smoke_test_base/preflight-clean-test-cache.json"
  local json_err="$smoke_test_base/preflight-clean-test-cache.stderr"
  local preserve_dir="$smoke_test_base/preflight-clean-test-cache-preserve"
  local cleanup_root="$smoke_test_base/repo-automation-template-tests"
  local cleanup_path="$cleanup_root/preflight-clean-test-cache-lock"
  local cleanup_child="$cleanup_path/locked-child"

  rm -rf -- "$cleanup_root" "$preserve_dir"
  mkdir -p "$preserve_dir" "$cleanup_child" || return 1
  printf 'keep\n' >"$preserve_dir/keep.txt" || return 1
  printf 'locked\n' >"$cleanup_child/blocked.txt" || return 1
  chmod 555 "$cleanup_path" "$cleanup_child" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$smoke_test_base" repo-automation/bin/codex-slice-preflight --json --clean-test-cache --branch=feature/preflight-smoke --preserve-path="$preserve_dir" >"$json_out" 2>"$json_err"
  ); then
    chmod 755 "$cleanup_child" "$cleanup_path" || return 1
    rm -rf -- "$cleanup_root" "$preserve_dir"
    test_fail "preflight cleanup JSON failure includes stop_reason"
    return 1
  fi

  chmod 755 "$cleanup_child" "$cleanup_path" || return 1
  rm -rf -- "$cleanup_root" "$preserve_dir"

  if python3 -m json.tool "$json_out" >/dev/null &&
    smoke_json_assert "$json_out" 'data.get("result") == "fail" and data.get("mode") == "clean-test-cache" and data.get("rc") == 1 and data.get("stop_reason") and "failed to delete candidate path" in data.get("stop_reason", "")'; then
    test_pass "preflight cleanup JSON failure includes stop_reason"
  else
    test_fail "preflight cleanup JSON failure includes stop_reason"
    return 1
  fi
}

smoke_check_preflight_repair() {
  local repo="$smoke_test_base/preflight-repair-repo"
  local fake_bin="$smoke_test_base/preflight-repair-bin"
  local output="$smoke_test_base/preflight-repair.json"
  local missing_output="$smoke_test_base/preflight-repair-missing.json"
  local mismatch_output="$smoke_test_base/preflight-repair-mismatch.json"
  local behind_output="$smoke_test_base/preflight-repair-behind.json"
  local diverged_output="$smoke_test_base/preflight-repair-diverged.json"
  local non_repair_output="$smoke_test_base/preflight-non-repair.json"
  local branch="feature/preflight-repair"
  local behind_branch="feature/preflight-repair-behind"
  local diverged_branch="feature/preflight-repair-diverged"

  git clone --local --no-hardlinks "$smoke_test_dir" "$repo" >/dev/null 2>&1 || return 1
  git -C "$repo" config user.name "repo-automation-test" || return 1
  git -C "$repo" config user.email "repo-automation-test@example.com" || return 1
  cp -- "$smoke_repo_root/repo-automation/bin/codex-slice-preflight" "$repo/repo-automation/bin/codex-slice-preflight" || return 1
  chmod +x "$repo/repo-automation/bin/codex-slice-preflight" || return 1
  git -C "$repo" update-index --skip-worktree repo-automation/bin/codex-slice-preflight .repo-automation.conf || return 1
  python3 - "$repo/.repo-automation.conf" <<'PY' || return 1
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(re.sub(r'^EXPECTED_REMOTE_URL=.*$', 'EXPECTED_REMOTE_URL=""', text, flags=re.M), encoding="utf-8")
PY
  git -C "$repo" switch -c "$branch" >/dev/null 2>&1 || return 1
  printf 'ahead-only repair\n' >"$repo/preflight-repair-ahead.txt" || return 1
  git -C "$repo" add preflight-repair-ahead.txt || return 1
  git -C "$repo" commit -m "test: ahead-only repair branch" >/dev/null 2>&1 || return 1
  git -C "$repo" checkout main >/dev/null 2>&1 || return 1
  mkdir -p "$fake_bin" || return 1
  cat >"$fake_bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '{"number":242,"state":"%s","headRefName":"%s"}\n' "${FAKE_PR_STATE:-OPEN}" "${FAKE_PR_HEAD:-feature/preflight-repair}"
EOF
  chmod +x "$fake_bin/gh" || return 1

  if (
    cd "$repo" || return 1
    repo-automation/bin/codex-slice-preflight --check-only --branch=feature/preflight-non-repair --json >"$non_repair_output"
  ) && python3 -m json.tool "$non_repair_output" >/dev/null &&
    smoke_json_assert "$non_repair_output" 'data.get("result") == "pass" and data.get("mode") == "check-only" and "repair_of_pr" not in data and "repair_pr_head" not in data'; then
    test_pass "non-repair preflight JSON omits repair-only fields"
  else
    test_fail "non-repair preflight JSON omits repair-only fields"
    return 1
  fi

  if (
    cd "$repo" || return 1
    PATH="$fake_bin:$PATH" repo-automation/bin/codex-slice-preflight --branch="$branch" --repair-of-pr=242 --json >"$output"
  ) && smoke_json_assert "$output" 'data.get("result") == "pass" and data.get("mode") == "repair" and data.get("repair_of_pr") == "242" and data.get("repair_pr_head") == "feature/preflight-repair" and data.get("divergence") == "0\t1"' &&
    [ "$(git -C "$repo" branch --show-current)" = "$branch" ]; then
    test_pass "repair preflight allows an ahead-only existing open PR branch"
  else
    test_fail "repair preflight allows an ahead-only existing open PR branch"
    return 1
  fi

  if (
    cd "$repo" || return 1
    git checkout main >/dev/null 2>&1 || return 1
    PATH="$fake_bin:$PATH" FAKE_PR_HEAD=feature/missing repo-automation/bin/codex-slice-preflight --branch=feature/missing --repair-of-pr=242 --json >"$missing_output"
  ); then
    test_fail "repair preflight refuses to create a missing branch"
    return 1
  elif git -C "$repo" show-ref --verify --quiet refs/heads/feature/missing; then
    test_fail "repair preflight refuses to create a missing branch"
    return 1
  else
    test_pass "repair preflight refuses to create a missing branch"
  fi

  if (
    cd "$repo" || return 1
    PATH="$fake_bin:$PATH" FAKE_PR_HEAD=feature/other repo-automation/bin/codex-slice-preflight --branch="$branch" --repair-of-pr=242 --json >"$mismatch_output"
  ); then
    test_fail "repair preflight rejects PR branch mismatch"
    return 1
  elif smoke_json_assert "$mismatch_output" 'data.get("result") == "fail" and "mismatch" in data.get("stop_reason", "")'; then
    test_pass "repair preflight rejects PR branch mismatch"
  else
    test_fail "repair preflight rejects PR branch mismatch"
    return 1
  fi

  git -C "$repo" checkout main >/dev/null 2>&1 || return 1
  git -C "$repo" branch "$behind_branch" || return 1
  git -C "$repo" switch -c "$diverged_branch" >/dev/null 2>&1 || return 1
  printf 'diverged repair\n' >"$repo/preflight-repair-diverged.txt" || return 1
  git -C "$repo" add preflight-repair-diverged.txt || return 1
  git -C "$repo" commit -m "test: diverged repair branch" >/dev/null 2>&1 || return 1
  git -C "$repo" checkout main >/dev/null 2>&1 || return 1
  printf 'main advances\n' >"$repo/preflight-repair-main.txt" || return 1
  git -C "$repo" add preflight-repair-main.txt || return 1
  git -C "$repo" commit -m "test: advance main" >/dev/null 2>&1 || return 1
  git -C "$repo" update-ref refs/remotes/origin/main "$(git -C "$repo" rev-parse main)" || return 1

  if (
    cd "$repo" || return 1
    PATH="$fake_bin:$PATH" FAKE_PR_HEAD="$behind_branch" repo-automation/bin/codex-slice-preflight --branch="$behind_branch" --repair-of-pr=242 --json >"$behind_output"
  ); then
    test_fail "repair preflight rejects a behind repair branch"
    return 1
  elif smoke_json_assert "$behind_output" 'data.get("result") == "fail" and data.get("divergence") == "1\t0" and "repair branch is behind origin/main" in data.get("stop_reason", "")'; then
    test_pass "repair preflight rejects a behind repair branch"
  else
    test_fail "repair preflight rejects a behind repair branch"
    return 1
  fi

  git -C "$repo" checkout main >/dev/null 2>&1 || return 1
  if (
    cd "$repo" || return 1
    PATH="$fake_bin:$PATH" FAKE_PR_HEAD="$diverged_branch" repo-automation/bin/codex-slice-preflight --branch="$diverged_branch" --repair-of-pr=242 --json >"$diverged_output"
  ); then
    test_fail "repair preflight rejects a diverged repair branch"
    return 1
  elif smoke_json_assert "$diverged_output" 'data.get("result") == "fail" and data.get("divergence") == "1\t1" and "repair branch diverged from origin/main" in data.get("stop_reason", "")'; then
    test_pass "repair preflight rejects a diverged repair branch"
  else
    test_fail "repair preflight rejects a diverged repair branch"
    return 1
  fi
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/codex-slice-preflight.sh EOF
