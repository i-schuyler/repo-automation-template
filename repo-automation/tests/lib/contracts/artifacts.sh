# repo-automation/tests/lib/contracts/artifacts.sh

# shellcheck shell=bash



smoke_check_post_codex_packet_contract() {
  local status=0
  local output_root=""
  local output_log=""
  local help_file=""
  local packet_dir=""
  local packet_zip=""
  local summary_file=""
  local copied_file=""
  local skipped_file=""
  local index_file=""
  local label_format_stderr=""
  local label_missing_stderr=""
  local label_empty_stderr=""
  local unknown_stderr=""

  smoke_setup_temp_repo || return 1
  output_root="$smoke_test_base/post-codex-output"
  output_log="$smoke_test_base/post-codex-output.log"
  help_file="$smoke_test_base/post-codex-help.txt"
  label_format_stderr="$smoke_test_base/post-codex-label-format.stderr"
  label_missing_stderr="$smoke_test_base/post-codex-label-missing.stderr"
  label_empty_stderr="$smoke_test_base/post-codex-label-empty.stderr"
  unknown_stderr="$smoke_test_base/post-codex-unknown.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/post-codex-packet --help > "$help_file"
  ) && grep -Fq -- '--out-dir=<path>' "$help_file" && grep -Fq -- '--label=<name>' "$help_file" && grep -Fq -- '--max-bytes=<bytes>' "$help_file" && ! grep -Fq -- '--out-dir PATH' "$help_file" && ! grep -Fq -- '--label NAME' "$help_file" && ! grep -Fq -- '--max-bytes N' "$help_file"; then
    test_pass "post-codex-packet help shows strict value syntax"
  else
    test_fail "post-codex-packet help shows strict value syntax"
    status=1
  fi

  cd "$smoke_test_dir" || return 1
  printf '\npacket helper staged line\n' >> docs/testing.md || return 1
  git add docs/testing.md || return 1
  printf '\npacket helper unstaged line\n' >> README.md || return 1
  mkdir -p packet-safe-nested || return 1
  printf 'nested safe packet content\n' > packet-safe-nested/deep.txt || return 1
  mkdir -p config || return 1
  printf 'nested sensitive env packet content\n' > config/.env || return 1
  printf 'nested sensitive env local packet content\n' > config/.env.local || return 1
  printf 'sensitive env packet content\n' > .env || return 1
  mkdir -p secrets || return 1
  mkdir -p keys || return 1
  printf 'nested ssh private key packet content\n' > keys/id_rsa || return 1
  printf 'nested ssh private key packet content\n' > keys/id_ed25519 || return 1
  printf 'token packet content\n' > secrets/token.txt || return 1
  printf 'credential packet content\n' > credentials-note.txt || return 1
  python3 - <<'PY' > packet-oversized.bin
import sys
sys.stdout.write('x' * 262145)
PY
  smoke_write_artifact_safety_fixture "$smoke_test_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/post-codex-packet --label review >/dev/null 2> "$label_format_stderr"
  ); then
    test_fail "post-codex-packet rejects --label <value>"
    status=1
  elif smoke_assert_flag_error_shape "$label_format_stderr" "flag format not accepted" "--label" "use --label=<name>"; then
    test_pass "post-codex-packet rejects --label <value>"
  else
    test_fail "post-codex-packet rejects --label <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/post-codex-packet --label >/dev/null 2> "$label_missing_stderr"
  ); then
    test_fail "post-codex-packet rejects missing --label value"
    status=1
  elif smoke_assert_flag_error_shape "$label_missing_stderr" "missing flag value" "--label" "use --label=<name>"; then
    test_pass "post-codex-packet rejects missing --label value"
  else
    test_fail "post-codex-packet rejects missing --label value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/post-codex-packet --label= >/dev/null 2> "$label_empty_stderr"
  ); then
    test_fail "post-codex-packet rejects empty --label value"
    status=1
  elif smoke_assert_flag_error_shape "$label_empty_stderr" "empty flag value" "--label" "use --label=<name>"; then
    test_pass "post-codex-packet rejects empty --label value"
  else
    test_fail "post-codex-packet rejects empty --label value"
    status=1
  fi

  if REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/post-codex-packet --label=review --keep-dir --max-bytes=262144 > "$output_log"; then
    :
  else
    test_fail "post-codex-packet helper runs successfully"
    status=1
  fi

  packet_zip="$(grep -E '^/' "$output_log" | tail -n 1 | tr -d '\r')"
  packet_dir="${packet_zip%.zip}"
  summary_file="$packet_dir/summary.txt"
  copied_file="$packet_dir/untracked/copied/packet-safe-nested/deep.txt"
  skipped_file="$packet_dir/untracked/skipped.txt"
  index_file="$output_root/post-codex/index.tsv"

  if smoke_assert_single_path_output "$output_log" && [ -d "$packet_dir" ] && [ -f "$packet_zip" ] && [ -f "$summary_file" ] && [ -f "$index_file" ]; then
    test_pass "post-codex-packet helper creates packet artifacts"
  else
    test_fail "post-codex-packet helper creates packet artifacts"
    status=1
  fi

  if grep -Eq '^Branch: main$' "$summary_file" && grep -Eq '^HEAD: [0-9a-f]{40}$' "$summary_file" && grep -Eq '^Repo path: ' "$summary_file" && grep -Eq '^Packet path: ' "$summary_file" && grep -Eq '^Zip path: ' "$summary_file" && grep -Eq '^Tracked unstaged files: [1-9][0-9]*$' "$summary_file" && grep -Eq '^Staged files: [1-9][0-9]*$' "$summary_file" && grep -Eq '^Untracked files: [1-9][0-9]*$' "$summary_file" && grep -Eq '^Copied untracked files: [1-9][0-9]*$' "$summary_file" && grep -Eq '^Skipped untracked files: [1-9][0-9]*$' "$summary_file" && grep -Eq '^Max untracked copy bytes: 262144$' "$summary_file"; then
    test_pass "post-codex-packet summary reports packet metadata"
  else
    test_fail "post-codex-packet summary reports packet metadata"
    status=1
  fi

  if grep -Eq '^README.md$' "$packet_dir/tracked-unstaged/name-list.txt" && grep -Eq '^docs/testing.md$' "$packet_dir/staged/name-list.txt" && grep -Eq '^packet-safe-nested/deep.txt$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^\.editorconfig$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^docs/safe-untracked.md$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^repo-automation-output/review-pack/output.txt$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^build/output.bin$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^node_modules/pkg/cache.txt$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^vendor/cache/tool.bin$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^\.env[[:space:]]' "$skipped_file" && grep -Eq '^config/\.env[[:space:]]' "$skipped_file" && grep -Eq '^config/\.env\.local[[:space:]]' "$skipped_file" && grep -Eq '^keys/id_rsa[[:space:]]' "$skipped_file" && grep -Eq '^keys/id_ed25519[[:space:]]' "$skipped_file" && grep -Eq '^secrets/token.txt[[:space:]]' "$skipped_file" && grep -Eq '^credentials-note.txt[[:space:]]' "$skipped_file" && grep -Eq '^packet-oversized.bin[[:space:]]' "$skipped_file" && grep -Eq '^build/output.bin[[:space:]]' "$skipped_file" && grep -Eq '^node_modules/pkg/cache.txt[[:space:]]' "$skipped_file" && grep -Eq '^vendor/cache/tool.bin[[:space:]]' "$skipped_file" && grep -Eq '^repo-automation-output/review-pack/output.txt[[:space:]]' "$skipped_file" && [ -f "$packet_dir/untracked/copied/.editorconfig" ] && [ -f "$packet_dir/untracked/copied/docs/safe-untracked.md" ] && [ -f "$copied_file" ]; then
    test_pass "post-codex-packet packet contents include copied and skipped untracked files"
  else
    test_fail "post-codex-packet packet contents include copied and skipped untracked files"
    status=1
  fi

  if python3 - "$packet_zip" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
