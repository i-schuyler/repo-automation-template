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
  cp -- "$smoke_repo_root/repo-automation/bin/slice-handoff" "$smoke_test_dir/repo-automation/bin/slice-handoff" || return 1
  cp -- "$smoke_repo_root/repo-automation/bin/slice-validator" "$smoke_test_dir/repo-automation/bin/slice-validator" || return 1
  cp -- "$smoke_repo_root/repo-automation/bin/codex-slice-preflight" "$smoke_test_dir/repo-automation/bin/codex-slice-preflight" || return 1
  chmod +x "$smoke_test_dir/repo-automation/bin/slice-handoff" || return 1
  chmod +x "$smoke_test_dir/repo-automation/bin/slice-validator" "$smoke_test_dir/repo-automation/bin/codex-slice-preflight" || return 1
  git -C "$smoke_test_dir" update-index --skip-worktree repo-automation/bin/slice-handoff repo-automation/bin/slice-validator repo-automation/bin/codex-slice-preflight || return 1

  smoke_slice_handoff_prepare_contract_context || return 1

  smoke_run_named_check "smoke:slice-handoff-contract:failure-excerpt-truncation" smoke_slice_handoff_assert_failure_excerpt_truncation || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:metadata-help" smoke_check_slice_handoff_contract_metadata_and_help || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:dry-run-artifacts" smoke_check_slice_handoff_contract_dry_run_artifacts || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:repair-routing" smoke_check_slice_handoff_contract_repair_routing || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:validation-review" smoke_check_slice_handoff_contract_validation_and_review_request || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:review-request-renderer" smoke_slice_handoff_assert_review_request_renderer || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:lifecycle-guards" smoke_check_slice_handoff_contract_lifecycle_and_self_modifying || status=1

  smoke_slice_handoff_prepare_execution_context || return 1

  smoke_run_named_check "smoke:slice-handoff-contract:repair-execution" smoke_check_slice_handoff_contract_repair_execution || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:execution-copied-helper-self-target" smoke_check_slice_handoff_contract_execution_copied_helper_self_target || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:model-reasoning-passthrough" smoke_check_slice_handoff_contract_model_reasoning_passthrough || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:execution-none" smoke_check_slice_handoff_contract_execution_none_behavior || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:execution-submit-success" smoke_check_slice_handoff_contract_execution_submit_success_behavior || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:execution-submit-false-positive" smoke_check_slice_handoff_contract_execution_submit_false_positive_blocker_behavior || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:execution-submit-true-blocker" smoke_check_slice_handoff_contract_execution_submit_true_codex_blocker_behavior || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:execution-failures" smoke_check_slice_handoff_contract_execution_failure_cases || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:repo-root-artifacts" smoke_check_slice_handoff_contract_no_repo_root_artifacts || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:codex-final-blocker-detector" smoke_check_slice_handoff_contract_codex_final_output_blocker_detector || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:validator-json-reason" smoke_check_slice_handoff_contract_validator_json_reason_failure || status=1
  smoke_run_named_check "smoke:slice-handoff-contract:validation-manifest-trace" smoke_check_slice_handoff_contract_execution_validation_manifest_trace || status=1

  return "$status"
}

smoke_check_slice_handoff_contract_repair_execution() {
  local repair_file="$smoke_test_base/slice-handoff-repair-execution.md"
  local stdout_file="$smoke_test_base/slice-handoff-repair-execution.out"
  local stderr_file="$smoke_test_base/slice-handoff-repair-execution.err"
  local codex_args="$smoke_test_base/slice-handoff-repair-codex.args"
  local repo_flow_args="$smoke_test_base/slice-handoff-repair-repo-flow.args"
  local fake_bin="$smoke_test_base/slice-handoff-repair-gh"
  local branch="feature/slice-handoff-repair"

  cp -- "$smoke_slice_handoff_execution_valid_submit_file" "$repair_file" || return 1
  python3 - "$repair_file" "$branch" <<'PY' || return 1
from pathlib import Path
import sys
path = Path(sys.argv[1])
branch = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = text.replace("branch: feature/slice-handoff-submit\n", f"branch: {branch}\nhandoff_mode: repair\nrepair_of_pr: 242\nrepair_session: resume\ncodex_session_id: session-242\n", 1)
path.write_text(text, encoding="utf-8")
PY
  git -C "$smoke_test_dir" branch -D "$branch" >/dev/null 2>&1 || true
  git -C "$smoke_test_dir" branch "$branch" main || return 1
  git -C "$smoke_test_dir" checkout main >/dev/null 2>&1 || return 1
  mkdir -p "$fake_bin" || return 1
  cat >"$fake_bin/gh" <<EOF
#!/usr/bin/env bash
printf '{"number":242,"state":"OPEN","headRefName":"$branch"}\n'
EOF
  chmod +x "$fake_bin/gh" || return 1

  if PATH="$fake_bin:$PATH" FAKE_CODEX_RUN_ARGS_FILE="$codex_args" FAKE_REPO_FLOW_ARGS_FILE="$repo_flow_args" \
    smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" \
      smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$repair_file" --repair --submit --explain &&
    grep -Fxq -- '--resume-session-id=session-242' "$codex_args" &&
    grep -Fxq -- '--replace-body' "$repo_flow_args" &&
    grep -Fxq 'mode=repair-submit' "$stderr_file" &&
    grep -Fxq 'repair_of_pr=242' "$stderr_file" &&
    grep -Fxq 'codex_session_id=session-242' "$stderr_file" &&
    grep -Fxq 'pushed=false' "$stderr_file" &&
    python3 - "$stderr_file" <<'PY' &&
from pathlib import Path
import sys
lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
summary = lines.index("===== FINAL SUMMARY =====")
context = lines.index("===== CODEX RUN CONTEXT =====")
review = lines.index("===== PR REVIEW REQUEST =====")
review_end = lines.index("===== END PR REVIEW REQUEST =====")
if not summary < context < review < review_end or review_end != len(lines) - 1:
    raise SystemExit(1)
PY
    [ "$(git -C "$smoke_test_dir" branch --show-current)" = "$branch" ]; then
    test_pass "slice-handoff repair execution resumes Codex and replaces the existing PR body"
  else
    test_fail "slice-handoff repair execution resumes Codex and replaces the existing PR body"
    return 1
  fi
}

