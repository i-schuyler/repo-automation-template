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

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/slice-handoff.sh EOF