assert 'summary.txt' in names
assert 'tracked-unstaged/name-list.txt' in names
assert 'staged/name-list.txt' in names
assert 'untracked/copied/packet-safe-nested/deep.txt' in names
assert 'untracked/copied/.editorconfig' in names
assert 'untracked/copied/docs/safe-untracked.md' in names
assert 'untracked/skipped.txt' in names
assert 'untracked/copied/.env' not in names
assert 'untracked/copied/build/output.bin' not in names
assert 'untracked/copied/node_modules/pkg/cache.txt' not in names
assert 'untracked/copied/vendor/cache/tool.bin' not in names
PY
  then
    test_pass "post-codex-packet zip archive contains packet files"
  else
    test_fail "post-codex-packet zip archive contains packet files"
    status=1
  fi

  if grep -Fq "$packet_dir" "$index_file" && awk -F "\t" 'NR > 1 && $6 == "review" { found = 1 } END { exit(found ? 0 : 1) }' "$index_file"; then
    test_pass "post-codex-packet index records the packet"
  else
    test_fail "post-codex-packet index records the packet"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/post-codex-packet --whatever >/dev/null 2> "$unknown_stderr"
  ); then
    test_fail "post-codex-packet rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/post-codex-packet --help"; then
    test_pass "post-codex-packet rejects unknown flags"
  else
    test_fail "post-codex-packet rejects unknown flags"
    status=1
  fi

  return "$status"
}

smoke_check_review_pack_contract() {
  local status=0
  local output_root=""
  local codex_stub_dir=""
  local codex_called_file=""
  local help_file=""
  local target_format_stderr=""
  local target_missing_stderr=""
  local target_empty_stderr=""
  local target_unknown_stderr=""
  local out_dir_format_stderr=""
  local out_dir_missing_stderr=""
  local out_dir_empty_stderr=""
  local label_format_stderr=""
  local label_missing_stderr=""
  local label_empty_stderr=""
  local chatgpt_output_file=""
  local chatgpt_stderr_file=""
  local chatgpt_bundle_zip=""
  local chatgpt_bundle_dir=""
  local chatgpt_post_codex_output=""
  local chatgpt_post_codex_path=""
  local chatgpt_repo_zip_output=""
  local chatgpt_repo_zip_path=""
  local codex_output_file=""
  local codex_stderr_file=""
  local codex_prompt_file=""

  smoke_setup_temp_repo || return 1
  smoke_write_artifact_safety_fixture "$smoke_test_dir" || return 1
  output_root="$smoke_test_base/review-pack-output"
  codex_stub_dir="$smoke_test_base/review-pack-codex-stub"
  codex_called_file="$smoke_test_base/review-pack-codex-called.txt"
  help_file="$smoke_test_base/review-pack-help.txt"
  target_format_stderr="$smoke_test_base/review-pack-target-format.stderr"
  target_missing_stderr="$smoke_test_base/review-pack-target-missing.stderr"
  target_empty_stderr="$smoke_test_base/review-pack-target-empty.stderr"
  target_unknown_stderr="$smoke_test_base/review-pack-target-unknown.stderr"
  out_dir_format_stderr="$smoke_test_base/review-pack-out-dir-format.stderr"
  out_dir_missing_stderr="$smoke_test_base/review-pack-out-dir-missing.stderr"
  out_dir_empty_stderr="$smoke_test_base/review-pack-out-dir-empty.stderr"
  label_format_stderr="$smoke_test_base/review-pack-label-format.stderr"
  label_missing_stderr="$smoke_test_base/review-pack-label-missing.stderr"
  label_empty_stderr="$smoke_test_base/review-pack-label-empty.stderr"
  chatgpt_output_file="$smoke_test_base/review-pack-chatgpt.out"
  chatgpt_stderr_file="$smoke_test_base/review-pack-chatgpt.err"
  codex_output_file="$smoke_test_base/review-pack-codex.out"
  codex_stderr_file="$smoke_test_base/review-pack-codex.err"

  mkdir -p "$codex_stub_dir" || return 1
  cat > "$codex_stub_dir/codex" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${SMOKE_CODEX_CALLED_FILE:-/dev/null}"
printf 'codex invoked unexpectedly\n' >&2
exit 99
EOF
  chmod +x "$codex_stub_dir/codex" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --help > "$help_file"
  ) && grep -Fq -- '--target=<chatgpt|codex>' "$help_file" && grep -Fq -- '--out-dir=<path>' "$help_file" && grep -Fq -- '--label=<text>' "$help_file" && ! grep -Fq -- '--target CHATGPT' "$help_file"; then
    test_pass "review-pack help shows strict value syntax"
  else
    test_fail "review-pack help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --target chatgpt >/dev/null 2> "$target_format_stderr"
  ); then
    test_fail "review-pack rejects --target <value>"
    status=1
  elif smoke_assert_flag_error_shape "$target_format_stderr" "flag format not accepted" "--target" "use --target=<chatgpt|codex>"; then
    test_pass "review-pack rejects --target <value>"
  else
    test_fail "review-pack rejects --target <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --target >/dev/null 2> "$target_missing_stderr"
  ); then
    test_fail "review-pack rejects missing --target value"
    status=1
  elif smoke_assert_flag_error_shape "$target_missing_stderr" "missing flag value" "--target" "use --target=<chatgpt|codex>"; then
    test_pass "review-pack rejects missing --target value"
  else
    test_fail "review-pack rejects missing --target value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --target= >/dev/null 2> "$target_empty_stderr"
  ); then
    test_fail "review-pack rejects empty --target value"
    status=1
  elif smoke_assert_flag_error_shape "$target_empty_stderr" "empty flag value" "--target" "use --target=<chatgpt|codex>"; then
    test_pass "review-pack rejects empty --target value"
  else
    test_fail "review-pack rejects empty --target value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --target=watson >/dev/null 2> "$target_unknown_stderr"
  ); then
    test_fail "review-pack rejects unsupported target values"
    status=1
  elif smoke_assert_flag_error_shape "$target_unknown_stderr" "unsupported flag value" "--target" "use --target=<chatgpt|codex>"; then
    test_pass "review-pack rejects unsupported target values"
  else
    test_fail "review-pack rejects unsupported target values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --out-dir review-pack-output --target=chatgpt >/dev/null 2> "$out_dir_format_stderr"
  ); then
    test_fail "review-pack rejects --out-dir <value>"
    status=1
  elif smoke_assert_flag_error_shape "$out_dir_format_stderr" "flag format not accepted" "--out-dir" "use --out-dir=<path>"; then
    test_pass "review-pack rejects --out-dir <value>"
  else
    test_fail "review-pack rejects --out-dir <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --out-dir --target=chatgpt >/dev/null 2> "$out_dir_missing_stderr"
  ); then
    test_fail "review-pack rejects missing --out-dir value"
    status=1
  elif smoke_assert_flag_error_shape "$out_dir_missing_stderr" "missing flag value" "--out-dir" "use --out-dir=<path>"; then
    test_pass "review-pack rejects missing --out-dir value"
  else
    test_fail "review-pack rejects missing --out-dir value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --out-dir= --target=chatgpt >/dev/null 2> "$out_dir_empty_stderr"
  ); then
    test_fail "review-pack rejects empty --out-dir value"
    status=1
  elif smoke_assert_flag_error_shape "$out_dir_empty_stderr" "empty flag value" "--out-dir" "use --out-dir=<path>"; then
    test_pass "review-pack rejects empty --out-dir value"
  else
    test_fail "review-pack rejects empty --out-dir value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --label review --target=chatgpt >/dev/null 2> "$label_format_stderr"
  ); then
    test_fail "review-pack rejects --label <value>"
    status=1
  elif smoke_assert_flag_error_shape "$label_format_stderr" "flag format not accepted" "--label" "use --label=<text>"; then
    test_pass "review-pack rejects --label <value>"
  else
    test_fail "review-pack rejects --label <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --label --target=chatgpt >/dev/null 2> "$label_missing_stderr"
  ); then
    test_fail "review-pack rejects missing --label value"
    status=1
  elif smoke_assert_flag_error_shape "$label_missing_stderr" "missing flag value" "--label" "use --label=<text>"; then
    test_pass "review-pack rejects missing --label value"
  else
    test_fail "review-pack rejects missing --label value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --label= --target=chatgpt >/dev/null 2> "$label_empty_stderr"
  ); then
    test_fail "review-pack rejects empty --label value"
    status=1
  elif smoke_assert_flag_error_shape "$label_empty_stderr" "empty flag value" "--label" "use --label=<text>"; then
    test_pass "review-pack rejects empty --label value"
  else
    test_fail "review-pack rejects empty --label value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    SMOKE_CODEX_CALLED_FILE="$codex_called_file" PATH="$codex_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target=chatgpt --label=review
  ) > "$chatgpt_output_file" 2> "$chatgpt_stderr_file"; then
    :
  else
    test_fail "review-pack chatgpt bundle run succeeds"
    status=1
  fi

  chatgpt_bundle_zip="$(grep -E '^/' "$chatgpt_output_file" | tail -n 1 | tr -d '\r')"
  chatgpt_bundle_dir="${chatgpt_bundle_zip%.zip}"
  chatgpt_post_codex_output="$chatgpt_bundle_dir/post-codex/output.txt"
  chatgpt_repo_zip_output="$chatgpt_bundle_dir/repo-zip/output.txt"
  chatgpt_post_codex_path="$(grep -E '^/' "$chatgpt_post_codex_output" | tail -n 1 | tr -d '\r')"
  chatgpt_repo_zip_path="$(grep -E '^/' "$chatgpt_repo_zip_output" | tail -n 1 | tr -d '\r')"

  if smoke_assert_single_path_output "$chatgpt_output_file" && [ -f "$chatgpt_bundle_zip" ] && [ -d "$chatgpt_bundle_dir" ] && [ -f "$chatgpt_bundle_dir/summary.txt" ] && [ -f "$chatgpt_post_codex_output" ] && [ -n "$chatgpt_post_codex_path" ] && [ -f "$chatgpt_post_codex_path" ] && [ -f "$chatgpt_repo_zip_output" ] && [ -n "$chatgpt_repo_zip_path" ] && [ -f "$chatgpt_repo_zip_path" ] && [ ! -e "$smoke_test_dir/review-pack" ]; then
    test_pass "review-pack chatgpt target creates a staged review bundle"
  else
    test_fail "review-pack chatgpt target creates a staged review bundle"
    status=1
  fi

  if python3 - "$chatgpt_repo_zip_path" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    assert any(name.endswith('/.editorconfig') for name in names)
    assert any(name.endswith('/docs/safe-untracked.md') for name in names)
    assert not any('build/output.bin' in name for name in names)
    assert not any('node_modules/pkg/cache.txt' in name for name in names)
    assert not any('vendor/cache/tool.bin' in name for name in names)
    assert not any('repo-automation-output/review-pack/output.txt' in name for name in names)
    assert not any(name.endswith('/.env') or '/.env.' in name for name in names)
