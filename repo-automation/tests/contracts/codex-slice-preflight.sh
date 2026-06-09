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
  smoke_run_named_check "smoke:preflight-json" smoke_check_preflight_json || return 1
  smoke_run_named_check "smoke:preflight-repair" smoke_check_preflight_repair
}

smoke_check_preflight_repair() {
  local repo="$smoke_test_base/preflight-repair-repo"
  local fake_bin="$smoke_test_base/preflight-repair-bin"
  local output="$smoke_test_base/preflight-repair.json"
  local missing_output="$smoke_test_base/preflight-repair-missing.json"
  local mismatch_output="$smoke_test_base/preflight-repair-mismatch.json"
  local behind_output="$smoke_test_base/preflight-repair-behind.json"
  local diverged_output="$smoke_test_base/preflight-repair-diverged.json"
  local branch="feature/preflight-repair"
  local behind_branch="feature/preflight-repair-behind"
  local diverged_branch="feature/preflight-repair-diverged"

  git clone --local --no-hardlinks "$smoke_test_dir" "$repo" >/dev/null 2>&1 || return 1
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