smoke_check_slice_handoff_contract_execution_copied_helper_self_target() {
  local status=0
  local self_target_out_dir="$smoke_slice_handoff_execution_artifact_root/out-execution-self-target"
  local stdout_file="$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-self-target.out"
  local stderr_file="$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-self-target.err"
  local worktree_helper_before="$smoke_slice_handoff_execution_artifact_root/slice-handoff-worktree-before.txt"
  local codex_run_before="$smoke_slice_handoff_execution_artifact_root/codex-run-before.txt"
  local fake_codex_edit_text="$smoke_slice_handoff_execution_artifact_root/fake-codex-edit-helper.txt"
  local self_target_expected_review_request
  local run_dir=""
  local snapshot_helper_path=""

  smoke_slice_handoff_install_fake_codex_run || return 1
  if [ -e "$smoke_test_dir/repo-automation/bin/codex-run" ]; then
    cp -- "$smoke_test_dir/repo-automation/bin/codex-run" "$codex_run_before" || return 1
  else
    : > "$codex_run_before" || return 1
  fi
  printf '# fake codex-run edited worktree helper\n' > "$fake_codex_edit_text" || return 1
  cp -- "$smoke_test_dir/repo-automation/bin/slice-handoff" "$worktree_helper_before" || return 1
  rm -rf -- "$self_target_out_dir" || return 1
  self_target_expected_review_request="$(cat <<'EOF'
Please review this PR before merge:

<PR_URL>

Slice handoff copied-helper smoke
Branch: feature/slice-handoff-self-target

Review the changed files and any related docs, tests, metadata, command contracts, output contracts, and examples for drift.

Return CLEAN, NEEDS REPAIR, BLOCKING, or UNCERTAIN. If repair is needed, describe one same-branch repair direction.
EOF
)"

  if (
    FAKE_CODEX_RUN_HELPER=1 \
    FAKE_CODEX_RUN_EDIT_TARGET_FILE="$fake_codex_edit_text" \
    FAKE_CODEX_RUN_EDIT_TARGET_PATH="repo-automation/bin/slice-handoff" \
    FAKE_CODEX_RUN_STDOUT_TEXT='pass' \
    FAKE_CODEX_RUN_FINAL_TEXT='Implementation complete.' \
    smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" \
      smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$smoke_slice_handoff_self_target_file" --explain --out-dir="$self_target_out_dir"
  ); then
    run_dir="$(smoke_slice_handoff_extract_field "$stderr_file" run_dir)" || return 1
    snapshot_helper_path="$run_dir/helper-snapshot/repo-automation/bin/slice-handoff"
    if smoke_slice_handoff_assert_execution_run_dir "$run_dir" "none" "feature/slice-handoff-self-target" "Slice handoff copied-helper smoke" "Update repo-automation/bin/slice-handoff to implement the copied-helper snapshot lane." "$self_target_expected_review_request" "" "$smoke_test_dir" && \
      grep -Fxq 'self_target=copied-helper' "$run_dir/slice-handoff-execution-summary.txt" && \
      grep -Fxq "helper_snapshot_path=$snapshot_helper_path" "$run_dir/slice-handoff-execution-summary.txt" && \
      grep -Eq '^helper_snapshot_hash=sha256:[0-9a-f]{64}$' "$run_dir/slice-handoff-execution-summary.txt" && \
      grep -Fxq 'self_target=copied-helper' "$stderr_file" && \
      grep -Fxq "helper_snapshot_path=$snapshot_helper_path" "$stderr_file" && \
      grep -Eq '^helper_snapshot_hash=sha256:[0-9a-f]{64}$' "$stderr_file" && \
      grep -Fxq 'snapshot_mode=copied-helper' "$run_dir/helper-snapshot.txt" && \
      grep -Fxq "snapshot_helper_path=$snapshot_helper_path" "$run_dir/helper-snapshot.txt" && \
      grep -Fxq "snapshot_root=$run_dir/helper-snapshot" "$run_dir/helper-snapshot.txt" && \
      grep -Fxq "snapshot_source_repo_root=$smoke_test_dir" "$run_dir/helper-snapshot.txt" && \
      [ -x "$snapshot_helper_path" ] && \
      cmp -s "$worktree_helper_before" "$snapshot_helper_path" && \
      ! cmp -s "$worktree_helper_before" "$smoke_test_dir/repo-automation/bin/slice-handoff" && \
      grep -Fxq '# fake codex-run edited worktree helper' "$smoke_test_dir/repo-automation/bin/slice-handoff"; then
      if [ -s "$codex_run_before" ]; then
        cp -- "$codex_run_before" "$smoke_test_dir/repo-automation/bin/codex-run" || return 1
        chmod +x "$smoke_test_dir/repo-automation/bin/codex-run" || return 1
      else
        rm -f -- "$smoke_test_dir/repo-automation/bin/codex-run" || return 1
      fi
      cp -- "$worktree_helper_before" "$smoke_test_dir/repo-automation/bin/slice-handoff" || return 1
      chmod +x "$smoke_test_dir/repo-automation/bin/slice-handoff" || return 1
      test_pass "slice-handoff copied-helper self-target execution keeps the snapshot boundary stable"
    else
      if [ -s "$codex_run_before" ]; then
        cp -- "$codex_run_before" "$smoke_test_dir/repo-automation/bin/codex-run" || return 1
        chmod +x "$smoke_test_dir/repo-automation/bin/codex-run" || return 1
      else
        rm -f -- "$smoke_test_dir/repo-automation/bin/codex-run" || return 1
      fi
      cp -- "$worktree_helper_before" "$smoke_test_dir/repo-automation/bin/slice-handoff" || return 1
      chmod +x "$smoke_test_dir/repo-automation/bin/slice-handoff" || return 1
      test_fail "slice-handoff copied-helper self-target execution keeps the snapshot boundary stable"
      status=1
    fi
  else
    test_fail "slice-handoff copied-helper self-target execution keeps the snapshot boundary stable"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_model_reasoning_passthrough() {
  local status=0
  local model_reasoning_file="$smoke_test_base/slice-handoff-model-reasoning.md"
  local dry_run_out_dir="$smoke_test_base/out-model-reasoning-dry-run"
  local execution_out_dir="$smoke_test_base/slice-handoff-tmp/model-reasoning-execution"
  local stdout_file="$smoke_test_base/slice-handoff-model-reasoning.out"
  local stderr_file="$smoke_test_base/slice-handoff-model-reasoning.err"
  local codex_args_file="$smoke_test_base/slice-handoff-model-reasoning-codex.args"
  local codex_run_before="$smoke_test_base/slice-handoff-model-reasoning-codex-run.before"

  cp -- "$smoke_slice_handoff_valid_none_file" "$model_reasoning_file" || return 1
  python3 - "$model_reasoning_file" <<'PY' || return 1
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = text.replace("codex_profile: default\n", "codex_profile: default\ncodex_model: gpt-5.4-mini\ncodex_reasoning: high\n", 1)
path.write_text(text, encoding='utf-8')
PY
  rm -rf -- "$dry_run_out_dir" "$execution_out_dir" || return 1
  if [ -e "$smoke_test_dir/repo-automation/bin/codex-run" ]; then
    cp -- "$smoke_test_dir/repo-automation/bin/codex-run" "$codex_run_before" || return 1
  else
    : > "$codex_run_before" || return 1
  fi

  if smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$model_reasoning_file" --dry-run --out-dir="$dry_run_out_dir" &&
    grep -Fxq 'codex_model=gpt-5.4-mini' "$dry_run_out_dir/dry-run-preview.txt" &&
    grep -Fxq 'codex_reasoning=high' "$dry_run_out_dir/dry-run-preview.txt" &&
    grep -Fxq -- '- --model=gpt-5.4-mini' "$dry_run_out_dir/dry-run-preview.txt" &&
    grep -Fxq -- '- --reasoning=high' "$dry_run_out_dir/dry-run-preview.txt" &&
    grep -Fxq 'codex_model=gpt-5.4-mini' "$dry_run_out_dir/slice-handoff-summary.txt" &&
    grep -Fxq 'codex_reasoning=high' "$dry_run_out_dir/slice-handoff-summary.txt"; then
    :
  else
    test_fail "slice-handoff model/reasoning dry-run passthrough"
    status=1
  fi

  if (
    FAKE_CODEX_RUN_HELPER=1 \
    FAKE_CODEX_RUN_ARGS_FILE="$codex_args_file" \
    FAKE_CODEX_RUN_STDOUT_TEXT='pass' \
    FAKE_CODEX_RUN_FINAL_TEXT='Implementation complete.' \
    smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" \
      smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$model_reasoning_file" --out-dir="$execution_out_dir" --explain &&
      grep -Fxq 'codex_model=gpt-5.4-mini' "$execution_out_dir/slice-handoff-summary.txt" &&
      grep -Fxq 'codex_reasoning=high' "$execution_out_dir/slice-handoff-summary.txt" &&
      run_dir="$(smoke_slice_handoff_extract_field "$stderr_file" run_dir)" &&
      grep -Fxq 'codex_model=gpt-5.4-mini' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'codex_reasoning=high' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'codex_model=gpt-5.4-mini' "$stderr_file" &&
      grep -Fxq 'codex_reasoning=high' "$stderr_file" &&
      grep -Fxq -- '--model=gpt-5.4-mini' "$codex_args_file" &&
      grep -Fxq -- '--reasoning=high' "$codex_args_file"
  ); then
    :
  else
    test_fail "slice-handoff model/reasoning execution passthrough"
    status=1
  fi

  if [ -s "$codex_run_before" ]; then
    cp -- "$codex_run_before" "$smoke_test_dir/repo-automation/bin/codex-run" || return 1
    chmod +x "$smoke_test_dir/repo-automation/bin/codex-run" || return 1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_repair_routing() {
  local repair_file="$smoke_test_base/slice-handoff-repair.md"
  local repair_out="$smoke_test_base/slice-handoff-repair-out"
  local stdout_file="$smoke_test_base/slice-handoff-repair.out"
  local stderr_file="$smoke_test_base/slice-handoff-repair.err"

  cp -- "$smoke_slice_handoff_valid_submit_file" "$repair_file" || return 1
  python3 - "$repair_file" <<'PY' || return 1
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "branch: feature/slice-handoff-submit\n"
metadata = marker + "handoff_mode: repair\nrepair_of_pr: 242\nrepair_session: resume\ncodex_session_id: session-242\n"
path.write_text(text.replace(marker, metadata, 1), encoding="utf-8")
PY
  rm -rf -- "$repair_out" || return 1

  if smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$repair_file" --repair --submit --dry-run --out-dir="$repair_out" --explain &&
    grep -Fxq -- '- --repair-of-pr=242' "$repair_out/dry-run-preview.txt" &&
    grep -Fxq -- '- --resume-session-id=session-242' "$repair_out/dry-run-preview.txt" &&
    grep -Fxq -- '- --replace-body' "$repair_out/dry-run-preview.txt" &&
    grep -Fxq 'mode=repair-dry-run' "$stderr_file" &&
    grep -Fxq 'repair_of_pr=242' "$stderr_file" &&
    grep -Fxq 'codex_session_id=session-242' "$stderr_file" &&
    grep -Fq '===== PR REVIEW REQUEST =====' "$stderr_file"; then
    test_pass "slice-handoff repair route resumes Codex and replaces the existing PR body"
  else
    test_fail "slice-handoff repair route resumes Codex and replaces the existing PR body"
    return 1
  fi
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_check_slice_handoff_contract_metadata_and_help() {
  local status=0

  if smoke_slice_handoff_assert_metadata; then
    test_pass "slice-handoff metadata matches helper object"
  else
    test_fail "slice-handoff metadata matches helper object"
    status=1
  fi

  if smoke_slice_handoff_assert_planned_route; then
    test_pass "slice-handoff dry-run planned route matches helper metadata"
  else
    test_fail "slice-handoff dry-run planned route matches helper metadata"
    status=1
  fi

  if (
      smoke_slice_handoff_run "$smoke_test_base/slice-handoff-help.out" "$smoke_test_base/slice-handoff-help.err" --help &&
      grep -Fxq 'Usage: repo-automation/bin/slice-handoff --file=<path> [--repair] [--dry-run] [--submit] [--out-dir=<path>] [--quiet] [--explain] [--help]' "$smoke_test_base/slice-handoff-help.out" &&
      grep -Fq -- '--repair' "$smoke_test_base/slice-handoff-help.out" &&
      grep -Fq -- '--explain' "$smoke_test_base/slice-handoff-help.out" &&
      smoke_slice_handoff_assert_stderr_effectively_empty "$smoke_test_base/slice-handoff-help.err"
  ); then
    test_pass "slice-handoff help includes --explain"
  else
    test_fail "slice-handoff help includes --explain"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_dry_run_artifacts() {
  local status=0
  local self_target_out_dir="$smoke_test_base/out-self-target"

  if smoke_slice_handoff_expect_success "valid-none" "pass" "" --file="$smoke_slice_handoff_valid_none_file" --dry-run; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_success "quiet-success" "" "" --file="$smoke_slice_handoff_valid_none_file" --dry-run --quiet; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_success "valid-submit" "pass" "" --file="$smoke_slice_handoff_valid_submit_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    rm -rf -- "$self_target_out_dir" &&
      smoke_slice_handoff_expect_success "self-target-copied-helper" "$(smoke_slice_handoff_expected_dry_run_stdout "$self_target_out_dir")" "" --file="$smoke_slice_handoff_self_target_file" --dry-run --out-dir="$self_target_out_dir" &&
      grep -Fxq 'self_target=copied-helper' "$self_target_out_dir/dry-run-preview.txt" &&
      grep -Fxq 'planned_helper_snapshot_root=<active-run-dir>/helper-snapshot' "$self_target_out_dir/dry-run-preview.txt" &&
      grep -Fxq 'planned_helper_snapshot_path=<active-run-dir>/helper-snapshot/repo-automation/bin/slice-handoff' "$self_target_out_dir/dry-run-preview.txt" &&
      grep -Fxq 'planned_helper_snapshot_hash=not_created_by_dry_run' "$self_target_out_dir/dry-run-preview.txt" &&
      [ ! -e "$self_target_out_dir/helper-snapshot.txt" ]
  ); then
    :
  else
    test_fail "out-dir self-target artifacts: expected planned copied-helper preview without runtime snapshot under $self_target_out_dir"
    status=1
  fi

  if (
    rm -rf -- "$smoke_slice_handoff_valid_none_out_dir" &&
      smoke_slice_handoff_expect_success "out-dir-none" "$smoke_slice_handoff_expected_none_stdout" "" --file="$smoke_slice_handoff_valid_none_file" --dry-run --out-dir="$smoke_slice_handoff_valid_none_out_dir" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_none_out_dir/codex-prompt.md" "$smoke_slice_handoff_expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_none_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_none_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_none_out_dir/review-request.txt" "$smoke_slice_handoff_expected_default_review_request" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_none_out_dir/slice-handoff-summary.txt" "$smoke_slice_handoff_expected_none_summary"
  ); then
    :
  else
    test_fail "out-dir-none artifacts: expected dry-run files under $smoke_slice_handoff_valid_none_out_dir"
    status=1
  fi

  if (
    rm -rf -- "$smoke_slice_handoff_valid_submit_out_dir" &&
      smoke_slice_handoff_expect_success "out-dir-submit" "$smoke_slice_handoff_expected_submit_stdout_value" "" --file="$smoke_slice_handoff_valid_submit_file" --dry-run --out-dir="$smoke_slice_handoff_valid_submit_out_dir" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/codex-prompt.md" "$smoke_slice_handoff_expected_submit_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_submit_noauth_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/review-request.txt" "$smoke_slice_handoff_expected_submit_default_review_request" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/slice-handoff-summary.txt" "$smoke_slice_handoff_expected_submit_noauth_summary" &&
      [ ! -e "$smoke_slice_handoff_valid_submit_out_dir/pr-body.md" ]
  ); then
    :
  else
    test_fail "out-dir-submit artifacts: expected submit files under $smoke_slice_handoff_valid_submit_out_dir"
    status=1
  fi

  if (
    rm -rf -- "$smoke_slice_handoff_valid_preset_out_dir" &&
      smoke_slice_handoff_expect_success "out-dir-preset" "$smoke_slice_handoff_expected_preset_stdout" "" --file="$smoke_slice_handoff_valid_preset_file" --dry-run --out-dir="$smoke_slice_handoff_valid_preset_out_dir" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_preset_out_dir/codex-prompt.md" "$smoke_slice_handoff_expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_preset_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_preset_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_preset_out_dir/review-request.txt" "$smoke_slice_handoff_expected_preset_review_request" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_preset_out_dir/slice-handoff-summary.txt" "$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-pr-review\ntitle=Slice handoff preset review smoke\ncodex_profile=default\nsubmit_mode=none\ncommit_message=\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=\nreview_request_path=%s/review-request.txt\nvalidation_manifest_path=%s/validation-manifest.json' "$smoke_slice_handoff_valid_preset_out_dir" "$smoke_slice_handoff_valid_preset_out_dir" "$smoke_slice_handoff_valid_preset_out_dir")"
  ); then
    :
  else
    test_fail "out-dir-preset artifacts: expected preset review-request artifacts under $smoke_slice_handoff_valid_preset_out_dir"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_validation_and_review_request() {
  local status=0
  local invalid_out_dir="$smoke_slice_handoff_invalid_out_dir"

  if (
    rm -rf -- "$invalid_out_dir" &&
      smoke_slice_handoff_expect_success "out-dir-submit-invalid-pr-body" "$(cat <<EOF
pass
out_dir=$invalid_out_dir
codex_prompt_path=$invalid_out_dir/codex-prompt.md
preview_path=$invalid_out_dir/dry-run-preview.txt
review_request_path=$invalid_out_dir/review-request.txt
summary_path=$invalid_out_dir/slice-handoff-summary.txt
validation_manifest_path=$invalid_out_dir/validation-manifest.json
EOF
)" "" --file="$smoke_slice_handoff_invalid_submit_file" --dry-run --out-dir="$invalid_out_dir" &&
      smoke_slice_handoff_assert_text_file "$invalid_out_dir/codex-prompt.md" "$smoke_slice_handoff_expected_submit_prompt" &&
      [ -s "$invalid_out_dir/dry-run-preview.txt" ] &&
      smoke_slice_handoff_assert_text_file "$invalid_out_dir/review-request.txt" "$smoke_slice_handoff_expected_submit_default_review_request" &&
      smoke_slice_handoff_assert_text_file "$invalid_out_dir/slice-handoff-summary.txt" "$(cat <<EOF
schema=repo-automation-slice-handoff/v1
branch=feature/slice-handoff-submit
title=Slice handoff submit smoke
codex_profile=review
submit_mode=repo-flow-submit-all
commit_message=chore: slice-handoff smoke
codex_prompt_path=$invalid_out_dir/codex-prompt.md
pr_body_path=
review_request_path=$invalid_out_dir/review-request.txt
validation_manifest_path=$invalid_out_dir/validation-manifest.json
EOF
)" &&
      [ ! -e "$invalid_out_dir/pr-body.md" ]
  ); then
    :
  else
    test_fail "out-dir-submit-invalid-pr-body artifacts: expected validation-manifest and no pr-body output under $invalid_out_dir"
    status=1
  fi

  if smoke_slice_handoff_expect_validator_failure "pr-review-conflict" "conflicting PR review sources: explicit ## PR Review Request and pr_review_prompt_id" "paste this blocker into ChatGPT" --file="$smoke_slice_handoff_invalid_prompt_conflict_file" --dry-run; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_validator_failure "pr-review-invalid-id" "invalid pr_review_prompt_id: -bad" "paste this blocker into ChatGPT" --file="$smoke_slice_handoff_invalid_prompt_id_file" --dry-run; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_validator_failure "pr-review-missing-preset" "missing PR review prompt preset: $smoke_test_dir/.prompts/missing-preset.md" "paste this blocker into ChatGPT" --file="$smoke_slice_handoff_missing_prompt_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    rm -rf -- "$smoke_slice_handoff_valid_submit_out_dir" &&
      smoke_slice_handoff_write_file "$smoke_slice_handoff_valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_submit_body" "$smoke_slice_handoff_explicit_review_request_text" &&
      smoke_slice_handoff_expect_success "out-dir-submit-review-request" "$(printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt\nvalidation_manifest_path=%s/validation-manifest.json' "$smoke_slice_handoff_valid_submit_out_dir" "$smoke_slice_handoff_valid_submit_out_dir" "$smoke_slice_handoff_valid_submit_out_dir" "$smoke_slice_handoff_valid_submit_out_dir" "$smoke_slice_handoff_valid_submit_out_dir" "$smoke_slice_handoff_valid_submit_out_dir" "$smoke_slice_handoff_valid_submit_out_dir")" "" --file="$smoke_slice_handoff_valid_submit_file" --dry-run --submit --out-dir="$smoke_slice_handoff_valid_submit_out_dir" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/codex-prompt.md" "$smoke_slice_handoff_expected_submit_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_submit_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/pr-body.md" "$smoke_slice_handoff_submit_body" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/review-request.txt" "$smoke_slice_handoff_explicit_review_request_text" &&
      ! grep -Fq -- "$smoke_slice_handoff_explicit_review_request_text" "$smoke_slice_handoff_valid_submit_out_dir/codex-prompt.md" &&
      ! grep -Fq -- "$smoke_slice_handoff_explicit_review_request_text" "$smoke_slice_handoff_valid_submit_out_dir/pr-body.md" &&
      ! grep -Fq -- 'PR Review Request' "$smoke_slice_handoff_valid_submit_out_dir/codex-prompt.md" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_submit_out_dir/slice-handoff-summary.txt" "$smoke_slice_handoff_expected_submit_summary"
  ); then
    :
  else
    test_fail "out-dir-submit-review-request artifacts"
    status=1
  fi

  if (
    rm -rf -- "$smoke_slice_handoff_valid_quiet_out_dir" &&
      smoke_slice_handoff_write_file "$smoke_slice_handoff_valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$smoke_slice_handoff_valid_prompt" "" "$smoke_slice_handoff_explicit_review_request_text" &&
      smoke_slice_handoff_run "$smoke_test_base/slice-handoff-quiet-out-review.out" "$smoke_test_base/slice-handoff-quiet-out-review.err" --file="$smoke_slice_handoff_valid_none_file" --dry-run --quiet --out-dir="$smoke_slice_handoff_valid_quiet_out_dir" &&
      [ ! -s "$smoke_test_base/slice-handoff-quiet-out-review.out" ] &&
      smoke_slice_handoff_assert_stderr_effectively_empty "$smoke_test_base/slice-handoff-quiet-out-review.err" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_quiet_out_dir/codex-prompt.md" "$smoke_slice_handoff_expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_quiet_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_quiet_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_quiet_out_dir/review-request.txt" "$smoke_slice_handoff_explicit_review_request_text" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_valid_quiet_out_dir/slice-handoff-summary.txt" "$smoke_slice_handoff_expected_quiet_summary" &&
      smoke_slice_handoff_expect_success "out-dir-none-review-request-stdout" "$smoke_slice_handoff_expected_none_review_stdout" "" --file="$smoke_slice_handoff_valid_none_file" --dry-run --out-dir="$smoke_slice_handoff_valid_quiet_out_dir"
  ); then
    :
  else
    test_fail "out-dir-none-review-request artifacts"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_lifecycle_and_self_modifying() {
  local status=0

  if smoke_slice_handoff_expect_validator_failure "lifecycle" "Codex Prompt contains lifecycle instruction: create a pr" "paste this blocker into ChatGPT" --file="$smoke_slice_handoff_lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_validator_failure "self-modifying-helper" "Codex Prompt targets the running helper: repo-automation/bin/slice-handoff" "paste this blocker into ChatGPT" --file="$smoke_slice_handoff_self_modifying_helper_file" --dry-run; then
    :
  else
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_execution_none_behavior() {
  local status=0
  local run_dir=""

  if (
    rm -rf -- "$smoke_slice_handoff_execution_none_out_dir" &&
      smoke_slice_handoff_assert_clean_worktree &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_none_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-none.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-none.err" --file="$smoke_slice_handoff_valid_none_file" --out-dir="$smoke_slice_handoff_execution_none_out_dir" &&
      run_dir="$(smoke_slice_handoff_assert_execution_stdout "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-none.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-none.err" "feature/slice-handoff-smoke")" &&
      grep -Fxq "codex_final_output_path=$run_dir/codex-run/codex-final.txt" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-none.out" &&
      smoke_slice_handoff_assert_execution_run_dir "$run_dir" "none" "feature/slice-handoff-smoke" "Slice handoff smoke" "$smoke_slice_handoff_expected_none_prompt" "$smoke_slice_handoff_expected_execution_review_request_head" "" "$smoke_test_dir" &&
      smoke_slice_handoff_assert_execution_preflight_isolated "$run_dir" "$smoke_slice_handoff_execution_fixture_sentinel" "$smoke_slice_handoff_execution_smoke_test_dir" "$smoke_test_base" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_none_out_dir/codex-prompt.md" "$smoke_slice_handoff_expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_none_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_execution_none_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_none_out_dir/review-request.txt" "$smoke_slice_handoff_expected_execution_review_request_head" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_none_out_dir/slice-handoff-summary.txt" "$smoke_slice_handoff_expected_execution_none_summary"
  ); then
    :
  else
    test_fail "execution-none artifacts"
    status=1
  fi

  if (
    rm -rf -- "$smoke_slice_handoff_execution_quiet_out_dir" &&
      smoke_slice_handoff_assert_clean_worktree &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_none_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-quiet.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-quiet.err" --file="$smoke_slice_handoff_valid_none_file" --out-dir="$smoke_slice_handoff_execution_quiet_out_dir" --quiet &&
      [ ! -s "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-quiet.out" ] &&
      smoke_slice_handoff_assert_stderr_effectively_empty "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-quiet.err" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_quiet_out_dir/codex-prompt.md" "$smoke_slice_handoff_expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_quiet_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_execution_quiet_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_quiet_out_dir/review-request.txt" "$smoke_slice_handoff_expected_execution_review_request_head" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_quiet_out_dir/slice-handoff-summary.txt" "$smoke_slice_handoff_expected_execution_quiet_summary"
  ); then
    :
  else
    test_fail "execution-quiet artifacts"
    status=1
  fi

  if (smoke_slice_handoff_run_dirty_preflight_regression); then
    :
  else
    test_fail "execution-dirty-preflight artifacts"
    status=1
  fi

  find "$TEST_TEMP_ROOT" -maxdepth 1 -mindepth 1 -type d \( \
      -name 'repo-automation-slice-handoff-remote.*' -o \
      -name 'repo-automation-slice-handoff-exec.*' -o \
      -name 'repo-automation-slice-handoff-exec-dirty.*' \
    \) -printf '%f\n' | sort > "$smoke_slice_handoff_top_level_fixture_after_file" || return 1
  if comm -13 "$smoke_slice_handoff_top_level_fixture_baseline_file" "$smoke_slice_handoff_top_level_fixture_after_file" | grep -q .; then
    test_fail "top-level slice-handoff fixture dirs under temp root"
    status=1
  fi

  if smoke_slice_handoff_expect_failure "missing-file" "missing required --file" "use --file=<path> with a readable handoff file" --dry-run; then
    :
  else
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_execution_submit_success_behavior() {
  local status=0
  local run_dir=""
  local review_request_path=""
  local review_request_block_path=""
  local expected_submit_review_request_rendered=""
  local expected_codex_run_context=""
  local stderr_file="$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-success.err"

  smoke_slice_handoff_prepare_execution_submit_context "success" || return 1
  if (
    rm -rf -- "$smoke_slice_handoff_execution_submit_out_dir" &&
      smoke_slice_handoff_assert_execution_submit_artifact_bundle "success" "$smoke_slice_handoff_execution_submit_bundle_root" "$smoke_slice_handoff_execution_fake_codex_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" &&
      smoke_slice_handoff_write_file "$smoke_slice_handoff_execution_valid_preset_file" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_submit_body" "" "repo-automation-template-pr-review" &&
      smoke_slice_handoff_assert_clean_worktree &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_RUN_FINAL_TEXT='Implementation complete.' FAKE_PR_BODY_CHECK_ARGS_FILE="$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" FAKE_REPO_FLOW_COMMIT_SHA="$smoke_slice_handoff_expected_submit_commit_sha" FAKE_REPO_FLOW_CI_STATE="$smoke_slice_handoff_expected_submit_ci_state" FAKE_REPO_FLOW_STDOUT_TEXT='fake repo-flow stdout' FAKE_REPO_FLOW_STDERR_TEXT='fake repo-flow stderr' FAKE_REPO_FLOW_URL_OR_STOP="$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" FAKE_REPO_FLOW_WATCHED="$smoke_slice_handoff_expected_submit_watched" smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-success.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-success.err" --file="$smoke_slice_handoff_execution_valid_preset_file" --submit --explain --out-dir="$smoke_slice_handoff_execution_submit_out_dir" &&
      [ ! -s "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-success.out" ] &&
      run_dir="$(smoke_slice_handoff_extract_field "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-success.err" run_dir)" &&
      expected_codex_run_context="$(smoke_slice_handoff_expected_codex_run_context "$run_dir" "implementation-complete")" &&
      expected_submit_review_request_rendered="$(cat <<EOF
Please review this PR before merge:

$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop

Slice: Slice handoff preset review smoke
Branch: feature/slice-handoff-pr-review
Run dir: $run_dir

Use the canonical private project review sources:
1. \`prompts/PR_REVIEW_PROMPT.md\`
2. \`projects/repo-automation-template/PROMPTS.md\` → \`PR Review Wrapper\`
3. \`projects/repo-automation-template/CURRENT_STATE.md\` for current guardrails, deferred hardening, and recent PR context.

Review the changed files and related docs, tests, metadata, helper contracts, output contracts, examples, and workflow routing for drift.

Return the full project review shape, including:
- Verdict
- Audit Coverage
- Findings
- Contract Drift Matrix
- Search Terms Used
- Tests / Enforcement Needing Updates
- Questions I Should Be Asking
- Selected Repair Architecture
- Consolidated Repair Prompt

Merge remains explicit and outside slice-handoff.
EOF
)" &&
      grep -Fxq "codex_final_output_path=$run_dir/codex-run/codex-final.txt" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-success.out" &&
      smoke_slice_handoff_assert_text_file "$run_dir/codex-run-context.txt" "$expected_codex_run_context" &&
      python3 - "$run_dir/codex-status-recent.json" <<'PY'
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
session = data['sessions'][0]
assert session['session_id'] == 'sess-123'
assert session['resume']['command'] == 'codex resume --include-non-interactive sess-123'
assert session['model']['name'] == 'gpt-5.4-mini'
assert session['model']['reasoning'] == 'medium'
assert session['context']['remaining_summary'] == '85% left'
assert data['rate_limits']['five_hour']['remaining_percent'] == 99.0
assert data['rate_limits']['five_hour']['resets_at_local'] == '2026-05-24 04:31 PDT'
assert data['rate_limits']['weekly']['remaining_percent'] == 93.0
assert data['rate_limits']['weekly']['resets_at_local'] == '2026-05-31 04:31 PDT'
PY
      final_summary_line="$(grep -nF '===== FINAL SUMMARY =====' "$stderr_file" | tail -n1 | cut -d: -f1)" &&
      codex_context_line="$(grep -nF '===== CODEX RUN CONTEXT =====' "$stderr_file" | tail -n1 | cut -d: -f1)" &&
      review_request_line="$(grep -nF '===== PR REVIEW REQUEST =====' "$stderr_file" | tail -n1 | cut -d: -f1)" &&
      review_request_end_line="$(grep -nF '===== END PR REVIEW REQUEST =====' "$stderr_file" | tail -n1 | cut -d: -f1)" &&
      total_stderr_lines="$(wc -l < "$stderr_file" | tr -d '[:space:]')" &&
      [ -n "$final_summary_line" ] &&
      [ -n "$codex_context_line" ] &&
      [ -n "$review_request_line" ] &&
      [ -n "$review_request_end_line" ] &&
      [ "$final_summary_line" -lt "$codex_context_line" ] &&
      [ "$codex_context_line" -lt "$review_request_line" ] &&
      [ "$review_request_line" -lt "$review_request_end_line" ] &&
      [ "$review_request_end_line" -eq "$total_stderr_lines" ] &&
      grep -Fxq 'INFO: slice-handoff repo-flow submit' "$stderr_file" &&
      pr_body_validation_info_prefix='INFO: slice-handoff ' &&
      pr_body_validation_info_suffix='PR-body validation' &&
      ! grep -Fq "${pr_body_validation_info_prefix}${pr_body_validation_info_suffix}" "$stderr_file" &&
      smoke_slice_handoff_assert_execution_submit_explain_review_request "$stderr_file" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" "feature/slice-handoff-pr-review" "$run_dir" "$smoke_slice_handoff_expected_submit_commit_sha" "$smoke_slice_handoff_expected_submit_ci_state" "true" &&
      smoke_slice_handoff_assert_execution_run_dir "$run_dir" "repo-flow-submit-all" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "$smoke_slice_handoff_submit_prompt" "$expected_submit_review_request_rendered" "$smoke_slice_handoff_submit_body" "$smoke_test_dir" "execution-submit" "review PR before merge" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" &&
      smoke_slice_handoff_assert_execution_preflight_isolated "$run_dir" "$smoke_slice_handoff_execution_fixture_sentinel" "$smoke_slice_handoff_execution_smoke_test_dir" "$smoke_test_base" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$(cat <<EOF
submit
--all
--message=chore: slice-handoff smoke
--body-file=$run_dir/pr-body.md
--review-request-file=$run_dir/review-request-source.txt
--watch
--timeout=900
--diagnose-on-fail
--explain
EOF
)" &&
      review_request_path="$(smoke_slice_handoff_extract_field "$run_dir/repo-flow-submit.stderr" review_request_path)" &&
      review_request_block_path="$(smoke_slice_handoff_extract_field "$run_dir/repo-flow-submit.stderr" review_request_block_path)" &&
      grep -Fxq "review_request_path=$review_request_path" "$run_dir/repo-flow-submit.stderr" &&
      [ -f "$review_request_path" ] &&
      [ -f "$review_request_block_path" ] &&
      cmp -s "$run_dir/review-request.txt" "$review_request_path" &&
      grep -Fxq "Slice: Slice handoff preset review smoke" "$run_dir/review-request-source.txt" &&
      grep -Fxq "Branch: feature/slice-handoff-pr-review" "$run_dir/review-request-source.txt" &&
      grep -Fxq "Run dir: $run_dir" "$run_dir/review-request-source.txt" &&
      grep -Fq '<PR_URL>' "$run_dir/review-request-source.txt" &&
      ! grep -Fq '<TITLE>' "$run_dir/review-request-source.txt" &&
      ! grep -Fq '<BRANCH>' "$run_dir/review-request-source.txt" &&
      ! grep -Fq '<RUN_DIR>' "$run_dir/review-request-source.txt" &&
      grep -Fxq 'fake repo-flow stdout' "$run_dir/repo-flow-submit.stdout" &&
      grep -Fq 'fake repo-flow stderr' "$run_dir/repo-flow-submit.stderr" &&
      grep -Fxq 'pass' "$run_dir/pr-body-check.stdout" &&
      grep -Fxq '===== FINAL SUMMARY =====' "$run_dir/repo-flow-submit.stderr" &&
      grep -Fxq "url_or_stop=$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" "$run_dir/repo-flow-submit.stderr" &&
      python3 - "$run_dir/repo-flow-submit.stderr" "$review_request_path" "$review_request_block_path" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" "$run_dir" "$smoke_slice_handoff_expected_submit_commit_sha" "$smoke_slice_handoff_expected_submit_ci_state" <<'PY'
from pathlib import Path
import sys

stderr_path = Path(sys.argv[1])
review_request_path = Path(sys.argv[2])
review_request_block_path = Path(sys.argv[3])
expected_pr = sys.argv[4]
expected_run_dir = sys.argv[5]
expected_commit = sys.argv[6]
expected_ci = sys.argv[7]

stderr_lines = stderr_path.read_text(encoding='utf-8').splitlines()
summary_line = stderr_lines.index('===== FINAL SUMMARY =====')
codex_context_line = stderr_lines.index('===== CODEX RUN CONTEXT =====')
review_line = stderr_lines.index('===== PR REVIEW REQUEST =====')
review_end_line = stderr_lines.index('===== END PR REVIEW REQUEST =====')
summary_end_line = stderr_lines.index('===== END =====')
if not (summary_line < summary_end_line < codex_context_line < review_line < review_end_line):
    raise SystemExit(1)
if stderr_lines[summary_end_line + 1] != '':
    raise SystemExit(1)
if stderr_lines[review_line - 1] != '':
    raise SystemExit(1)
expected_review = review_request_path.read_text(encoding='utf-8')
expected_block = [
    '===== PR REVIEW REQUEST =====',
    'Review metadata:',
    f'PR: {expected_pr}',
    'Branch: feature/slice-handoff-pr-review',
    f'Run dir: {expected_run_dir}',
    f'Commit: {expected_commit}',
    f'CI: {expected_ci}',
    'Review request valid: true',
    '',
    *expected_review.splitlines(),
    '===== END PR REVIEW REQUEST =====',
]
if review_request_block_path.read_text(encoding='utf-8').splitlines() != expected_block:
    raise SystemExit(1)
PY
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/codex-prompt.md" "$smoke_slice_handoff_submit_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_execution_submit_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/pr-body.md" "$smoke_slice_handoff_submit_body" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/review-request.txt" "$smoke_slice_handoff_expected_preset_review_request" &&
      smoke_slice_handoff_assert_text_file "$run_dir/codex-run/codex-final.txt" 'Implementation complete.' &&
      grep -Fxq 'mode=execution-submit' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'result=pass' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'next=review PR before merge' "$run_dir/slice-handoff-execution-summary.txt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/slice-handoff-summary.txt" "$smoke_slice_handoff_expected_execution_submit_summary"
  ); then
    test_pass "execution-submit success"
  else
    test_fail "execution-submit success"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_execution_submit_false_positive_blocker_behavior() {
  local status=0
  local run_dir=""

  smoke_slice_handoff_prepare_execution_submit_context "false-positive" || return 1
  if (
      rm -rf -- "$smoke_slice_handoff_execution_submit_out_dir" &&
      smoke_slice_handoff_assert_execution_submit_artifact_bundle "false-positive" "$smoke_slice_handoff_execution_submit_bundle_root" "$smoke_slice_handoff_execution_fake_codex_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" &&
      smoke_slice_handoff_write_file "$smoke_slice_handoff_execution_valid_preset_file" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_submit_body" "" "repo-automation-template-pr-review" &&
      smoke_slice_handoff_assert_clean_worktree &&
      smoke_slice_handoff_set_execution_codex_run_final_text $'Implementation complete.\n\nblocker' &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_RUN_HELPER=1 FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_PR_BODY_CHECK_ARGS_FILE="$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" FAKE_REPO_FLOW_COMMIT_SHA="$smoke_slice_handoff_expected_submit_commit_sha" FAKE_REPO_FLOW_CI_STATE="$smoke_slice_handoff_expected_submit_ci_state" FAKE_REPO_FLOW_STDOUT_TEXT='fake repo-flow stdout' FAKE_REPO_FLOW_STDERR_TEXT='fake repo-flow stderr' FAKE_REPO_FLOW_URL_OR_STOP="$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" FAKE_REPO_FLOW_WATCHED="$smoke_slice_handoff_expected_submit_watched" smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-false-positive.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-false-positive.err" --file="$smoke_slice_handoff_execution_valid_preset_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir" &&
      run_dir="$(smoke_slice_handoff_assert_execution_stdout "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-false-positive.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-false-positive.err" "feature/slice-handoff-pr-review" "execution-submit" "review PR before merge" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop")" &&
      grep -Fxq "codex_final_output_path=$run_dir/codex-run/codex-final.txt" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-false-positive.out" &&
      smoke_slice_handoff_assert_execution_run_dir "$run_dir" "repo-flow-submit-all" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "$smoke_slice_handoff_submit_prompt" "$(cat <<EOF
Please review this PR before merge:

$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop

Slice: Slice handoff preset review smoke
Branch: feature/slice-handoff-pr-review
Run dir: $run_dir

Use the canonical private project review sources:
1. \`prompts/PR_REVIEW_PROMPT.md\`
2. \`projects/repo-automation-template/PROMPTS.md\` → \`PR Review Wrapper\`
3. \`projects/repo-automation-template/CURRENT_STATE.md\` for current guardrails, deferred hardening, and recent PR context.

Review the changed files and related docs, tests, metadata, helper contracts, output contracts, examples, and workflow routing for drift.

Return the full project review shape, including:
- Verdict
- Audit Coverage
- Findings
- Contract Drift Matrix
- Search Terms Used
- Tests / Enforcement Needing Updates
- Questions I Should Be Asking
- Selected Repair Architecture
- Consolidated Repair Prompt

Merge remains explicit and outside slice-handoff.
EOF
)" "$smoke_slice_handoff_submit_body" "$smoke_test_dir" "execution-submit" "review PR before merge" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" &&
      smoke_slice_handoff_assert_execution_submit_success_boundary "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-false-positive.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-false-positive.err" "feature/slice-handoff-pr-review" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" &&
      smoke_slice_handoff_assert_text_file "$run_dir/codex-run/codex-final.txt" $'Implementation complete.\n\nblocker' &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/codex-prompt.md" "$smoke_slice_handoff_submit_prompt" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/dry-run-preview.txt" "$smoke_slice_handoff_expected_execution_submit_preview" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/pr-body.md" "$smoke_slice_handoff_submit_body" &&
      smoke_slice_handoff_assert_text_file "$smoke_slice_handoff_execution_submit_out_dir/review-request.txt" "$smoke_slice_handoff_expected_preset_review_request"
  ); then
    test_pass "execution-submit false-positive blocker"
  else
    test_fail "execution-submit false-positive blocker"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_execution_submit_true_codex_blocker_behavior() {
  local status=0
  local run_dir=""

  smoke_slice_handoff_prepare_execution_submit_context "true-blocker" || return 1
  if (
    rm -rf -- "$smoke_slice_handoff_execution_submit_out_dir" &&
      smoke_slice_handoff_assert_execution_submit_artifact_bundle "true-blocker" "$smoke_slice_handoff_execution_submit_bundle_root" "$smoke_slice_handoff_execution_fake_codex_args_submit_blocker_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" &&
      smoke_slice_handoff_write_file "$smoke_slice_handoff_execution_valid_preset_file" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_submit_body" "" "repo-automation-template-pr-review" &&
      smoke_slice_handoff_assert_clean_worktree &&
      smoke_slice_handoff_set_execution_codex_run_final_text $'\nblocker\n' &&
      rm -f -- "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_RUN_HELPER=1 FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_blocker_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_PR_BODY_CHECK_ARGS_FILE="$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-blocker.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-blocker.err" --file="$smoke_slice_handoff_execution_valid_preset_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit true Codex blocker"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir "$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "execution-submit true Codex blocker")" || return 1
    if smoke_slice_handoff_assert_execution_submit_blocker_boundary "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-blocker.err" "feature/slice-handoff-pr-review" "$run_dir" "$run_dir/codex-run/codex-final.txt"; then
      test_pass "execution-submit true Codex blocker"
    else
      test_fail "execution-submit true Codex blocker"
      status=1
    fi
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_execution_failure_cases() {
  local status=0
  local run_dir=""
  local review_request_path=""
  local expected_codex_run_stdout_fallback_reason=""

  smoke_slice_handoff_prepare_execution_submit_context "missing-final" || return 1
  if (
    rm -f -- "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      smoke_slice_handoff_assert_execution_submit_artifact_bundle "missing-final" "$smoke_slice_handoff_execution_submit_bundle_root" "$smoke_slice_handoff_execution_fake_codex_args_submit_missing_final_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" &&
      smoke_slice_handoff_clear_execution_codex_run_final_text &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_RUN_HELPER=1 FAKE_CODEX_RUN_SKIP_FINAL_OUTPUT=1 FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_missing_final_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_PR_BODY_CHECK_ARGS_FILE="$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-missing-final.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-missing-final.err" --file="$smoke_slice_handoff_execution_valid_preset_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit missing codex-final"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir "$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "execution-submit missing codex-final")" || return 1
    if smoke_slice_handoff_assert_child_failure_shape "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-missing-final.err" "codex-run-output-contract" "codex-run output contract" "0" "$run_dir/codex-run.stdout" "$run_dir/codex-run.stderr" "final output file is missing or empty" "final output file is missing or empty" "repair codex-run output contract and rerun slice-handoff" &&
      pr_body_validation_info_prefix='INFO: slice-handoff ' &&
      pr_body_validation_info_suffix='PR-body validation' &&
      ! grep -Fq "${pr_body_validation_info_prefix}${pr_body_validation_info_suffix}" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-missing-final.err" &&
      ! grep -Fq 'INFO: slice-handoff repo-flow submit' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-missing-final.err" &&
      ! grep -Fq '===== PR REVIEW REQUEST =====' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-missing-final.err" &&
      [ ! -e "$run_dir/pr-body-check.stdout" ] &&
      [ ! -e "$run_dir/pr-body-check.stderr" ] &&
      [ ! -e "$run_dir/repo-flow-submit.stdout" ] &&
      [ ! -e "$run_dir/repo-flow-submit.stderr" ] &&
      [ -f "$run_dir/codex-run/codex-run-summary.txt" ] &&
      [ ! -e "$run_dir/codex-run/codex-final.txt" ]; then
      test_pass "execution-submit missing codex-final"
    else
      test_fail "execution-submit missing codex-final"
      status=1
    fi
  fi

  smoke_slice_handoff_prepare_execution_submit_context "codex-run-failure" || return 1
  if (
    rm -f -- "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      smoke_slice_handoff_assert_execution_submit_artifact_bundle "codex-run-failure" "$smoke_slice_handoff_execution_submit_bundle_root" "$smoke_slice_handoff_execution_fake_codex_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_RUN_HELPER=1 FAKE_CODEX_RUN_EXIT_CODE=1 FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_RUN_STDOUT_TEXT='' FAKE_CODEX_RUN_STDERR_TEXT='fail: forced codex-run blocker from smoke' FAKE_PR_BODY_CHECK_ARGS_FILE="$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-failure.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-failure.err" --file="$smoke_slice_handoff_execution_valid_submit_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit codex-run failure"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir "$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "execution-submit codex-run failure")" || return 1
    if smoke_slice_handoff_assert_child_failure_shape "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-failure.err" "codex-run" "repo-automation/bin/codex-run" "1" "$run_dir/codex-run.stdout" "$run_dir/codex-run.stderr" "fail: forced codex-run blocker from smoke" "fail: forced codex-run blocker from smoke" "fix codex-run and rerun slice-handoff" &&
      pr_body_validation_info_prefix='INFO: slice-handoff ' &&
      pr_body_validation_info_suffix='PR-body validation' &&
      ! grep -Fq "${pr_body_validation_info_prefix}${pr_body_validation_info_suffix}" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-failure.err" &&
      ! grep -Fq 'INFO: slice-handoff repo-flow submit' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-failure.err" &&
      [ ! -e "$run_dir/pr-body-check.stdout" ] &&
      [ ! -e "$run_dir/pr-body-check.stderr" ] &&
      [ ! -e "$run_dir/repo-flow-submit.stdout" ] &&
      [ ! -e "$run_dir/repo-flow-submit.stderr" ]; then
      test_pass "execution-submit codex-run failure"
    else
      test_fail "execution-submit codex-run failure"
      status=1
    fi
  fi

  smoke_slice_handoff_prepare_execution_submit_context "codex-run-summary-failure" || return 1
  local codex_run_failure_log="$smoke_slice_handoff_execution_submit_bundle_root/fake-codex-run-failure.log"
  local codex_run_failure_artifact="$smoke_slice_handoff_execution_submit_bundle_root/fake-codex-run-failure.artifact"
  local codex_run_failure_reason="codex summary reason from smoke"
  local codex_run_failure_fix="codex summary fix from smoke"
  local codex_run_failure_excerpt="codex summary excerpt from smoke"
  printf 'fake codex-run failure log\n' > "$codex_run_failure_log" || return 1
  printf 'fake codex-run failure artifact\n' > "$codex_run_failure_artifact" || return 1
  if (
    rm -f -- "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      smoke_slice_handoff_assert_execution_submit_artifact_bundle "codex-run-summary-failure" "$smoke_slice_handoff_execution_submit_bundle_root" "$smoke_slice_handoff_execution_fake_codex_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_RUN_HELPER=1 FAKE_CODEX_RUN_EXIT_CODE=1 FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_RUN_STDOUT_TEXT='' FAKE_CODEX_RUN_STDERR_TEXT='fail: generic codex-run stderr fallback' FAKE_CODEX_RUN_FAILURE_REASON="$codex_run_failure_reason" FAKE_CODEX_RUN_FAILURE_FIX="$codex_run_failure_fix" FAKE_CODEX_RUN_FAILURE_LOG="$codex_run_failure_log" FAKE_CODEX_RUN_FAILURE_ARTIFACT="$codex_run_failure_artifact" FAKE_CODEX_RUN_FAILURE_EXCERPT="$codex_run_failure_excerpt" FAKE_PR_BODY_CHECK_ARGS_FILE="$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" --file="$smoke_slice_handoff_execution_valid_submit_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit codex-run summary failure"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir "$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "execution-submit codex-run summary failure")" || return 1
    if smoke_slice_handoff_assert_child_failure_shape "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" "codex-run" "repo-automation/bin/codex-run" "1" "$run_dir/codex-run.stdout" "$run_dir/codex-run.stderr" "$codex_run_failure_reason" "$codex_run_failure_excerpt" "fix codex-run and rerun slice-handoff" &&
      grep -Fq 'child_summary:' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      grep -Fq "child_summary: $run_dir/codex-run/codex-run-summary.txt" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      grep -Fq "child_failure_log: $codex_run_failure_log" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      grep -Fq "child_failure_artifact: $codex_run_failure_artifact" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      grep -Fq "child_failure_excerpt: $codex_run_failure_excerpt" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      grep -Fq "reason: $codex_run_failure_reason" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      grep -Fq "fix: $codex_run_failure_fix" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      ! grep -Fq 'reason: fail: generic codex-run stderr fallback' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      ! grep -Fq '===== PR REVIEW REQUEST =====' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-summary-failure.err" &&
      [ -f "$run_dir/codex-run/codex-run-summary.txt" ] &&
      grep -Fxq "failure_reason=$codex_run_failure_reason" "$run_dir/codex-run/codex-run-summary.txt" &&
      grep -Fxq "failure_fix=$codex_run_failure_fix" "$run_dir/codex-run/codex-run-summary.txt" &&
      grep -Fxq "failure_log=$codex_run_failure_log" "$run_dir/codex-run/codex-run-summary.txt" &&
      grep -Fxq "failure_artifact=$codex_run_failure_artifact" "$run_dir/codex-run/codex-run-summary.txt" &&
      grep -Fxq "failure_excerpt=$codex_run_failure_excerpt" "$run_dir/codex-run/codex-run-summary.txt"; then
      test_pass "execution-submit codex-run summary failure"
    else
      test_fail "execution-submit codex-run summary failure"
      status=1
    fi
  fi

  smoke_slice_handoff_prepare_execution_submit_context "codex-run-stdout-fallback" || return 1
  if (
    rm -f -- "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      smoke_slice_handoff_assert_execution_submit_artifact_bundle "codex-run-stdout-fallback" "$smoke_slice_handoff_execution_submit_bundle_root" "$smoke_slice_handoff_execution_fake_codex_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_RUN_HELPER=1 FAKE_CODEX_RUN_EXIT_CODE=1 FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_RUN_STDOUT_TEXT=$'codex stdout fallback one\ncodex stdout fallback two' FAKE_CODEX_RUN_STDERR_TEXT='' FAKE_PR_BODY_CHECK_ARGS_FILE="$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-stdout-fallback.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-stdout-fallback.err" --file="$smoke_slice_handoff_execution_valid_submit_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit codex-run stdout fallback"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir "$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "execution-submit codex-run stdout fallback")" || return 1
    expected_codex_run_stdout_fallback_reason="$(printf 'codex stdout fallback one | codex stdout fallback two | final_output_path=%s/codex-run/codex-final.txt | summary_path=%s/codex-run/codex-run-summary.txt' "$run_dir" "$run_dir")"
    if smoke_slice_handoff_assert_child_failure_shape "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-stdout-fallback.err" "codex-run" "repo-automation/bin/codex-run" "1" "$run_dir/codex-run.stdout" "$run_dir/codex-run.stderr" "$expected_codex_run_stdout_fallback_reason" "$expected_codex_run_stdout_fallback_reason" "fix codex-run and rerun slice-handoff" &&
      ! grep -Fq 'INFO: slice-handoff repo-flow submit' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-run-stdout-fallback.err" &&
      [ ! -e "$run_dir/pr-body-check.stdout" ] &&
      [ ! -e "$run_dir/pr-body-check.stderr" ] &&
      [ ! -e "$run_dir/repo-flow-submit.stdout" ] &&
      [ ! -e "$run_dir/repo-flow-submit.stderr" ]; then
      test_pass "execution-submit codex-run stdout fallback"
    else
      test_fail "execution-submit codex-run stdout fallback"
      status=1
    fi
  fi

  smoke_slice_handoff_prepare_execution_submit_context "missing-codex-status-field" || return 1
  if (
    rm -f -- "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      smoke_slice_handoff_assert_execution_submit_artifact_bundle "missing-codex-status-field" "$smoke_slice_handoff_execution_submit_bundle_root" "$smoke_slice_handoff_execution_fake_codex_args_submit_file" "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" &&
      smoke_slice_handoff_set_execution_codex_run_final_text 'Implementation complete.' &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_RUN_HELPER=1 FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' FAKE_CODEX_STATUS_MISSING_FIELD='sessions[0].model.reasoning' FAKE_PR_BODY_CHECK_ARGS_FILE="$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file" FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" --file="$smoke_slice_handoff_execution_valid_submit_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit codex-status missing field"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir "$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "execution-submit codex-status missing field")" || return 1
    if grep -Fxq 'fail: codex-status recent output contract failed' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" &&
      grep -Fq 'reason: missing required codex-status field: sessions[0].model.reasoning' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" &&
      grep -Fq 'fix: repair codex-status recent output contract and rerun slice-handoff' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" &&
      grep -Fq 'details:' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" &&
      grep -Fq "stdout: $run_dir/codex-status-recent.json" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" &&
      grep -Fq "stderr: $run_dir/codex-status-recent.stderr" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" &&
      ! grep -Fq '===== CODEX RUN CONTEXT =====' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" &&
      ! grep -Fq '===== PR REVIEW REQUEST =====' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err" &&
      ! grep -Fq '===== FINAL SUMMARY =====' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-codex-status-missing-field.err"; then
      test_pass "execution-submit codex-status missing field"
    else
      test_fail "execution-submit codex-status missing field"
      status=1
    fi
  fi

  smoke_slice_handoff_restore_codex_run || return 1
  unset FAKE_CODEX_RUN_HELPER FAKE_CODEX_RUN_SKIP_FINAL_OUTPUT

  smoke_slice_handoff_prepare_execution_submit_context "pr-body-check-failure" || return 1
  if (
    rm -f -- "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" FAKE_PR_BODY_CHECK_EXIT_CODE=1 FAKE_PR_BODY_CHECK_STDERR_TEXT='fail: forced pr-body-check blocker from smoke' smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-pr-body-check.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-pr-body-check.err" --file="$smoke_slice_handoff_execution_invalid_submit_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit pr-body-check failure"
    status=1
  else
    if smoke_slice_handoff_assert_validator_failure_shape "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-pr-body-check.err" "fail: forced pr-body-check blocker from smoke" "paste this blocker into ChatGPT" &&
      [ ! -s "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" ]; then
      test_pass "execution-submit pr-body-check failure"
    else
      test_fail "execution-submit pr-body-check failure"
      status=1
    fi
  fi

  smoke_slice_handoff_prepare_execution_submit_context "repo-flow-failure" || return 1
  if (
    rm -f -- "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" FAKE_REPO_FLOW_STDOUT_TEXT='fake repo-flow stdout' FAKE_REPO_FLOW_STDERR_TEXT='fail: repo-flow submit blocker from smoke' FAKE_REPO_FLOW_EXIT_CODE=1 FAKE_REPO_FLOW_CI_STATE=fail FAKE_REPO_FLOW_PUSHED=true FAKE_REPO_FLOW_FAILURE_URL_OR_STOP_MODE=url smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow.err" --file="$smoke_slice_handoff_valid_submit_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit repo-flow failure"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir "$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "execution-submit repo-flow failure")" || return 1
    review_request_path="$(smoke_slice_handoff_extract_field "$run_dir/repo-flow-submit.stderr" review_request_path)" || return 1
    if smoke_slice_handoff_assert_child_failure_shape "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow.err" "repo-flow-submit" "repo-automation/bin/repo-flow submit" "1" "$run_dir/repo-flow-submit.stdout" "$run_dir/repo-flow-submit.stderr" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" "investigate CI failure before PR review/merge" &&
      smoke_slice_handoff_assert_execution_submit_failure_summary "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow.err" "execution-submit" "feature/slice-handoff-submit" "$run_dir" "$review_request_path" "$smoke_slice_handoff_expected_submit_repo_flow_pr" "$smoke_slice_handoff_expected_submit_commit_sha" "true" "$smoke_slice_handoff_expected_submit_watched" "fail" "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" "investigate CI failure before PR review/merge" "false" &&
      grep -Fxq 'mode=execution-submit' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'result=fail' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq "repo_flow_submit_stdout_path=$run_dir/repo-flow-submit.stdout" "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq "repo_flow_submit_stderr_path=$run_dir/repo-flow-submit.stderr" "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'pushed=true' "$run_dir/repo-flow-submit.stderr" &&
      grep -Fxq 'pass' "$run_dir/codex-run.stdout" &&
      grep -Fxq 'submit' "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      grep -Fxq 'fake repo-flow stdout' "$run_dir/repo-flow-submit.stdout" &&
      grep -Fq 'repo-flow submit blocker from smoke' "$run_dir/repo-flow-submit.stderr" &&
      ! grep -Fq '===== PR REVIEW REQUEST =====' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow.err"; then
      :
    else
      test_fail "execution-submit repo-flow failure"
      status=1
    fi
  fi

  smoke_slice_handoff_prepare_execution_submit_context "repo-flow-output-contract-failure" || return 1
  if (
    rm -f -- "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' FAKE_REPO_FLOW_ARGS_FILE="$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" FAKE_REPO_FLOW_STDOUT_TEXT='fake repo-flow stdout' FAKE_REPO_FLOW_STDERR_TEXT='fake repo-flow stderr' FAKE_REPO_FLOW_URL_OR_STOP='not-a-url' smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow-output-contract.out" "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow-output-contract.err" --file="$smoke_slice_handoff_valid_submit_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "execution-submit repo-flow output-contract failure"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir "$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "execution-quiet")" || return 1
    if smoke_slice_handoff_assert_child_failure_shape "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow-output-contract.err" "repo-flow-submit-output-contract" "repo-automation/bin/repo-flow submit output contract" "0" "$run_dir/repo-flow-submit.stdout" "$run_dir/repo-flow-submit.stderr" "missing PR URL in repo-flow submit url_or_stop output" "missing PR URL in repo-flow submit url_or_stop output" "repair repo-flow submit output contract and rerun slice-handoff" &&
      ! grep -Fq '===== PR REVIEW REQUEST =====' "$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-submit-repo-flow-output-contract.err" &&
      grep -Fxq 'fake repo-flow stdout' "$run_dir/repo-flow-submit.stdout" &&
      grep -Fxq 'fake repo-flow stderr' "$run_dir/repo-flow-submit.stderr"; then
      test_pass "execution-submit repo-flow output-contract failure"
    else
      test_fail "execution-submit repo-flow output-contract failure"
      status=1
    fi
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_no_repo_root_artifacts() {
  local status=0

  if smoke_slice_handoff_assert_no_repo_root_out_dir; then
    test_pass "slice-handoff repo-root out-dir remains absent"
  else
    test_fail "slice-handoff repo-root out-dir remains absent"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_codex_final_output_blocker_detector() {
  local status=0
  local blocker_file="$smoke_test_base/slice-handoff-blocker.txt"
  local later_blocker_file="$smoke_test_base/slice-handoff-later-blocker.txt"
  local empty_file="$smoke_test_base/slice-handoff-empty.txt"
  local whitespace_file="$smoke_test_base/slice-handoff-whitespace.txt"

  printf 'blocker\n' > "$blocker_file" || return 1
  printf 'Implementation complete.\n\nblocker\n' > "$later_blocker_file" || return 1
  : > "$empty_file" || return 1
  printf ' \t \n' > "$whitespace_file" || return 1

  if smoke_slice_handoff_assert_codex_final_output_is_blocker "$blocker_file" &&
    ! smoke_slice_handoff_assert_codex_final_output_is_blocker "$later_blocker_file" &&
    ! smoke_slice_handoff_assert_codex_final_output_is_blocker "$empty_file" &&
    ! smoke_slice_handoff_assert_codex_final_output_is_blocker "$whitespace_file" &&
    ! smoke_slice_handoff_assert_codex_final_output_is_blocker "$smoke_test_base/does-not-exist.txt"; then
    test_pass "codex final output blocker detector"
  else
    test_fail "codex final output blocker detector"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_execution_validation_manifest_trace() {
  local status=0
  local out_dir="$smoke_slice_handoff_execution_artifact_root/validation-manifest-trace-out"
  local stdout_file="$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-validation-manifest-trace.out"
  local stderr_file="$smoke_slice_handoff_execution_artifact_root/slice-handoff-execution-validation-manifest-trace.err"
  local preflight_args_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-slice-preflight.args"
  local preflight_path="$smoke_test_dir/repo-automation/bin/codex-slice-preflight"
  local run_dir=""
  local expected_manifest_path=""

  cat > "$preflight_path" <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail

args_file="$preflight_args_file"
manifest_path=""
json_requested=0

if [ -n "\$args_file" ]; then
  printf '%s\n' "\$@" > "\$args_file"
fi

for arg in "\$@"; do
  case "\$arg" in
    --json)
      json_requested=1
      ;;
    --validation-manifest=*)
      manifest_path="\${arg#--validation-manifest=}"
      ;;
  esac
done

if [ "\$json_requested" -eq 1 ]; then
  printf '{"script":"codex-slice-preflight","result":"pass","mode":"run","rc":0'
  if [ -n "\$manifest_path" ]; then
    printf ',"validation_manifest_path":"%s"' "\$manifest_path"
  fi
  printf '}\n'
else
  printf 'pass\n'
  if [ -n "\$manifest_path" ]; then
    printf 'validation_manifest_path=%s\n' "\$manifest_path"
  fi
fi

exit 0
EOF
  chmod +x "$preflight_path" || return 1
  git -C "$smoke_test_dir" update-index --skip-worktree repo-automation/bin/codex-slice-preflight || return 1

  if (
    rm -rf -- "$out_dir" &&
      smoke_slice_handoff_assert_clean_worktree &&
      PATH="$smoke_slice_handoff_execution_fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$smoke_slice_handoff_execution_fake_codex_args_none_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$smoke_slice_handoff_execution_valid_none_file" --out-dir="$out_dir"
  ); then
    run_dir="$(smoke_slice_handoff_extract_field "$stdout_file" run_dir)" || return 1
    expected_manifest_path="$run_dir/validation-manifest.json"
    if smoke_json_assert "$run_dir/preflight.json" "data.get(\"validation_manifest_path\") == \"$expected_manifest_path\"" &&
      grep -Fxq "validation_manifest_path=$expected_manifest_path" "$run_dir/slice-handoff-summary.txt" &&
      grep -Fxq "validation_manifest_path=$expected_manifest_path" "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq -- "--validation-manifest=$expected_manifest_path" "$preflight_args_file"; then
      test_pass "execution validation manifest trace"
    else
      test_fail "execution validation manifest trace"
      status=1
    fi
  else
    test_fail "execution validation manifest trace"
    status=1
  fi

  return "$status"
}

smoke_check_slice_handoff_contract_validator_json_reason_failure() {
  local status=0
  local stdout_file="$smoke_slice_handoff_execution_artifact_root/slice-handoff-validator-json-reason.out"
  local stderr_file="$smoke_slice_handoff_execution_artifact_root/slice-handoff-validator-json-reason.err"
  local validator_path="$smoke_test_dir/repo-automation/bin/slice-validator"

  smoke_slice_handoff_prepare_execution_submit_context "validator-json-reason" || return 1

  if (
    trap 'cp -- "$smoke_repo_root/repo-automation/bin/slice-validator" "$smoke_test_dir/repo-automation/bin/slice-validator" >/dev/null 2>&1 || true' EXIT
    cat > "$validator_path" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

printf '{"result":"fail","reason":"validator JSON reason"}\n'
printf 'fail: validator stderr fallback should be ignored\n' >&2
exit 1
EOF
    chmod +x "$validator_path" || return 1
    smoke_slice_handoff_run_with_isolated_temp_env "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$smoke_slice_handoff_valid_submit_file" --submit --out-dir="$smoke_slice_handoff_execution_submit_out_dir"
  ); then
    test_fail "validator json reason failure"
    status=1
  else
    if smoke_slice_handoff_assert_validator_failure_shape "$stderr_file" "validator JSON reason" &&
      ! grep -Fq 'INFO: slice-handoff preflight' "$stderr_file" &&
      ! grep -Fq '===== CODEX RUN CONTEXT =====' "$stderr_file"; then
      test_pass "validator json reason failure"
    else
      test_fail "validator json reason failure"
      status=1
    fi
  fi

  return "$status"
}

smoke_check_slice_handoff_contract() {
  return 0
}

smoke_main "$@"
# repo-automation/tests/contracts/slice-handoff.sh EOF