PY
  then
    test_pass "review-pack chatgpt bundle includes only safe repository snapshot files"
  else
    test_fail "review-pack chatgpt bundle includes only safe repository snapshot files"
    status=1
  fi

  if [ -f "$codex_called_file" ]; then
    test_fail "review-pack chatgpt target does not invoke Codex"
    status=1
  else
    test_pass "review-pack chatgpt target does not invoke Codex"
  fi

  if (
    cd "$smoke_test_dir" || return 1
    SMOKE_CODEX_CALLED_FILE="$codex_called_file" PATH="$codex_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target=codex --label=review
  ) > "$codex_output_file" 2> "$codex_stderr_file"; then
    :
  else
    test_fail "review-pack codex prompt run succeeds"
    status=1
  fi

  codex_prompt_file="$(sed -n '1p' "$codex_output_file" | tr -d '\r')"

  if smoke_assert_single_path_output "$codex_output_file" && [ -f "$codex_prompt_file" ] && [ ! -e "$smoke_test_dir/review-pack" ] && grep -Fq 'Task' "$codex_prompt_file" && grep -Fq 'Goal' "$codex_prompt_file" && grep -Fq 'Scope' "$codex_prompt_file" && grep -Fq 'Evidence excerpt' "$codex_prompt_file" && grep -Fq 'Required behavior' "$codex_prompt_file" && grep -Fq 'Not in scope' "$codex_prompt_file" && grep -Fq 'Checks required' "$codex_prompt_file" && ! grep -Fq 'Checks allowed' "$codex_prompt_file" && grep -Fq 'Output contract' "$codex_prompt_file"; then
    test_pass "review-pack codex target creates a local prompt artifact"
  else
    test_fail "review-pack codex target creates a local prompt artifact"
    status=1
  fi

  if [ -f "$codex_called_file" ]; then
    test_fail "review-pack codex target does not invoke Codex"
    status=1
  else
    test_pass "review-pack codex target does not invoke Codex"
  fi

  return "$status"
}

smoke_check_repair_prompt_contract() {
  local status=0
  local output_root=""
  local failure_log_root=""
  local codex_stub_dir=""
  local codex_called_file=""
  local help_file=""
  local source_format_stderr=""
  local source_missing_stderr=""
  local source_empty_stderr=""
  local source_unknown_stderr=""
  local target_format_stderr=""
  local target_missing_stderr=""
  local target_empty_stderr=""
  local target_unknown_stderr=""
  local evidence_file_format_stderr=""
  local evidence_file_missing_stderr=""
  local evidence_file_empty_stderr=""
  local pr_format_stderr=""
  local pr_missing_stderr=""
  local pr_empty_stderr=""
  local run_id_format_stderr=""
  local run_id_missing_stderr=""
  local run_id_empty_stderr=""
  local out_dir_format_stderr=""
  local out_dir_missing_stderr=""
  local out_dir_empty_stderr=""
  local ci_json_file=""
  local local_failure_log=""
  local ci_stub_log=""
  local ci_stub_dir=""
  local ci_stub_path=""
  local ci_output_file=""
  local ci_prompt_file=""
  local local_output_file=""
  local local_prompt_file=""
  local evidence_output_file=""
  local evidence_prompt_file=""

  smoke_setup_temp_repo || return 1
  smoke_write_artifact_safety_fixture "$smoke_test_dir" || return 1
  output_root="$smoke_test_base/repair-prompt-output"
  failure_log_root="$smoke_test_base/repair-prompt-failure"
  codex_stub_dir="$smoke_test_base/repair-prompt-codex-stub"
  codex_called_file="$smoke_test_base/repair-prompt-codex-called.txt"
  help_file="$smoke_test_base/repair-prompt-help.txt"
  source_format_stderr="$smoke_test_base/repair-prompt-source-format.stderr"
  source_missing_stderr="$smoke_test_base/repair-prompt-source-missing.stderr"
  source_empty_stderr="$smoke_test_base/repair-prompt-source-empty.stderr"
  source_unknown_stderr="$smoke_test_base/repair-prompt-source-unknown.stderr"
  target_format_stderr="$smoke_test_base/repair-prompt-target-format.stderr"
  target_missing_stderr="$smoke_test_base/repair-prompt-target-missing.stderr"
  target_empty_stderr="$smoke_test_base/repair-prompt-target-empty.stderr"
  target_unknown_stderr="$smoke_test_base/repair-prompt-target-unknown.stderr"
  evidence_file_format_stderr="$smoke_test_base/repair-prompt-evidence-format.stderr"
  evidence_file_missing_stderr="$smoke_test_base/repair-prompt-evidence-missing.stderr"
  evidence_file_empty_stderr="$smoke_test_base/repair-prompt-evidence-empty.stderr"
  pr_format_stderr="$smoke_test_base/repair-prompt-pr-format.stderr"
  pr_missing_stderr="$smoke_test_base/repair-prompt-pr-missing.stderr"
  pr_empty_stderr="$smoke_test_base/repair-prompt-pr-empty.stderr"
  run_id_format_stderr="$smoke_test_base/repair-prompt-run-id-format.stderr"
  run_id_missing_stderr="$smoke_test_base/repair-prompt-run-id-missing.stderr"
  run_id_empty_stderr="$smoke_test_base/repair-prompt-run-id-empty.stderr"
  out_dir_format_stderr="$smoke_test_base/repair-prompt-out-dir-format.stderr"
  out_dir_missing_stderr="$smoke_test_base/repair-prompt-out-dir-missing.stderr"
  out_dir_empty_stderr="$smoke_test_base/repair-prompt-out-dir-empty.stderr"
  missing_evidence_stderr="$smoke_test_base/repair-prompt-missing-evidence.stderr"
  ci_json_file="$smoke_test_base/repair-prompt-ci-evidence.json"
  local_failure_log="$failure_log_root/repo-automation-template/run-tests-20260516-120000.log"
  ci_stub_log="$smoke_test_base/repair-prompt-ci-stub.log"
  ci_stub_dir="$smoke_test_base/repair-prompt-ci-stub"
  ci_stub_path="$smoke_test_dir/repo-automation/bin/ci-log-dump"
  ci_output_file="$smoke_test_base/repair-prompt-ci.out"
  local_output_file="$smoke_test_base/repair-prompt-local.out"
  evidence_output_file="$smoke_test_base/repair-prompt-evidence.out"

  mkdir -p "$failure_log_root/repo-automation-template" "$ci_stub_dir" "$codex_stub_dir" || return 1
  cat > "$codex_stub_dir/codex" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${SMOKE_CODEX_CALLED_FILE:-/dev/null}"
printf 'codex invoked unexpectedly\n' >&2
exit 99
EOF
  chmod +x "$codex_stub_dir/codex" || return 1

  cat > "$ci_json_file" <<'EOF'
{"script":"ci-log-dump","first_failure_label":"ci failure","first_failure_excerpt":"CI excerpt line one\npassword=secret-value","recommended_fix":"Restart the job","tail_excerpt":["tail line one","tail line two"],"overall_status":"fail"}
EOF

  cat > "$local_failure_log" <<'EOF'
FAIL: local failure
excerpt: local failure line
password=supersecret
fix: rerun the command
EOF

  cat > "$ci_stub_path" <<EOF
#!/usr/bin/env bash
set -u
printf '%s\n' "\$*" >> "$ci_stub_log"
case "\$*" in
  *'--first-failure'*'--machine-json'*)
    :
    ;;
  *)
    printf 'ci-log-dump stub missing required flags\n' >&2
    exit 99
    ;;
