#!/usr/bin/env bash
# repo-automation/tests/contracts/repo-flow-submit.sh

set -u
set -o pipefail

# shellcheck disable=SC2034
REPO_FLOW_CONTRACT_SOURCE_ONLY=1
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/repo-flow.sh"

repo_flow_submit_contract_summary_field() {
  local summary_file="$1"
  local field="$2"

  smoke_extract_final_summary_block "$summary_file" | awk -F= -v field="$field" '$1 == field { sub("^[^=]*=", "", $0); print; exit }'
}

repo_flow_submit_contract_assert_review_order() {
  local stderr_file="$1"
  local expected_text="$2"

  python3 - "$stderr_file" "$expected_text" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
expected = sys.argv[2]
summary = "===== FINAL SUMMARY =====\n"
summary_end = "===== END =====\n"
block_start = "===== PR REVIEW REQUEST =====\n"
block_end = "===== END PR REVIEW REQUEST =====\n"

if text.count(summary) != 1 or text.count(block_start) != 1 or text.count(block_end) != 1:
    raise SystemExit(1)
summary_index = text.index(summary)
summary_end_index = text.index(summary_end, summary_index) + len(summary_end)
block_index = text.index("\n" + block_start)
if not summary_index < summary_end_index <= block_index:
    raise SystemExit(1)
block_text = text[text.index(block_start, block_index) + len(block_start):text.index(block_end, block_index)]
if expected not in block_text:
    raise SystemExit(1)
PY
}

repo_flow_submit_contract_assert_head_unchanged() {
  local repo_dir="$1"
  local expected_head="$2"

  [ "$(git -C "$repo_dir" rev-parse HEAD)" = "$expected_head" ]
}

# smoke_test_dir is assigned by smoke_setup_temp_repo from the sourced repo-flow contract helpers.
# shellcheck disable=SC2154
# smoke_test_dir is assigned by smoke_setup_temp_repo from the sourced repo-flow contract helpers.
# shellcheck disable=SC2154
repo_flow_submit_contract_main_impl() {
  local status=0
  local gh_stub_dir=""
  local local_bash_path=""
  local stdout_file=""
  local stderr_file=""
  local create_log_file=""
  local review_file=""
  local review_path=""
  local review_block_path=""
  local head_before=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154
  gh_stub_dir="$smoke_test_base/gh-stub"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-no-review" || return 1
  stdout_file="$smoke_test_base/repo-flow-submit-no-review.out"
  stderr_file="$smoke_test_base/repo-flow-submit-no-review.stderr"
  printf '\nrepo-flow submit no review request\n' >> "$smoke_test_dir/README.md" || return 1
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_EMPTY=1 \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/931' \
    "$local_bash_path" repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit no review' > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/931' ] &&
    [ ! -s "$stderr_file" ] &&
    ! grep -Fq 'PR REVIEW REQUEST' "$stdout_file"; then
    test_pass "repo-flow submit without review request flags preserves compact output"
  else
    test_fail "repo-flow submit without review request flags preserves compact output"
    status=1
  fi

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-review-file" || return 1
  stdout_file="$smoke_test_base/repo-flow-submit-review-file.out"
  stderr_file="$smoke_test_base/repo-flow-submit-review-file.stderr"
  create_log_file="$smoke_test_base/repo-flow-submit-review-file-create.log"
  review_file="$smoke_test_base/repo-flow-submit-review-file.md"
  cat > "$review_file" <<'EOF'
Please review <TITLE>.
PR: <PR_URL>
Branch: <BRANCH>
EOF
  printf '\nrepo-flow submit review file\n' >> "$smoke_test_dir/README.md" || return 1
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_EMPTY=1 \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_CREATE_NUMBER=932 \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/932' \
    "$local_bash_path" repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit review file' --review-request-file="$review_file" --explain > "$stdout_file" 2> "$stderr_file"
  ); then
    review_path="$(repo_flow_submit_contract_summary_field "$stderr_file" review_request_path)"
    review_block_path="$(repo_flow_submit_contract_summary_field "$stderr_file" review_request_block_path)"
    if [ ! -s "$stdout_file" ] &&
      smoke_assert_single_final_summary_block "$stderr_file" &&
      smoke_assert_final_summary_field "$stderr_file" url_or_stop https://github.com/i-schuyler/repo-automation-template/pull/932 &&
      [ -f "$review_path" ] &&
      [ -f "$review_block_path" ] &&
      grep -Fxq 'Please review repo-flow submit review file.' "$review_path" &&
      grep -Fxq 'PR: https://github.com/i-schuyler/repo-automation-template/pull/932' "$review_path" &&
      grep -Fxq 'Branch: feature/repo-flow-submit-review-file' "$review_path" &&
      grep -Fxq '===== PR REVIEW REQUEST =====' "$review_block_path" &&
      repo_flow_submit_contract_assert_review_order "$stderr_file" 'PR: https://github.com/i-schuyler/repo-automation-template/pull/932'; then
      test_pass "repo-flow submit renders --review-request-file after FINAL SUMMARY"
    else
      test_fail "repo-flow submit renders --review-request-file after FINAL SUMMARY"
      status=1
    fi
  else
    test_fail "repo-flow submit renders --review-request-file after FINAL SUMMARY"
    status=1
  fi

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-review-id" || return 1
  mkdir -p "$smoke_test_dir/.prompts" || return 1
  cat > "$smoke_test_dir/.prompts/repo-review.md" <<'EOF'
