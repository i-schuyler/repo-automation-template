#!/usr/bin/env bash
# shellcheck disable=SC2154
# repo-automation/tests/contracts/slice-handoff.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/slice-handoff.sh"

smoke_main_impl() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:slice-handoff-contract" smoke_check_slice_handoff_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_check_slice_handoff_contract() {
  local status=0
  local smoke_check_root="$smoke_test_base/slice-handoff"
  local valid_none_file="$smoke_check_root/valid-none.md"
  local valid_submit_file="$smoke_check_root/valid-submit.md"
  local valid_none_out_dir="$smoke_test_base/out-valid-none"
  local valid_submit_out_dir="$smoke_test_base/out-valid-submit"
  local valid_quiet_out_dir="$smoke_test_base/out-quiet"
  local invalid_out_dir="$smoke_test_base/out-invalid-validation"
  local inside_repo_out_dir="$smoke_repo_root/slice-handoff-out-inside-repo"
  local expected_none_stdout
  local expected_submit_stdout
  local expected_none_prompt
  local expected_submit_prompt
  local expected_submit_body
  local expected_none_summary
  local expected_quiet_summary
  local expected_submit_summary
  local missing_schema_file="$smoke_check_root/missing-schema.md"
  local invalid_schema_file="$smoke_check_root/invalid-schema.md"
  local missing_branch_file="$smoke_check_root/missing-branch.md"
  local invalid_branch_file="$smoke_check_root/invalid-branch.md"
  local invalid_profile_file="$smoke_check_root/invalid-profile.md"
  local missing_commit_file="$smoke_check_root/missing-commit.md"
  local missing_pr_body_file="$smoke_check_root/missing-pr-body.md"
  local placeholder_file="$smoke_check_root/placeholder.md"
  local lifecycle_file="$smoke_check_root/lifecycle.md"
  local valid_prompt="Implement the slice exactly as specified."
  local submit_prompt="Implement the slice and prepare the PR body."
  local submit_body

  mkdir -p "$smoke_check_root" || return 1

  if smoke_slice_handoff_assert_metadata; then
    test_pass "slice-handoff metadata matches helper object"
  else
    test_fail "slice-handoff metadata matches helper object"
    status=1
  fi

  submit_body="$(cat <<'EOF'
## Scope

Slice handoff smoke.

## What changed

Nothing.

## What did not change

Nothing.

## Verification status

Validated with slice-handoff and pr-body-check.

## User-visible behavior changes

None.

## Stop conditions encountered

None.

## Re-entry hint

Review the PR and continue the slice.
EOF
)"
  expected_none_prompt="$(printf '%s' "$valid_prompt")"
  expected_submit_prompt="$(printf '%s' "$submit_prompt")"
  expected_submit_body="$(printf '%s' "$submit_body")"
  expected_none_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-smoke\ntitle=Slice handoff smoke\ncodex_profile=default\nsubmit_mode=none\ncommit_message=\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=' "$valid_none_out_dir")"
  expected_quiet_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-smoke\ntitle=Slice handoff smoke\ncodex_profile=default\nsubmit_mode=none\ncommit_message=\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=' "$valid_quiet_out_dir")"
  expected_submit_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-submit\ntitle=Slice handoff submit smoke\ncodex_profile=review\nsubmit_mode=repo-flow-submit-all\ncommit_message=chore: slice-handoff smoke\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s/pr-body.md' "$valid_submit_out_dir" "$valid_submit_out_dir")"
  expected_none_stdout="$(printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\nsummary_path=%s/slice-handoff-summary.txt' "$valid_none_out_dir" "$valid_none_out_dir" "$valid_none_out_dir")"
  expected_submit_stdout="$(printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s/pr-body.md\nsummary_path=%s/slice-handoff-summary.txt' "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir")"

  smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" || return 1
  smoke_slice_handoff_write_file "$valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" || return 1

  if smoke_slice_handoff_expect_success "valid-none" "pass" "" --file="$valid_none_file" --plan-only; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_success "quiet-success" "" "" --file="$valid_none_file" --plan-only --quiet; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_success "valid-submit" "pass" "" --file="$valid_submit_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    rm -rf -- "$valid_none_out_dir" &&
      smoke_slice_handoff_expect_success "out-dir-none" "$expected_none_stdout" "" --file="$valid_none_file" --plan-only --out-dir="$valid_none_out_dir" &&
      smoke_slice_handoff_assert_text_file "$valid_none_out_dir/codex-prompt.md" "$expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$valid_none_out_dir/slice-handoff-summary.txt" "$expected_none_summary"
  ); then
    :
  else
    test_fail "out-dir-none artifacts"
    status=1
  fi

  if (
    rm -rf -- "$valid_submit_out_dir" &&
      smoke_slice_handoff_expect_success "out-dir-submit" "$expected_submit_stdout" "" --file="$valid_submit_file" --plan-only --out-dir="$valid_submit_out_dir" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/codex-prompt.md" "$expected_submit_prompt" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/pr-body.md" "$expected_submit_body" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/slice-handoff-summary.txt" "$expected_submit_summary"
  ); then
    :
  else
    test_fail "out-dir-submit artifacts"
    status=1
  fi

  if (
    rm -rf -- "$valid_quiet_out_dir" &&
      smoke_slice_handoff_run "$smoke_test_base/slice-handoff-quiet-out.out" "$smoke_test_base/slice-handoff-quiet-out.err" --file="$valid_none_file" --plan-only --quiet --out-dir="$valid_quiet_out_dir" &&
      [ ! -s "$smoke_test_base/slice-handoff-quiet-out.out" ] &&
      [ ! -s "$smoke_test_base/slice-handoff-quiet-out.err" ] &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/codex-prompt.md" "$expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/slice-handoff-summary.txt" "$expected_quiet_summary"
  ); then
    :
  else
    test_fail "out-dir-quiet artifacts"
    status=1
  fi

  if (
    rm -rf -- "$inside_repo_out_dir" &&
      smoke_slice_handoff_expect_failure "out-dir-inside-repo" "out-dir must be outside the repo root" "choose a directory outside the current repo root" --file="$valid_none_file" --plan-only --out-dir="$inside_repo_out_dir" &&
      [ ! -e "$inside_repo_out_dir" ]
  ); then
    :
  else
    test_fail "out-dir-inside-repo artifacts"
    status=1
  fi

  if smoke_slice_handoff_expect_failure "missing-file" "missing required --file" "use --file=<path> with a readable handoff file" --plan-only; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "file-format" "missing flag value: --file" "use --file=<path>" --file "$valid_none_file" --plan-only; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "empty-file" "empty flag value: --file" "use --file=<path>" --file= --plan-only; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "missing-out-dir-value" "missing flag value: --out-dir" "use --out-dir=<path>" --file="$valid_none_file" --plan-only --out-dir; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "empty-out-dir" "empty flag value: --out-dir" "use --out-dir=<path>" --file="$valid_none_file" --plan-only --out-dir=; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "positional-out-dir" "unknown argument: out-dir" "run repo-automation/bin/slice-handoff --help" --file="$valid_none_file" --plan-only out-dir; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "missing-plan-only" "missing required --plan-only" "pass --plan-only to validate the handoff without executing it" --file="$valid_none_file"; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "unknown-flag" "unknown flag: --whatever" "run repo-automation/bin/slice-handoff --help" --file="$valid_none_file" --plan-only --whatever; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "execute-flag" "unsupported flag: --execute" "use --plan-only; execute mode is not implemented" --file="$valid_none_file" --plan-only --execute; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "submit-flag" "unsupported flag: --submit" "slice-handoff only accepts --plan-only for now" --file="$valid_none_file" --plan-only --submit=repo-flow-submit-all; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$missing_schema_file" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