esac
cat <<'JSON'
{"script":"ci-log-dump","first_failure_label":"gathered CI failure","first_failure_excerpt":"gathered ci excerpt\npassword=supersecret","recommended_fix":"fix the CI path","tail_excerpt":["tail line one","tail line two"],"overall_status":"fail"}
JSON
EOF
  chmod +x "$ci_stub_path" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --help > "$help_file"
  ) && grep -Fq -- '--source=<ci|local>' "$help_file" && grep -Fq -- '--target=codex' "$help_file" && grep -Fq -- '--evidence-file=<path>' "$help_file" && grep -Fq -- '--pr=<number>' "$help_file" && grep -Fq -- '--run-id=<id>' "$help_file"; then
    test_pass "repair-prompt help shows strict value syntax"
  else
    test_fail "repair-prompt help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --source ci --target=codex >/dev/null 2> "$source_format_stderr"
  ); then
    test_fail "repair-prompt rejects --source <value>"
    status=1
  elif smoke_assert_flag_error_shape "$source_format_stderr" "flag format not accepted" "--source" "use --source=<ci|local>"; then
    test_pass "repair-prompt rejects --source <value>"
  else
    test_fail "repair-prompt rejects --source <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --source >/dev/null 2> "$source_missing_stderr"
  ); then
    test_fail "repair-prompt rejects missing --source value"
    status=1
  elif smoke_assert_flag_error_shape "$source_missing_stderr" "missing flag value" "--source" "use --source=<ci|local>"; then
    test_pass "repair-prompt rejects missing --source value"
  else
    test_fail "repair-prompt rejects missing --source value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --source= --target=codex >/dev/null 2> "$source_empty_stderr"
  ); then
    test_fail "repair-prompt rejects empty --source value"
    status=1
  elif smoke_assert_flag_error_shape "$source_empty_stderr" "empty flag value" "--source" "use --source=<ci|local>"; then
    test_pass "repair-prompt rejects empty --source value"
  else
    test_fail "repair-prompt rejects empty --source value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --source=watson --target=codex >/dev/null 2> "$source_unknown_stderr"
  ); then
    test_fail "repair-prompt rejects unsupported source values"
    status=1
  elif smoke_assert_flag_error_shape "$source_unknown_stderr" "unsupported flag value" "--source" "use --source=<ci|local>"; then
    test_pass "repair-prompt rejects unsupported source values"
  else
    test_fail "repair-prompt rejects unsupported source values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --target codex --source=ci >/dev/null 2> "$target_format_stderr"
  ); then
    test_fail "repair-prompt rejects --target <value>"
    status=1
  elif smoke_assert_flag_error_shape "$target_format_stderr" "flag format not accepted" "--target" "use --target=codex"; then
    test_pass "repair-prompt rejects --target <value>"
  else
    test_fail "repair-prompt rejects --target <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --target >/dev/null 2> "$target_missing_stderr"
  ); then
    test_fail "repair-prompt rejects missing --target value"
    status=1
  elif smoke_assert_flag_error_shape "$target_missing_stderr" "missing flag value" "--target" "use --target=codex"; then
    test_pass "repair-prompt rejects missing --target value"
  else
    test_fail "repair-prompt rejects missing --target value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --target= >/dev/null 2> "$target_empty_stderr"
  ); then
    test_fail "repair-prompt rejects empty --target value"
    status=1
  elif smoke_assert_flag_error_shape "$target_empty_stderr" "empty flag value" "--target" "use --target=codex"; then
    test_pass "repair-prompt rejects empty --target value"
  else
    test_fail "repair-prompt rejects empty --target value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --target=chatgpt --source=ci >/dev/null 2> "$target_unknown_stderr"
  ); then
    test_fail "repair-prompt rejects unsupported target values"
    status=1
  elif smoke_assert_flag_error_shape "$target_unknown_stderr" "unsupported flag value" "--target" "use --target=codex"; then
    test_pass "repair-prompt rejects unsupported target values"
  else
    test_fail "repair-prompt rejects unsupported target values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --evidence-file review-prompt.json --source=ci --target=codex >/dev/null 2> "$evidence_file_format_stderr"
  ); then
    test_fail "repair-prompt rejects --evidence-file <value>"
    status=1
  elif smoke_assert_flag_error_shape "$evidence_file_format_stderr" "flag format not accepted" "--evidence-file" "use --evidence-file=<path>"; then
    test_pass "repair-prompt rejects --evidence-file <value>"
  else
    test_fail "repair-prompt rejects --evidence-file <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --evidence-file --source=ci --target=codex >/dev/null 2> "$evidence_file_missing_stderr"
  ); then
    test_fail "repair-prompt rejects missing --evidence-file value"
    status=1
  elif smoke_assert_flag_error_shape "$evidence_file_missing_stderr" "missing flag value" "--evidence-file" "use --evidence-file=<path>"; then
    test_pass "repair-prompt rejects missing --evidence-file value"
  else
    test_fail "repair-prompt rejects missing --evidence-file value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --evidence-file= --source=ci --target=codex >/dev/null 2> "$evidence_file_empty_stderr"
  ); then
    test_fail "repair-prompt rejects empty --evidence-file value"
    status=1
  elif smoke_assert_flag_error_shape "$evidence_file_empty_stderr" "empty flag value" "--evidence-file" "use --evidence-file=<path>"; then
    test_pass "repair-prompt rejects empty --evidence-file value"
  else
    test_fail "repair-prompt rejects empty --evidence-file value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --pr 123 --source=ci --target=codex >/dev/null 2> "$pr_format_stderr"
  ); then
    test_fail "repair-prompt rejects --pr <value>"
    status=1
  elif smoke_assert_flag_error_shape "$pr_format_stderr" "flag format not accepted" "--pr" "use --pr=<number>"; then
    test_pass "repair-prompt rejects --pr <value>"
  else
    test_fail "repair-prompt rejects --pr <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --pr --source=ci --target=codex >/dev/null 2> "$pr_missing_stderr"
  ); then
    test_fail "repair-prompt rejects missing --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$pr_missing_stderr" "missing flag value" "--pr" "use --pr=<number>"; then
    test_pass "repair-prompt rejects missing --pr value"
  else
    test_fail "repair-prompt rejects missing --pr value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --pr= --source=ci --target=codex >/dev/null 2> "$pr_empty_stderr"
  ); then
    test_fail "repair-prompt rejects empty --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$pr_empty_stderr" "empty flag value" "--pr" "use --pr=<number>"; then
    test_pass "repair-prompt rejects empty --pr value"
  else
    test_fail "repair-prompt rejects empty --pr value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --run-id 123 --source=ci --target=codex >/dev/null 2> "$run_id_format_stderr"
  ); then
    test_fail "repair-prompt rejects --run-id <value>"
    status=1
  elif smoke_assert_flag_error_shape "$run_id_format_stderr" "flag format not accepted" "--run-id" "use --run-id=<id>"; then
    test_pass "repair-prompt rejects --run-id <value>"
  else
    test_fail "repair-prompt rejects --run-id <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --run-id --source=ci --target=codex >/dev/null 2> "$run_id_missing_stderr"
  ); then
    test_fail "repair-prompt rejects missing --run-id value"
    status=1
  elif smoke_assert_flag_error_shape "$run_id_missing_stderr" "missing flag value" "--run-id" "use --run-id=<id>"; then
    test_pass "repair-prompt rejects missing --run-id value"
  else
    test_fail "repair-prompt rejects missing --run-id value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --run-id= --source=ci --target=codex >/dev/null 2> "$run_id_empty_stderr"
  ); then
    test_fail "repair-prompt rejects empty --run-id value"
    status=1
  elif smoke_assert_flag_error_shape "$run_id_empty_stderr" "empty flag value" "--run-id" "use --run-id=<id>"; then
    test_pass "repair-prompt rejects empty --run-id value"
  else
    test_fail "repair-prompt rejects empty --run-id value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --out-dir repair-prompt-output --source=ci --target=codex >/dev/null 2> "$out_dir_format_stderr"
  ); then
    test_fail "repair-prompt rejects --out-dir <value>"
    status=1
  elif smoke_assert_flag_error_shape "$out_dir_format_stderr" "flag format not accepted" "--out-dir" "use --out-dir=<path>"; then
    test_pass "repair-prompt rejects --out-dir <value>"
  else
    test_fail "repair-prompt rejects --out-dir <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --out-dir --source=ci --target=codex >/dev/null 2> "$out_dir_missing_stderr"
  ); then
    test_fail "repair-prompt rejects missing --out-dir value"
    status=1
  elif smoke_assert_flag_error_shape "$out_dir_missing_stderr" "missing flag value" "--out-dir" "use --out-dir=<path>"; then
    test_pass "repair-prompt rejects missing --out-dir value"
  else
    test_fail "repair-prompt rejects missing --out-dir value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --out-dir= --source=ci --target=codex >/dev/null 2> "$out_dir_empty_stderr"
  ); then
    test_fail "repair-prompt rejects empty --out-dir value"
    status=1
  elif smoke_assert_flag_error_shape "$out_dir_empty_stderr" "empty flag value" "--out-dir" "use --out-dir=<path>"; then
    test_pass "repair-prompt rejects empty --out-dir value"
  else
    test_fail "repair-prompt rejects empty --out-dir value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repair-prompt --source=ci --target=codex --evidence-file="$smoke_test_dir/missing-evidence.json" >/dev/null 2> "$missing_evidence_stderr"
  ); then
    test_fail "repair-prompt rejects missing evidence file"
    status=1
  elif grep -Fqx "fail: missing evidence file: $smoke_test_dir/missing-evidence.json" "$missing_evidence_stderr" && grep -Fqx 'fix: pass --evidence-file=<path> to an existing CI or local evidence file' "$missing_evidence_stderr"; then
    test_pass "repair-prompt rejects missing evidence file"
  else
    test_fail "repair-prompt rejects missing evidence file"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    SMOKE_CODEX_CALLED_FILE="$codex_called_file" REPO_AUTOMATION_OUTPUT_DIR="$output_root" PATH="$codex_stub_dir:$PATH" repo-automation/bin/repair-prompt --source=ci --target=codex --evidence-file="$ci_json_file"
  ) > "$evidence_output_file" 2> "$local_output_file"; then
    :
  else
    test_fail "repair-prompt evidence-file run succeeds"
    status=1
  fi

  evidence_prompt_file="$(sed -n '1p' "$evidence_output_file" | tr -d '\r')"
  if smoke_assert_single_path_output "$evidence_output_file" && [ -f "$evidence_prompt_file" ] && grep -Fq 'CI excerpt line one' "$evidence_prompt_file" && grep -Fq 'Restart the job' "$evidence_prompt_file" && grep -Fq 'Output: pass or blocker only.' "$evidence_prompt_file" && ! grep -Fq 'password=secret-value' "$evidence_prompt_file" && ! grep -Fq 'supersecret' "$evidence_prompt_file" && ! grep -Fq 'Checks allowed' "$evidence_prompt_file" && [ ! -e "$smoke_test_dir/repair-prompt" ]; then
    test_pass "repair-prompt uses provided CI evidence file and redacts secrets"
  else
    test_fail "repair-prompt uses provided CI evidence file and redacts secrets"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    SMOKE_CODEX_CALLED_FILE="$codex_called_file" REPO_AUTOMATION_OUTPUT_DIR="$output_root" PATH="$codex_stub_dir:$PATH" repo-automation/bin/repair-prompt --source=ci --target=codex --pr=123
  ) > "$ci_output_file" 2> "$local_output_file"; then
    :
  else
    test_fail "repair-prompt CI gather run succeeds"
    status=1
  fi

  ci_prompt_file="$(sed -n '1p' "$ci_output_file" | tr -d '\r')"
  if grep -Fq -- '--first-failure' "$ci_stub_log" && grep -Fq -- '--machine-json' "$ci_stub_log" && grep -Fq -- '--pr=123' "$ci_stub_log" && [ -f "$ci_prompt_file" ] && grep -Fq 'gathered CI failure' "$ci_prompt_file" && grep -Fq 'fix the CI path' "$ci_prompt_file" && grep -Fq 'Output: pass or blocker only.' "$ci_prompt_file" && ! grep -Fq 'supersecret' "$ci_prompt_file" && ! grep -Fq 'Checks allowed' "$ci_prompt_file" && smoke_assert_single_path_output "$ci_output_file"; then
    test_pass "repair-prompt gathers CI evidence with ci-log-dump"
  else
    test_fail "repair-prompt gathers CI evidence with ci-log-dump"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    SMOKE_CODEX_CALLED_FILE="$codex_called_file" TMPDIR="$failure_log_root" REPO_AUTOMATION_OUTPUT_DIR="$output_root" PATH="$codex_stub_dir:$PATH" repo-automation/bin/repair-prompt --source=local --target=codex
  ) > "$local_output_file" 2>&1; then
    :
  else
    test_fail "repair-prompt local gather run succeeds"
    status=1
  fi

  local_prompt_file="$(sed -n '1p' "$local_output_file" | tr -d '\r')"
  if smoke_assert_single_path_output "$local_output_file" && [ -f "$local_prompt_file" ] && grep -Fq 'Local failure evidence' "$local_prompt_file" && grep -Fq 'local failure line' "$local_prompt_file" && grep -Fq 'Checks required' "$local_prompt_file" && grep -Fq 'Output: pass or blocker only.' "$local_prompt_file" && ! grep -Fq 'Checks allowed' "$local_prompt_file" && ! grep -Fq 'password=supersecret' "$local_prompt_file" && ! grep -Fq 'supersecret' "$local_prompt_file" && [ ! -e "$smoke_test_dir/repair-prompt" ]; then
    test_pass "repair-prompt local source creates a prompt artifact"
  else
    test_fail "repair-prompt local source creates a prompt artifact"
    status=1
  fi

  if [ -f "$codex_called_file" ]; then
    test_fail "repair-prompt target=codex does not invoke Codex"
    status=1
  else
    test_pass "repair-prompt target=codex does not invoke Codex"
  fi

  return "$status"
}