Review <PR_URL>
Title <TITLE>
Branch <BRANCH>
EOF
  git -C "$smoke_test_dir" add .prompts/repo-review.md || return 1
  git -C "$smoke_test_dir" commit -m "add repo-flow submit review preset" >/dev/null || return 1
  stdout_file="$smoke_test_base/repo-flow-submit-review-id.out"
  stderr_file="$smoke_test_base/repo-flow-submit-review-id.stderr"
  printf '\nrepo-flow submit review id\n' >> "$smoke_test_dir/README.md" || return 1
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_EMPTY=1 \
    GH_STUB_PR_CREATE_NUMBER=933 \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/933' \
    "$local_bash_path" repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit review id' --review-request-id=repo-review --explain > "$stdout_file" 2> "$stderr_file"
  ) && [ ! -s "$stdout_file" ] &&
    smoke_assert_final_summary_field "$stderr_file" url_or_stop https://github.com/i-schuyler/repo-automation-template/pull/933 &&
    repo_flow_submit_contract_assert_review_order "$stderr_file" 'Review https://github.com/i-schuyler/repo-automation-template/pull/933' &&
    grep -Fq 'Title repo-flow submit review id' "$stderr_file" &&
    grep -Fq 'Branch feature/repo-flow-submit-review-id' "$stderr_file"; then
    test_pass "repo-flow submit renders --review-request-id presets"
  else
    test_fail "repo-flow submit renders --review-request-id presets"
    status=1
  fi

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-review-validation" || return 1
  review_file="$smoke_test_base/repo-flow-submit-review-validation.md"
  cat > "$review_file" <<'EOF'
Review <PR_URL>
EOF
  printf '\nrepo-flow submit review validation\n' >> "$smoke_test_dir/README.md" || return 1
  git -C "$smoke_test_dir" add README.md || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  stderr_file="$smoke_test_base/repo-flow-submit-review-mutual.stderr"
  create_log_file="$smoke_test_base/repo-flow-submit-review-mutual-create.log"
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit review invalid' --review-request-file="$review_file" --review-request-id=repo-review >/dev/null 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit rejects mutually exclusive review request sources"
    status=1
  elif grep -Fxq 'STOP: use either --review-request-file or --review-request-id, not both' "$stderr_file" &&
    repo_flow_submit_contract_assert_head_unchanged "$smoke_test_dir" "$head_before" &&
    [ ! -s "$create_log_file" ]; then
    test_pass "repo-flow submit rejects mutually exclusive review request sources"
  else
    test_fail "repo-flow submit rejects mutually exclusive review request sources"
    status=1
  fi

  stderr_file="$smoke_test_base/repo-flow-submit-review-invalid-id.stderr"
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit review invalid' --review-request-id='bad/id' >/dev/null 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit rejects invalid review request IDs"
    status=1
  elif grep -Fxq 'STOP: invalid review request id: bad/id' "$stderr_file" &&
    repo_flow_submit_contract_assert_head_unchanged "$smoke_test_dir" "$head_before"; then
    test_pass "repo-flow submit rejects invalid review request IDs"
  else
    test_fail "repo-flow submit rejects invalid review request IDs"
    status=1
  fi

  stderr_file="$smoke_test_base/repo-flow-submit-review-missing-preset.stderr"
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit review invalid' --review-request-id=missing-preset >/dev/null 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit rejects missing review request presets before mutation"
    status=1
  elif grep -Fq 'STOP: review request preset does not exist:' "$stderr_file" &&
    repo_flow_submit_contract_assert_head_unchanged "$smoke_test_dir" "$head_before"; then
    test_pass "repo-flow submit rejects missing review request presets before mutation"
  else
    test_fail "repo-flow submit rejects missing review request presets before mutation"
    status=1
  fi

  return "$status"
}

repo_flow_submit_contract_main() {
  smoke_run_focused_contract_wrapper repo_flow_submit_contract_main_impl "$@"
}

repo_flow_submit_contract_main "$@"
# repo-automation/tests/contracts/repo-flow-submit.sh EOF