filtered = [line for line in source if not line.startswith('schema: ')]
Path(sys.argv[2]).write_text('\n'.join(filtered) + '\n', encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "missing-schema" "missing schema" "set schema: repo-automation-slice-handoff/v1" --file="$missing_schema_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$invalid_schema_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('schema: repo-automation-slice-handoff/v1', 'schema: repo-automation-slice-handoff/v2', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "invalid-schema" "invalid schema" "set schema: repo-automation-slice-handoff/v1" --file="$invalid_schema_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$missing_branch_file" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
filtered = [line for line in source if not line.startswith('branch: ')]
Path(sys.argv[2]).write_text('\n'.join(filtered) + '\n', encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "missing-branch" "missing branch" "set a non-empty branch in the envelope" --file="$missing_branch_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$invalid_branch_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('branch: feature/slice-handoff-smoke', 'branch: -bad branch', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "invalid-branch" "invalid branch: -bad branch" "use a conservative feature branch name without whitespace or shell metacharacters" --file="$invalid_branch_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$invalid_profile_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('codex_profile: default', 'codex_profile: ../profile', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "invalid-profile" "invalid codex_profile: ../profile" "use one of default, lean, medium, high, repair, or review" --file="$invalid_profile_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_submit_file" "$missing_commit_file" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
filtered = [line for line in source if not line.startswith('commit_message: ')]
Path(sys.argv[2]).write_text('\n'.join(filtered) + '\n', encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "missing-commit-message" "missing commit_message" "set commit_message when submit_mode is repo-flow-submit-all" --file="$missing_commit_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_submit_file" "$missing_pr_body_file" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
filtered = []
skip = False
for line in source:
    if line == '## PR Body':
        skip = True
        continue
    if skip:
        continue
    filtered.append(line)
Path(sys.argv[2]).write_text('\n'.join(filtered) + '\n', encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "missing-pr-body" "missing ## PR Body" "add ## PR Body when submit_mode is repo-flow-submit-all" --file="$missing_pr_body_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$placeholder_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Use previous chat and do the rest.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "placeholder-reject" "unsafe placeholder text in Codex Prompt: use previous chat" "replace the placeholder prompt with concrete slice instructions" --file="$placeholder_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Please create a PR and merge it after checkout.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-reject" "Codex Prompt contains lifecycle instruction: create a pr" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --plan-only; then
    :
  else
    status=1
  fi

  if (
    rm -rf -- "$invalid_out_dir" &&
      smoke_slice_handoff_expect_failure "out-dir-validation-fail" "unsafe placeholder text in Codex Prompt: use previous chat" "replace the placeholder prompt with concrete slice instructions" --file="$placeholder_file" --plan-only --out-dir="$invalid_out_dir" &&
      [ ! -e "$invalid_out_dir" ]
  ); then
    :
  else
    test_fail "out-dir-validation-fail artifacts"
    status=1
  fi

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/slice-handoff.sh EOF
