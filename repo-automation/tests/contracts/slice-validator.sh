#!/usr/bin/env bash
# shellcheck disable=SC2154

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

smoke_slice_validator_run() {
  local stdout_file="$1"
  local stderr_file="$2"
  shift 2

  (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator "$@" >"$stdout_file" 2>"$stderr_file"
  )
}

smoke_slice_validator_write_handoff() {
  local path="$1"
  local branch="$2"
  local title="$3"
  local codex_profile="$4"
  local submit_mode="$5"
  local commit_message="$6"
  local prompt_text="$7"
  local pr_body_text="${8:-}"
  local review_request_text="${9:-}"
  local pr_review_prompt_id="${10:-}"

  python3 - "$path" "$branch" "$title" "$codex_profile" "$submit_mode" "$commit_message" "$prompt_text" "$pr_body_text" "$review_request_text" "$pr_review_prompt_id" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
branch = sys.argv[2]
title = sys.argv[3]
codex_profile = sys.argv[4]
submit_mode = sys.argv[5]
commit_message = sys.argv[6]
prompt_text = sys.argv[7]
pr_body_text = sys.argv[8]
review_request_text = sys.argv[9]
pr_review_prompt_id = sys.argv[10]

lines = [
    "schema: repo-automation-slice-handoff/v1",
    f"branch: {branch}",
    f"title: {title}",
    f"codex_profile: {codex_profile}",
    f"submit_mode: {submit_mode}",
    f"commit_message: {commit_message}",
]
if pr_review_prompt_id:
    lines.append(f"pr_review_prompt_id: {pr_review_prompt_id}")
lines += [
    "",
    "# Slice Handoff",
    "",
    "## Codex Prompt",
    prompt_text,
]
if pr_body_text:
    lines += ["", "## PR Body", pr_body_text]
if review_request_text:
    lines += ["", "## PR Review Request", review_request_text]
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

smoke_slice_validator_assert_json_file() {
  local json_file="$1"
  local expr="$2"

  python3 - "$json_file" "$expr" <<'PY'
import json
from pathlib import Path
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
if not eval(sys.argv[2], {}, {"data": data}):  # controlled test expression
    raise SystemExit(1)
PY
}

smoke_slice_validator_assert_prompt_case() {
  local handoff_file="$1"
  local stdout_file="$2"
  local stderr_file="$3"
  local expect_result="$4"
  local reason_fragment="${5:-}"
  local fix_fragment="${6:-}"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$handoff_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    [ "$expect_result" = "pass" ]
  else
    [ "$expect_result" = "fail" ] || return 1
    grep -Fq "$reason_fragment" "$stderr_file" && grep -Fq "$fix_fragment" "$stderr_file"
  fi
}

smoke_check_slice_validator_contract() {
  local status=0
  local root="$smoke_test_base/slice-validator"
  local valid_none_file="$root/valid-none.md"
  local valid_submit_file="$root/valid-submit.md"
  local valid_repair_file="$root/valid-repair.md"
  local missing_repair_pr_file="$root/missing-repair-pr.md"
  local missing_session_id_file="$root/missing-session-id.md"
  local unsafe_session_id_file="$root/unsafe-session-id.md"
  local outside_repo_root_file="$smoke_test_base/slice-validator-outside-root/slice-validator-outside-root.md"
  local invalid_schema_file="$root/invalid-schema.md"
  local missing_schema_file="$root/missing-schema.md"
  local missing_branch_file="$root/missing-branch.md"
  local invalid_branch_file="$root/invalid-branch.md"
  local invalid_profile_file="$root/invalid-profile.md"
  local missing_commit_file="$root/missing-commit.md"
  local missing_pr_body_file="$root/missing-pr-body.md"
  local invalid_pr_body_file="$root/invalid-pr-body.md"
  local conflict_review_file="$root/conflict-review.md"
  local invalid_prompt_id_file="$root/invalid-prompt-id.md"
  local missing_preset_file="$root/missing-preset.md"
  local unsafe_prompt_file="$root/unsafe-prompt.md"
  local lifecycle_prompt_file="$root/lifecycle-prompt.md"
  local self_mod_prompt_file="$root/self-modifying-prompt.md"
  local self_target_run_file="$root/self-target-run.md"
  local self_target_invoke_file="$root/self-target-invoke.md"
  local self_target_execute_file="$root/self-target-execute.md"
  local self_target_negative_file="$root/self-target-negative.md"
  local valid_body_file="$root/valid-body.md"
  local invalid_body_file="$root/invalid-body.md"
  local help_stdout="$smoke_test_base/slice-validator-help.out"
  local help_stderr="$smoke_test_base/slice-validator-help.err"
  local stdout_file="$smoke_test_base/slice-validator.out"
  local stderr_file="$smoke_test_base/slice-validator.err"
  local json_stdout="$smoke_test_base/slice-validator.json"
  local json_stderr="$smoke_test_base/slice-validator.json.err"
  local quiet_stdout="$smoke_test_base/slice-validator.quiet.out"
  local quiet_stderr="$smoke_test_base/slice-validator.quiet.err"
  local manifest_path=""

  mkdir -p "$root" || return 1
  mkdir -p "$(dirname "$outside_repo_root_file")" || return 1
  mkdir -p "$smoke_test_dir/.prompts" || return 1
  cp -- "$smoke_repo_root/.prompts/repo-automation-template-pr-review.md" "$smoke_test_dir/.prompts/" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --help >"$smoke_test_base/pr-body-check-help.out"
  ) && grep -Fq -- '--body-file=<path>' "$smoke_test_base/pr-body-check-help.out"; then
    test_pass "pr-body-check help advertises body-file flag"
  else
    test_fail "pr-body-check help advertises body-file flag"
    status=1
  fi

  cat > "$valid_body_file" <<'EOF'
## Scope

Slice validator smoke.

## What changed

Nothing.

## What did not change

Nothing.

## Verification status

Validated with pr-body-check.

## User-visible behavior changes

None.

## Stop conditions encountered

None.

## Re-entry hint

Review the PR and continue.
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$valid_body_file" --quiet >"$quiet_stdout" 2>"$quiet_stderr"
  ) && [ ! -s "$quiet_stdout" ] && [ ! -s "$quiet_stderr" ]; then
    test_pass "pr-body-check quiet success is silent"
  else
    test_fail "pr-body-check quiet success is silent"
    status=1
  fi

  printf 'placeholder body\n' > "$invalid_body_file" || return 1
  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$invalid_body_file" --quiet >"$quiet_stdout" 2>"$quiet_stderr"
  ); then
    test_fail "pr-body-check quiet failure is not silent"
    status=1
  elif grep -Fq 'result=fail' "$quiet_stderr" && grep -Fq 'code=' "$quiet_stderr" && grep -Fq 'step=' "$quiet_stderr" && grep -Fq 'reason=' "$quiet_stderr" && grep -Fq 'fix=' "$quiet_stderr" && [ ! -s "$quiet_stdout" ]; then
    test_pass "pr-body-check quiet failure uses QDE"
  else
    test_fail "pr-body-check quiet failure uses QDE"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$valid_body_file" --json >"$json_stdout" 2>"$json_stderr"
  ) && python3 -m json.tool "$json_stdout" >/dev/null && [ ! -s "$json_stderr" ]; then
    test_pass "pr-body-check JSON success is valid"
  else
    test_fail "pr-body-check JSON success is valid"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-body-check --body-file="$invalid_body_file" --json >"$json_stdout" 2>"$json_stderr"
  ); then
    test_fail "pr-body-check JSON failure is valid"
    status=1
  elif python3 -m json.tool "$json_stdout" >/dev/null && [ ! -s "$json_stderr" ] && smoke_slice_validator_assert_json_file "$json_stdout" 'data.get("result") == "fail" and data.get("code") and data.get("step") and data.get("reason") and data.get("fix")'; then
    test_pass "pr-body-check JSON failure is valid"
  else
    test_fail "pr-body-check JSON failure is valid"
    status=1
  fi

  smoke_slice_validator_write_handoff "$valid_none_file" "feature/slice-validator-smoke" "Slice validator smoke" "default" "none" "" "Implement the slice exactly as specified." "" "Please review this PR before merge."
  smoke_slice_validator_write_handoff "$valid_submit_file" "feature/slice-validator-submit" "Slice validator submit smoke" "review" "repo-flow-submit-all" "chore: slice-validator smoke" "Implement the slice and prepare the PR body." "$(cat "$valid_body_file")" "Please review this PR before merge."
  cp "$valid_submit_file" "$valid_repair_file" || return 1
  python3 - "$valid_repair_file" <<'PY' || return 1
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "branch: feature/slice-validator-submit\n"
repair = marker + "handoff_mode: repair\nrepair_of_pr: 242\nrepair_session: resume\ncodex_session_id: session-242\n"
path.write_text(text.replace(marker, repair, 1), encoding="utf-8")
PY
  cp "$valid_repair_file" "$missing_repair_pr_file" || return 1
  sed -i '/^repair_of_pr:/d' "$missing_repair_pr_file" || return 1
  cp "$valid_repair_file" "$missing_session_id_file" || return 1
  sed -i '/^codex_session_id:/d' "$missing_session_id_file" || return 1
  cp "$valid_repair_file" "$unsafe_session_id_file" || return 1
  sed -i 's|^codex_session_id:.*|codex_session_id: ../unsafe id|' "$unsafe_session_id_file" || return 1
  smoke_slice_validator_write_handoff "$outside_repo_root_file" "feature/slice-validator-outside-root" "Slice validator outside repo root" "default" "none" "" "Implement the slice exactly as specified." "" "" "repo-automation-template-pr-review"

  cp "$valid_submit_file" "$invalid_schema_file" || return 1
  python3 - "$invalid_schema_file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8').replace('schema: repo-automation-slice-handoff/v1', 'schema: repo-automation-slice-handoff/v2', 1)