smoke_check_repo_zip_contract() {
  local status=0
  local output_root=""
  local output_log=""
  local label_format_stderr=""
  local label_missing_stderr=""
  local label_empty_stderr=""
  local unknown_flag_stderr=""
  local zip_path=""
  local packet_dir=""
  local summary_file=""
  local files_file=""
  local zip_root=""

  smoke_setup_temp_repo || return 1
  output_root="$smoke_test_dir/repo-automation-output"
  output_log="$smoke_test_base/repo-zip-output.log"

  cd "$smoke_test_dir" || return 1
  printf 'tracked base\n' > tracked.txt || return 1
  git add tracked.txt || return 1
  git commit -m "add tracked snapshot file" >/dev/null || return 1
  printf '\ntracked update\n' >> tracked.txt || return 1
  printf 'ignored.log\n' > .gitignore || return 1
  git add .gitignore || return 1
  git commit -m "add ignore rule" >/dev/null || return 1
  printf 'untracked content\n' > untracked.txt || return 1
  printf 'ignored artifact\n' > ignored.log || return 1
  printf 'git internals\n' > .git/repo-zip-sentinel || return 1
  mkdir -p post-codex ci-log-dump repo-zip repo-automation-output/repo-zip || return 1
  printf 'tracked helper file\n' > repo-automation/bin/ci-log-dump || return 1
  git add repo-automation/bin/ci-log-dump || return 1
  git commit -m "add ci-log-dump helper file" >/dev/null || return 1
  printf 'post codex artifact\n' > post-codex/payload.txt || return 1
  printf 'ci log artifact\n' > ci-log-dump/actions_run_123.log || return 1
  printf 'repo zip artifact\n' > repo-zip/staging.txt || return 1
  printf 'self output artifact\n' > repo-automation-output/repo-zip/previous.txt || return 1
  mkdir -p nested/subdir || return 1
  smoke_write_artifact_safety_fixture "$smoke_test_dir" || return 1

  if (
    cd nested/subdir || exit 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/repo-zip --label=review
  ) > "$output_log"; then
    :
  else
    test_fail "repo-zip helper runs successfully"
    status=1
  fi

  zip_path="$(grep -E '^/' "$output_log" | tail -n 1 | tr -d '\r')"
  packet_dir="$(dirname "$zip_path")"
  summary_file="$packet_dir/summary.txt"
  files_file="$packet_dir/files.txt"
  zip_root="$(basename "$smoke_test_dir")"

  if smoke_assert_single_path_output "$output_log" && [ -d "$packet_dir" ] && [ -f "$zip_path" ] && [ -f "$summary_file" ] && [ -f "$files_file" ]; then
    test_pass "repo-zip helper creates packet artifacts"
  else
    test_fail "repo-zip helper creates packet artifacts"
    status=1
  fi

  if grep -Eq '^Repo path: ' "$summary_file" && grep -Eq '^Branch: main$' "$summary_file" && grep -Eq '^HEAD: [0-9a-f]{40}$' "$summary_file" && grep -Eq '^Zip path: ' "$summary_file" && grep -Eq '^File count: [1-9][0-9]*$' "$summary_file" && grep -Eq '^Zip size: [1-9][0-9]* bytes$' "$summary_file" && grep -Eq '^Zip modified time: ' "$summary_file"; then
    test_pass "repo-zip summary reports zip metadata"
  else
    test_fail "repo-zip summary reports zip metadata"
    status=1
  fi

  if grep -Eq '^tracked\.txt$' "$files_file" && grep -Eq '^untracked\.txt$' "$files_file" && grep -Eq '^repo-automation/bin/repo-zip$' "$files_file" && grep -Eq '^repo-automation/bin/ci-log-dump$' "$files_file" && grep -Eq '^\.editorconfig$' "$files_file" && grep -Eq '^docs/safe-untracked.md$' "$files_file" && ! grep -Eq '^ignored\.log$' "$files_file" && ! grep -Eq '^\.env$' "$files_file" && ! grep -Eq '^build/output\.bin$' "$files_file" && ! grep -Eq '^node_modules/pkg/cache\.txt$' "$files_file" && ! grep -Eq '^vendor/cache/tool\.bin$' "$files_file" && ! grep -Eq '^repo-automation-output/review-pack/output\.txt$' "$files_file" && ! grep -Eq '(^|/)\.git(/|$)' "$files_file" && ! grep -Eq '^post-codex/' "$files_file" && ! grep -Eq '^ci-log-dump/' "$files_file" && ! grep -Eq '^repo-zip/' "$files_file" && ! grep -Eq '^review-pack/' "$files_file" && ! grep -Eq '^repair-prompt/' "$files_file" && ! grep -Eq '^evidence-bundle/' "$files_file" && ! grep -Eq '^repo-automation-output/' "$files_file"; then
    test_pass "repo-zip file selection includes tracked and untracked non-ignored files only"
  else
    test_fail "repo-zip file selection includes tracked and untracked non-ignored files only"
    status=1
  fi

  if python3 - "$zip_path" "$zip_root" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
zip_root = sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    tracked_name = f'{zip_root}/tracked.txt'
    untracked_name = f'{zip_root}/untracked.txt'
    helper_name = f'{zip_root}/repo-automation/bin/repo-zip'
    ci_log_dump_name = f'{zip_root}/repo-automation/bin/ci-log-dump'
    dotfile_name = f'{zip_root}/.editorconfig'
    doc_name = f'{zip_root}/docs/safe-untracked.md'
    ignored_name = f'{zip_root}/ignored.log'
    assert tracked_name in names
    assert untracked_name in names
    assert helper_name in names
    assert ci_log_dump_name in names
    assert dotfile_name in names
    assert doc_name in names
    assert ignored_name not in names
    assert not any(name == f'{zip_root}/.git' or name.startswith(f'{zip_root}/.git/') for name in names)
    assert not any('post-codex/' in name or 'ci-log-dump/' in name or 'repo-zip/' in name or 'review-pack/' in name or 'repair-prompt/' in name or 'evidence-bundle/' in name or 'repo-automation-output/' in name for name in names)
    assert archive.read(tracked_name).decode('utf-8').endswith('tracked update\n')
    assert archive.read(untracked_name).decode('utf-8') == 'untracked content\n'
PY
  then
    test_pass "repo-zip archive contains tracked and untracked files"
  else
    test_fail "repo-zip archive contains tracked and untracked files"
    status=1
  fi

  label_format_stderr="$smoke_test_base/repo-zip-label-format.stderr"
  label_missing_stderr="$smoke_test_base/repo-zip-label-missing.stderr"
  label_empty_stderr="$smoke_test_base/repo-zip-label-empty.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/repo-zip --label review >/dev/null 2> "$label_format_stderr"
  ); then
    test_fail "repo-zip rejects --label <value>"
    status=1
  elif smoke_assert_flag_error_shape "$label_format_stderr" "flag format not accepted" "--label" "use --label=<name>"; then
    test_pass "repo-zip rejects --label <value>"
  else
    test_fail "repo-zip rejects --label <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/repo-zip --label >/dev/null 2> "$label_missing_stderr"
  ); then
    test_fail "repo-zip rejects missing --label value"
    status=1
  elif smoke_assert_flag_error_shape "$label_missing_stderr" "missing flag value" "--label" "use --label=<name>"; then
    test_pass "repo-zip rejects missing --label value"
  else
    test_fail "repo-zip rejects missing --label value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/repo-zip --label= >/dev/null 2> "$label_empty_stderr"
  ); then
    test_fail "repo-zip rejects empty --label value"
    status=1
  elif smoke_assert_flag_error_shape "$label_empty_stderr" "empty flag value" "--label" "use --label=<name>"; then
    test_pass "repo-zip rejects empty --label value"
  else
    test_fail "repo-zip rejects empty --label value"
    status=1
  fi

  unknown_flag_stderr="$smoke_test_base/repo-zip-unknown.stderr"
  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/repo-zip --whatever >/dev/null 2> "$unknown_flag_stderr"
  ); then
    test_fail "repo-zip rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_flag_stderr" "unknown flag" "--whatever" "run repo-automation/bin/repo-zip --help"; then
    test_pass "repo-zip rejects unknown flags"
  else
    test_fail "repo-zip rejects unknown flags"
    status=1
  fi

  return "$status"
}

smoke_check_evidence_bundle_contract() {
  local status=0
  local output_root=""
  local failure_log_root=""
  local gh_stub_dir=""
  local nested_dir=""
  local default_output_log=""
  local label_format_stderr=""
  local label_missing_stderr=""
  local label_empty_stderr=""
  local pr_format_stderr=""
  local pr_missing_stderr=""
  local pr_empty_stderr=""
  local lines_format_stderr=""
  local lines_missing_stderr=""
  local lines_empty_stderr=""
  local unknown_flag_stderr=""
  local default_bundle_dir=""
  local default_bundle_zip=""
  local default_summary_file=""
  local default_status_file=""
  local default_touched_file=""
  local default_failure_log_file=""
  local default_bundle_root=""
  local post_output_log=""
  local post_bundle_dir=""
  local post_bundle_zip=""
  local post_summary_file=""
  local post_bundle_root=""
  local pr_output_log=""
  local pr_bundle_dir=""
  local pr_bundle_zip=""
  local pr_summary_file=""
  local pr_bundle_root=""

  smoke_setup_temp_repo || return 1
  output_root="$smoke_test_base/evidence-bundle-output"
  failure_log_root="$smoke_test_base/evidence-bundle-tmp"
  gh_stub_dir="$smoke_test_base/gh-stub-evidence-bundle"
  nested_dir="$smoke_test_dir/nested/subdir"
  default_output_log="$smoke_test_base/evidence-bundle-default.log"
  post_output_log="$smoke_test_base/evidence-bundle-post.log"
  pr_output_log="$smoke_test_base/evidence-bundle-pr.log"

  mkdir -p "$failure_log_root/repo-automation-template" "$nested_dir" || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1

  cd "$smoke_test_dir" || return 1
  printf 'tracked base\n' > tracked.txt || return 1
  git add tracked.txt || return 1
  git commit -m "add tracked bundle file" >/dev/null || return 1
  printf '\ntracked update\n' >> tracked.txt || return 1
  printf 'ignored.log\n' > .gitignore || return 1
  git add .gitignore || return 1
  git commit -m "add bundle ignore rule" >/dev/null || return 1
  printf 'untracked content\n' > untracked.txt || return 1
  printf 'ignored artifact\n' > ignored.log || return 1
  printf 'latest failure line\n' > "$failure_log_root/repo-automation-template/run-tests-20260512-120000.log" || return 1

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label=review
  ) > "$default_output_log"; then
    :
  else
    test_fail "evidence-bundle helper runs successfully"
    status=1
  fi

  default_bundle_zip="$(grep -E '^/' "$default_output_log" | tail -n 1 | tr -d '\r')"
  default_bundle_dir="${default_bundle_zip%.zip}"
  default_summary_file="$default_bundle_dir/summary.txt"
  default_status_file="$default_bundle_dir/git-status-short.txt"
  default_touched_file="$default_bundle_dir/touched-files.json"
  default_failure_log_file="$default_bundle_dir/failure-log.txt"
  default_bundle_root="$(basename "$default_bundle_dir")"

  if smoke_assert_single_path_output "$default_output_log" && [ -d "$default_bundle_dir" ] && [ -f "$default_bundle_zip" ] && [ -f "$default_summary_file" ] && [ -f "$default_status_file" ] && [ -f "$default_touched_file" ] && [ -f "$default_failure_log_file" ]; then
    test_pass "evidence-bundle helper creates bundle artifacts"
  else
    test_fail "evidence-bundle helper creates bundle artifacts"
    status=1
  fi

  if grep -Fqx "Repo path: $smoke_test_dir" "$default_summary_file" && grep -Eq '^Branch: main$' "$default_summary_file" && grep -Eq '^HEAD: [0-9a-f]{40}$' "$default_summary_file" && grep -Eq '^PR number: $' "$default_summary_file" && grep -Eq '^Bundle dir: ' "$default_summary_file" && grep -Eq '^Bundle zip: ' "$default_summary_file" && grep -Eq '^Included sections: .*git-status-short.*touched-files.*failure-log' "$default_summary_file" && grep -Eq '^Skipped sections: .*ci-log-dump \(no --pr\).*post-codex-packet \(not requested\).*repo-zip \(not requested\)' "$default_summary_file"; then
    test_pass "evidence-bundle summary reports core metadata"
  else
    test_fail "evidence-bundle summary reports core metadata"
    status=1
  fi

  if grep -Eq 'tracked\.txt' "$default_status_file" && grep -Eq 'untracked\.txt' "$default_status_file"; then
    test_pass "evidence-bundle status snapshot captures tracked and untracked files"
  else
    test_fail "evidence-bundle status snapshot captures tracked and untracked files"
    status=1
  fi

  if smoke_json_assert "$default_touched_file" 'data.get("mode") == "working-tree" and "tracked.txt" in data.get("working_tree_tracked_files", []) and "untracked.txt" in data.get("untracked_files", []) and "ignored.log" not in data.get("untracked_files", [])'; then
    test_pass "evidence-bundle touched-files output captures working tree evidence"
  else
    test_fail "evidence-bundle touched-files output captures working tree evidence"
    status=1
  fi

  if grep -Eq '^Latest failure log: ' "$default_failure_log_file" && ! grep -q 'gh stub unexpected command' "$default_output_log"; then
    test_pass "evidence-bundle default mode avoids network-only CI behavior"
  else
    test_fail "evidence-bundle default mode avoids network-only CI behavior"
    status=1
  fi

  if python3 - "$default_bundle_zip" "$default_bundle_root" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