path.write_text(text, encoding='utf-8')
PY
  cp "$valid_submit_file" "$missing_schema_file" || return 1
  python3 - "$missing_schema_file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
lines = path.read_text(encoding='utf-8').splitlines()
path.write_text('\n'.join(lines[1:]) + '\n', encoding='utf-8')
PY
  cp "$valid_submit_file" "$missing_branch_file" || return 1
  python3 - "$missing_branch_file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8').replace('branch: feature/slice-validator-submit\n', '', 1)
path.write_text(text, encoding='utf-8')
PY
  cp "$valid_submit_file" "$invalid_branch_file" || return 1
  python3 - "$invalid_branch_file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8').replace('branch: feature/slice-validator-submit', 'branch: -bad branch', 1)
path.write_text(text, encoding='utf-8')
PY
  cp "$valid_submit_file" "$invalid_profile_file" || return 1
  python3 - "$invalid_profile_file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8').replace('codex_profile: review', 'codex_profile: invalid', 1)
path.write_text(text, encoding='utf-8')
PY
  cp "$valid_submit_file" "$missing_commit_file" || return 1
  python3 - "$missing_commit_file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8').replace('commit_message: chore: slice-validator smoke\n', 'commit_message:\n', 1)
path.write_text(text, encoding='utf-8')
PY
  smoke_slice_validator_write_handoff "$missing_pr_body_file" "feature/slice-validator-missing-body" "Slice validator missing PR body" "review" "repo-flow-submit-all" "chore: slice-validator smoke" "Implement the slice and prepare the PR body." "" "Please review this PR before merge."
  smoke_slice_validator_write_handoff "$invalid_pr_body_file" "feature/slice-validator-invalid-body" "Slice validator invalid body" "review" "repo-flow-submit-all" "chore: slice-validator smoke" "Implement the slice and prepare the PR body." "not a valid body" "Please review this PR before merge."
  smoke_slice_validator_write_handoff "$conflict_review_file" "feature/slice-validator-conflict" "Slice validator review conflict" "default" "none" "" "Implement the slice exactly as specified." "" "Please review this PR before merge." "repo-review"
  smoke_slice_validator_write_handoff "$invalid_prompt_id_file" "feature/slice-validator-prompt-id" "Slice validator invalid preset" "default" "none" "" "Implement the slice exactly as specified." "" "" "-bad"
  smoke_slice_validator_write_handoff "$missing_preset_file" "feature/slice-validator-missing-preset" "Slice validator missing preset" "default" "none" "" "Implement the slice exactly as specified." "" "" "missing-preset"
  smoke_slice_validator_write_handoff "$unsafe_prompt_file" "feature/slice-validator-unsafe" "Slice validator unsafe prompt" "default" "none" "" "use previous chat and do the rest" "" ""
  smoke_slice_validator_write_handoff "$lifecycle_prompt_file" "feature/slice-validator-lifecycle" "Slice validator lifecycle prompt" "default" "none" "" "Please create a PR." "" ""
  smoke_slice_validator_write_handoff "$self_mod_prompt_file" "feature/slice-validator-self-mod" "Slice validator self-mod prompt" "default" "none" "" "Please update repo-automation/bin/slice-handoff to use the new gate." "" ""
  smoke_slice_validator_write_handoff "$self_target_run_file" "feature/slice-validator-self-target-run" "Slice validator self-target run" "default" "none" "" "Please run repo-automation/bin/slice-handoff for this validation step." "" ""
  smoke_slice_validator_write_handoff "$self_target_invoke_file" "feature/slice-validator-self-target-invoke" "Slice validator self-target invoke" "default" "none" "" "Please invoke repo-automation/bin/slice-handoff after you review the prompt." "" ""
  smoke_slice_validator_write_handoff "$self_target_execute_file" "feature/slice-validator-self-target-execute" "Slice validator self-target execute" "default" "none" "" "Please execute repo-automation/bin/slice-handoff as the orchestration step." "" ""
  smoke_slice_validator_write_handoff "$self_target_negative_file" "feature/slice-validator-self-target-negative" "Slice validator self-target negative" "default" "none" "" "Do not edit repo-automation/bin/slice-handoff." "" ""

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --help >"$help_stdout" 2>"$help_stderr"
  ) && grep -Fq -- 'Usage: repo-automation/bin/slice-validator' "$help_stdout" && grep -Fq -- '--file=<path>' "$help_stdout" && grep -Fq -- '--manifest-out=<path>' "$help_stdout" && grep -Fq -- '--artifact-dir=<path>' "$help_stdout" && grep -Fq -- '--submit' "$help_stdout" && [ ! -s "$help_stderr" ]; then
    test_pass "slice-validator help shows core flags"
  else
    test_fail "slice-validator help shows core flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$valid_repair_file" --repair --submit >"$stdout_file" 2>"$stderr_file"
  ) && grep -Fxq 'handoff_mode=repair' "$stdout_file" && grep -Fxq 'repair_of_pr=242' "$stdout_file" && grep -Fxq 'codex_session_id=session-242' "$stdout_file"; then
    test_pass "slice-validator validates repair metadata"
  else
    test_fail "slice-validator validates repair metadata"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$missing_repair_pr_file" --repair >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects missing repair_of_pr"
    status=1
  elif grep -Fq 'missing repair_of_pr' "$stderr_file"; then
    test_pass "slice-validator rejects missing repair_of_pr"
  else
    test_fail "slice-validator rejects missing repair_of_pr"
    status=1
  fi

  for repair_file in "$missing_session_id_file" "$unsafe_session_id_file"; do
    if (
      cd "$smoke_test_dir" || return 1
      repo-automation/bin/slice-validator --file="$repair_file" --repair >"$stdout_file" 2>"$stderr_file"
    ); then
      test_fail "slice-validator rejects missing or unsafe resume session ID"
      status=1
    elif grep -Eq '(missing|unsafe) codex_session_id' "$stderr_file"; then
      test_pass "slice-validator rejects missing or unsafe resume session ID"
    else
      test_fail "slice-validator rejects missing or unsafe resume session ID"
      status=1
    fi
  done

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects missing --file"
    status=1
  elif grep -Fq 'missing required --file' "$stderr_file" && grep -Fq 'fix:' "$stderr_file"; then
    test_pass "slice-validator rejects missing --file"
  else
    test_fail "slice-validator rejects missing --file"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$root/missing.md" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects missing file"
    status=1
  elif grep -Fq 'missing handoff file:' "$stderr_file"; then
    test_pass "slice-validator rejects missing file"
  else
    test_fail "slice-validator rejects missing file"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$valid_none_file" >"$stdout_file" 2>"$stderr_file"
  ) && grep -Fxq 'pass' "$stdout_file" && grep -Fq 'manifest_path=' "$stdout_file" && grep -Fq 'next=codex-slice-preflight' "$stdout_file"; then
    manifest_path="$(grep -F 'manifest_path=' "$stdout_file" | head -n1 | cut -d= -f2-)"
    if [ -s "$manifest_path" ] && smoke_slice_validator_assert_json_file "$manifest_path" 'data.get("schema") == "repo-automation-slice-validator/v1" and data.get("validated_capabilities", {}).get("codex_run") is True and data.get("validated_capabilities", {}).get("repo_flow_submit") is False and data.get("next") == "codex-slice-preflight"'; then
      test_pass "slice-validator validates a non-submit handoff"
    else
      test_fail "slice-validator validates a non-submit handoff"
      status=1
    fi
  else
    test_fail "slice-validator validates a non-submit handoff"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$outside_repo_root_file" --json >"$json_stdout" 2>"$json_stderr"
  ) && python3 -m json.tool "$json_stdout" >/dev/null && [ ! -s "$json_stderr" ]; then
    if python3 - "$json_stdout" <<'PY'
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
manifest = Path(data["manifest_path"])
manifest_text = manifest.read_text(encoding='utf-8')
if '"review_request_source": "preset:repo-automation-template-pr-review"' not in manifest_text:
    raise SystemExit(1)