bundle_root = sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    summary_name = f'{bundle_root}/summary.txt'
    status_name = f'{bundle_root}/git-status-short.txt'
    touched_name = f'{bundle_root}/touched-files.json'
    failure_name = f'{bundle_root}/failure-log.txt'
    ignored_name = f'{bundle_root}/ignored.log'
    assert summary_name in names
    assert status_name in names
    assert touched_name in names
    assert failure_name in names
    assert ignored_name not in names
    assert not any(name.startswith(f'{bundle_root}/ci-log-dump/') for name in names)
    assert not any(name.startswith(f'{bundle_root}/post-codex/') for name in names)
    assert not any(name.startswith(f'{bundle_root}/repo-zip/') for name in names)
PY
  then
    test_pass "evidence-bundle default archive contains only core sections"
  else
    test_fail "evidence-bundle default archive contains only core sections"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label=review --post-codex --include-repo-zip
  ) > "$post_output_log"; then
    :
  else
    test_fail "evidence-bundle helper records optional artifact sections"
    status=1
  fi

  post_bundle_zip="$(grep -E '^/' "$post_output_log" | tail -n 1 | tr -d '\r')"
  post_bundle_dir="${post_bundle_zip%.zip}"
  post_summary_file="$post_bundle_dir/summary.txt"
  post_bundle_root="$(basename "$post_bundle_dir")"

  if grep -Eq '^Included sections: .*post-codex-packet.*repo-zip' "$post_summary_file" && grep -Eq '^Post-codex packet zip: ' "$post_summary_file" && grep -Eq '^Repo snapshot zip: ' "$post_summary_file" && smoke_assert_single_path_output "$post_bundle_dir/post-codex/output.txt" && smoke_assert_single_path_output "$post_bundle_dir/repo-zip/output.txt"; then
    test_pass "evidence-bundle summary records optional packet paths"
  else
    test_fail "evidence-bundle summary records optional packet paths"
    status=1
  fi

  if smoke_assert_single_path_output "$post_output_log" && [ -f "$post_bundle_zip" ]; then
    test_pass "evidence-bundle optional artifact run reports packet zip paths"
  else
    test_fail "evidence-bundle optional artifact run reports packet zip paths"
    status=1
  fi

  if python3 - "$post_bundle_zip" "$post_bundle_root" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
bundle_root = sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    assert any(name.startswith(f'{bundle_root}/post-codex/') for name in names)
    assert any(name.startswith(f'{bundle_root}/repo-zip/') for name in names)
    assert f'{bundle_root}/summary.txt' in names
PY
  then
    test_pass "evidence-bundle archive contains optional packet directories"
  else
    test_fail "evidence-bundle archive contains optional packet directories"
    status=1
  fi

  label_format_stderr="$smoke_test_base/evidence-bundle-label-format.stderr"
  label_missing_stderr="$smoke_test_base/evidence-bundle-label-missing.stderr"
  label_empty_stderr="$smoke_test_base/evidence-bundle-label-empty.stderr"
  pr_format_stderr="$smoke_test_base/evidence-bundle-pr-format.stderr"
  pr_missing_stderr="$smoke_test_base/evidence-bundle-pr-missing.stderr"
  pr_empty_stderr="$smoke_test_base/evidence-bundle-pr-empty.stderr"
  lines_format_stderr="$smoke_test_base/evidence-bundle-lines-format.stderr"
  lines_missing_stderr="$smoke_test_base/evidence-bundle-lines-missing.stderr"
  lines_empty_stderr="$smoke_test_base/evidence-bundle-lines-empty.stderr"

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label review >/dev/null 2> "$label_format_stderr"
  ); then
    test_fail "evidence-bundle rejects --label <value>"
    status=1
  elif smoke_assert_flag_error_shape "$label_format_stderr" "flag format not accepted" "--label" "use --label=<name>"; then
    test_pass "evidence-bundle rejects --label <value>"
  else
    test_fail "evidence-bundle rejects --label <value>"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label >/dev/null 2> "$label_missing_stderr"
  ); then
    test_fail "evidence-bundle rejects missing --label value"
    status=1
  elif smoke_assert_flag_error_shape "$label_missing_stderr" "missing flag value" "--label" "use --label=<name>"; then
    test_pass "evidence-bundle rejects missing --label value"
  else
    test_fail "evidence-bundle rejects missing --label value"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label= >/dev/null 2> "$label_empty_stderr"
  ); then
    test_fail "evidence-bundle rejects empty --label value"
    status=1
  elif smoke_assert_flag_error_shape "$label_empty_stderr" "empty flag value" "--label" "use --label=<name>"; then
    test_pass "evidence-bundle rejects empty --label value"
  else
    test_fail "evidence-bundle rejects empty --label value"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --pr 123 >/dev/null 2> "$pr_format_stderr"
  ); then
    test_fail "evidence-bundle rejects --pr <value>"
    status=1
  elif smoke_assert_flag_error_shape "$pr_format_stderr" "flag format not accepted" "--pr" "use --pr=<number>"; then
    test_pass "evidence-bundle rejects --pr <value>"
  else
    test_fail "evidence-bundle rejects --pr <value>"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --pr >/dev/null 2> "$pr_missing_stderr"
  ); then
    test_fail "evidence-bundle rejects missing --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$pr_missing_stderr" "missing flag value" "--pr" "use --pr=<number>"; then
    test_pass "evidence-bundle rejects missing --pr value"
  else
    test_fail "evidence-bundle rejects missing --pr value"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --pr= >/dev/null 2> "$pr_empty_stderr"
  ); then
    test_fail "evidence-bundle rejects empty --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$pr_empty_stderr" "empty flag value" "--pr" "use --pr=<number>"; then
    test_pass "evidence-bundle rejects empty --pr value"
  else
    test_fail "evidence-bundle rejects empty --pr value"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --lines 1 >/dev/null 2> "$lines_format_stderr"
  ); then
    test_fail "evidence-bundle rejects --lines <value>"
    status=1
  elif smoke_assert_flag_error_shape "$lines_format_stderr" "flag format not accepted" "--lines" "use --lines=<lines>"; then
    test_pass "evidence-bundle rejects --lines <value>"
  else
    test_fail "evidence-bundle rejects --lines <value>"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --lines >/dev/null 2> "$lines_missing_stderr"
  ); then
    test_fail "evidence-bundle rejects missing --lines value"
    status=1
  elif smoke_assert_flag_error_shape "$lines_missing_stderr" "missing flag value" "--lines" "use --lines=<lines>"; then
    test_pass "evidence-bundle rejects missing --lines value"
  else
    test_fail "evidence-bundle rejects missing --lines value"
    status=1
  fi

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --lines= >/dev/null 2> "$lines_empty_stderr"
  ); then
    test_fail "evidence-bundle rejects empty --lines value"
    status=1
  elif smoke_assert_flag_error_shape "$lines_empty_stderr" "empty flag value" "--lines" "use --lines=<lines>"; then
    test_pass "evidence-bundle rejects empty --lines value"
  else
    test_fail "evidence-bundle rejects empty --lines value"
    status=1
  fi

  unknown_flag_stderr="$smoke_test_base/evidence-bundle-unknown.stderr"
  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --whatever >/dev/null 2> "$unknown_flag_stderr"
  ); then
    test_fail "evidence-bundle rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_flag_stderr" "unknown flag" "--whatever" "run repo-automation/bin/evidence-bundle --help"; then
    test_pass "evidence-bundle rejects unknown flags"
  else
    test_fail "evidence-bundle rejects unknown flags"
    status=1
  fi

  (
    cd "$smoke_test_dir" || exit 1
    git remote set-url origin git@github.com:example/evidence-bundle-fixture.git
  ) || return 1

  if (
    cd nested/subdir || exit 1
    TMPDIR="$failure_log_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_VIEW_HEAD_REF='feature/evidence-bundle' GH_STUB_RUN_LIST_JSON='[{"databaseId":222,"conclusion":"failure"}]' GH_STUB_RUN_VIEW_LOG='ci log line one
ci log line two' REPO_AUTOMATION_OUTPUT_DIR="$output_root" ../../repo-automation/bin/evidence-bundle --label=pr --pr=123
  ) > "$pr_output_log"; then
    :
  else
    test_fail "evidence-bundle optional ci log dump run succeeds"
    status=1
  fi

  pr_bundle_zip="$(grep -E '^/' "$pr_output_log" | tail -n 1 | tr -d '\r')"
  pr_bundle_dir="${pr_bundle_zip%.zip}"
  pr_summary_file="$pr_bundle_dir/summary.txt"
  pr_bundle_root="$(basename "$pr_bundle_dir")"

  if grep -Eq '^PR number: 123$' "$pr_summary_file" && grep -Eq '^Included sections: .*ci-log-dump' "$pr_summary_file" && grep -Eq '^CI log dump dir: ' "$pr_summary_file"; then
    test_pass "evidence-bundle PR mode records ci-log-dump metadata"
  else
    test_fail "evidence-bundle PR mode records ci-log-dump metadata"
    status=1
  fi

  if smoke_assert_single_path_output "$pr_output_log" && grep -q '^Saved log path: ' "$pr_bundle_dir/ci-log-dump/output.txt"; then
    test_pass "evidence-bundle PR mode saves CI log output"
  else
    test_fail "evidence-bundle PR mode saves CI log output"
    status=1
  fi

  if python3 - "$pr_bundle_zip" "$pr_bundle_root" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
bundle_root = sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    assert f'{bundle_root}/summary.txt' in names
    assert f'{bundle_root}/ci-log-dump/output.txt' in names
    assert any(name.startswith(f'{bundle_root}/ci-log-dump/') and name.endswith('.log') for name in names)
PY
  then
    test_pass "evidence-bundle archive includes CI log dump artifacts"
  else
    test_fail "evidence-bundle archive includes CI log dump artifacts"
    status=1
  fi

  return "$status"
}

# repo-automation/tests/lib/contracts/artifacts.sh EOF