PY
    then
      test_pass "slice-validator resolves PR review presets from the repo root"
    else
      test_fail "slice-validator resolves PR review presets from the repo root"
      status=1
    fi
  else
    test_fail "slice-validator resolves PR review presets from the repo root"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$valid_submit_file" >"$stdout_file" 2>"$stderr_file"
  ) && grep -Fxq 'pass' "$stdout_file" && grep -Fq 'manifest_path=' "$stdout_file"; then
    manifest_path="$(grep -F 'manifest_path=' "$stdout_file" | head -n1 | cut -d= -f2-)"
    if smoke_slice_validator_assert_json_file "$manifest_path" 'data.get("validated_capabilities", {}).get("pr_body_check") is True and data.get("validated_capabilities", {}).get("repo_flow_submit") is False'; then
      test_pass "slice-validator grants submit-capable handoff without submit authorization"
    else
      test_fail "slice-validator grants submit-capable handoff without submit authorization"
      status=1
    fi
  else
    test_fail "slice-validator grants submit-capable handoff without submit authorization"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$valid_submit_file" --submit >"$stdout_file" 2>"$stderr_file"
  ) && grep -Fxq 'pass' "$stdout_file"; then
    manifest_path="$(grep -F 'manifest_path=' "$stdout_file" | head -n1 | cut -d= -f2-)"
    if smoke_slice_validator_assert_json_file "$manifest_path" 'data.get("validated_capabilities", {}).get("repo_flow_submit") is True and data.get("validated_capabilities", {}).get("pr_body_check") is True'; then
      test_pass "slice-validator grants submit when authorized and PR body is valid"
    else
      test_fail "slice-validator grants submit when authorized and PR body is valid"
      status=1
    fi
  else
    test_fail "slice-validator grants submit when authorized and PR body is valid"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$missing_schema_file" >"$json_stdout" 2>"$json_stderr"
  ); then
    test_fail "slice-validator rejects missing schema"
    status=1
  elif grep -Fq 'missing schema' "$json_stderr"; then
    test_pass "slice-validator rejects missing schema"
  else
    test_fail "slice-validator rejects missing schema"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$invalid_schema_file" --json >"$json_stdout" 2>"$json_stderr"
  ); then
    test_fail "slice-validator JSON failure is valid"
    status=1
  elif python3 -m json.tool "$json_stdout" >/dev/null && [ ! -s "$json_stderr" ] && smoke_slice_validator_assert_json_file "$json_stdout" 'data.get("result") == "fail" and data.get("code") and data.get("step") and data.get("reason") and data.get("fix")'; then
    test_pass "slice-validator JSON failure is valid"
  else
    test_fail "slice-validator JSON failure is valid"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$valid_none_file" --json >"$json_stdout" 2>"$json_stderr"
  ) && python3 -m json.tool "$json_stdout" >/dev/null && [ ! -s "$json_stderr" ] && smoke_slice_validator_assert_json_file "$json_stdout" 'data.get("result") == "pass" and data.get("manifest_path") and data.get("validated_capabilities", {}).get("codex_run") is True'; then
    test_pass "slice-validator JSON success is valid"
  else
    test_fail "slice-validator JSON success is valid"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$valid_none_file" --quiet >"$quiet_stdout" 2>"$quiet_stderr"
  ) && [ ! -s "$quiet_stdout" ] && [ ! -s "$quiet_stderr" ]; then
    test_pass "slice-validator quiet success is silent"
  else
    test_fail "slice-validator quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$missing_schema_file" --quiet >"$quiet_stdout" 2>"$quiet_stderr"
  ); then
    test_fail "slice-validator quiet failure is not silent"
    status=1
  elif grep -Fq 'result=fail' "$quiet_stderr" && grep -Fq 'code=' "$quiet_stderr" && grep -Fq 'step=' "$quiet_stderr" && grep -Fq 'reason=' "$quiet_stderr" && grep -Fq 'fix=' "$quiet_stderr" && [ ! -s "$quiet_stdout" ]; then
    test_pass "slice-validator quiet failure uses QDE"
  else
    test_fail "slice-validator quiet failure uses QDE"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$invalid_branch_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects invalid branch"
    status=1
  elif grep -Fq 'invalid branch:' "$stderr_file"; then
    test_pass "slice-validator rejects invalid branch"
  else
    test_fail "slice-validator rejects invalid branch"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$invalid_profile_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects invalid codex_profile"
    status=1
  elif grep -Fq 'invalid codex_profile:' "$stderr_file"; then
    test_pass "slice-validator rejects invalid codex_profile"
  else
    test_fail "slice-validator rejects invalid codex_profile"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$missing_commit_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects missing commit_message for submit mode"
    status=1
  elif grep -Fq 'missing commit_message' "$stderr_file"; then
    test_pass "slice-validator rejects missing commit_message for submit mode"
  else
    test_fail "slice-validator rejects missing commit_message for submit mode"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$missing_pr_body_file" >"$stdout_file" 2>"$stderr_file"
  ) && grep -Fxq 'pass' "$stdout_file" && grep -Fq 'manifest_path=' "$stdout_file"; then
    manifest_path="$(grep -F 'manifest_path=' "$stdout_file" | head -n1 | cut -d= -f2-)"
    if smoke_slice_validator_assert_json_file "$manifest_path" 'data.get("validated_capabilities", {}).get("codex_run") is True and data.get("validated_capabilities", {}).get("pr_body_check") is False and data.get("validated_capabilities", {}).get("repo_flow_submit") is False and "pr-body-check" in data.get("forbidden_steps", [])'; then
      test_pass "slice-validator denies submit-only body capability without blocking validate-only flow"
    else
      test_fail "slice-validator denies submit-only body capability without blocking validate-only flow"
      status=1
    fi
  else
    test_fail "slice-validator denies submit-only body capability without blocking validate-only flow"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$missing_pr_body_file" --submit >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects missing PR body when submit is requested"
    status=1
  elif grep -Fq 'missing ## PR Body' "$stderr_file"; then
    test_pass "slice-validator rejects missing PR body when submit is requested"
  else
    test_fail "slice-validator rejects missing PR body when submit is requested"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$invalid_pr_body_file" >"$stdout_file" 2>"$stderr_file"
  ) && grep -Fxq 'pass' "$stdout_file" && grep -Fq 'manifest_path=' "$stdout_file"; then
    manifest_path="$(grep -F 'manifest_path=' "$stdout_file" | head -n1 | cut -d= -f2-)"
    if smoke_slice_validator_assert_json_file "$manifest_path" 'data.get("validated_capabilities", {}).get("repo_flow_submit") is False and data.get("validated_capabilities", {}).get("pr_body_check") is False'; then
      test_pass "slice-validator denies invalid PR body when submit is not requested"
    else
      test_fail "slice-validator denies invalid PR body when submit is not requested"
      status=1
    fi
  else
    test_fail "slice-validator denies invalid PR body when submit is not requested"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$invalid_pr_body_file" --submit >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator fails when requested submit needs invalid PR body"
    status=1
  elif grep -Fq 'PR body validation failed' "$stderr_file" || grep -Fq 'missing required heading' "$stderr_file"; then
    test_pass "slice-validator fails when requested submit needs invalid PR body"
  else
    test_fail "slice-validator fails when requested submit needs invalid PR body"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$conflict_review_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects review source conflict"
    status=1
  elif grep -Fq 'conflicting PR review sources' "$stderr_file"; then
    test_pass "slice-validator rejects review source conflict"
  else
    test_fail "slice-validator rejects review source conflict"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$invalid_prompt_id_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects invalid PR review prompt ID"
    status=1
  elif grep -Fq 'invalid pr_review_prompt_id:' "$stderr_file"; then
    test_pass "slice-validator rejects invalid PR review prompt ID"
  else
    test_fail "slice-validator rejects invalid PR review prompt ID"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$missing_preset_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects missing PR review preset"
    status=1
  elif grep -Fq 'missing PR review prompt preset:' "$stderr_file"; then
    test_pass "slice-validator rejects missing PR review preset"
  else
    test_fail "slice-validator rejects missing PR review preset"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$unsafe_prompt_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects unsafe placeholder prompt"
    status=1
  elif grep -Fq 'unsafe placeholder text in Codex Prompt:' "$stderr_file"; then
    test_pass "slice-validator rejects unsafe placeholder prompt"
  else
    test_fail "slice-validator rejects unsafe placeholder prompt"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/slice-validator --file="$lifecycle_prompt_file" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "slice-validator rejects lifecycle instructions"
    status=1
  elif grep -Fq 'Codex Prompt contains lifecycle instruction:' "$stderr_file"; then
    test_pass "slice-validator rejects lifecycle instructions"
  else
    test_fail "slice-validator rejects lifecycle instructions"
    status=1
  fi

  local -a self_target_cases=(
    "reject-target|$self_mod_prompt_file|fail|Codex Prompt targets the running helper: repo-automation/bin/slice-handoff|future copied-helper/self-target support is required"
    "allow-run|$self_target_run_file|pass||"
    "allow-invoke|$self_target_invoke_file|pass||"
    "allow-execute|$self_target_execute_file|pass||"
    "allow-negative|$self_target_negative_file|pass||"
  )
  local self_target_case=""
  local self_target_case_name=""
  local self_target_case_file=""
  local self_target_case_result=""
  local self_target_case_reason=""
  local self_target_case_fix=""
  for self_target_case in "${self_target_cases[@]}"; do
    IFS='|' read -r self_target_case_name self_target_case_file self_target_case_result self_target_case_reason self_target_case_fix <<EOF
$self_target_case
EOF
    if smoke_slice_validator_assert_prompt_case "$self_target_case_file" "$stdout_file" "$stderr_file" "$self_target_case_result" "$self_target_case_reason" "$self_target_case_fix"; then
      test_pass "slice-validator self-target case: $self_target_case_name"
    else
      test_fail "slice-validator self-target case: $self_target_case_name"
      status=1
    fi
  done

  if python3 - "$smoke_repo_root/repo-automation/helper-metadata.json" <<'PY'
import json
from pathlib import Path
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
helpers = [h for h in data.get('helpers', []) if isinstance(h, dict) and h.get('name') == 'slice-validator']
if len(helpers) != 1:
    raise SystemExit(1)
helper = helpers[0]
checks = {
    'name': 'slice-validator',
    'path': 'repo-automation/bin/slice-validator',
    'doc_path': 'repo-automation/docs/slice-validator.md',
    'contract_test_path': 'repo-automation/tests/contracts/slice-validator.sh',
    'public': True,
    'supports_json': True,
    'supports_quiet': True,
}
for key, expected in checks.items():
    if helper.get(key) != expected:
        raise SystemExit(1)
PY
  then
    test_pass "slice-validator metadata object is registered once"
  else
    test_fail "slice-validator metadata object is registered once"
    status=1
  fi

  rm -rf "$root" >/dev/null 2>&1 || true
  rm -f "$help_stdout" "$help_stderr" "$stdout_file" "$stderr_file" "$json_stdout" "$json_stderr" "$quiet_stdout" "$quiet_stderr" >/dev/null 2>&1 || true
  return "$status"
}

smoke_main_impl() {
  local status=0
  trap 'test_cleanup' EXIT INT TERM
  smoke_setup_temp_repo || return 1
  smoke_run_named_check "smoke:slice-validator-contract" smoke_check_slice_validator_contract || status=1
  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
