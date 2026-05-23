# repo-automation/tests/lib/contracts/artifacts.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



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

smoke_check_post_codex_review_contract() {
  local status=0
  local review_tmp_root="$smoke_test_base/post-codex-review-tmp"
  local review_log_root="$review_tmp_root/repo-automation-template"
  local review_output_root="$smoke_test_base/post-codex-review-output"
  local review_summary_file="$smoke_test_base/post-codex-review-summary.txt"
  local review_default_file="$smoke_test_base/post-codex-review-default.txt"
  local review_quiet_file="$smoke_test_base/post-codex-review-quiet.txt"
  local review_explain_file="$smoke_test_base/post-codex-review-explain.txt"
  local review_json_file="$smoke_test_base/post-codex-review.json"
  local review_failure_log="$review_log_root/repo-doctor-20260518-120000.log"
  local review_local_config=""
  local review_packet_path=""
  local review_packet_line=""
  local review_packet_file=""

  smoke_setup_temp_repo || return 1
  mkdir -p "$review_log_root" "$review_output_root" || return 1
  review_local_config="$smoke_test_dir/.repo-automation.local.conf"
  printf '.repo-automation.local.conf\n' >> "$smoke_test_dir/.git/info/exclude" || return 1
  cat > "$review_local_config" <<'EOF'
FINAL_SUMMARY_AFTER_START_HOOK="mark"
FINAL_SUMMARY_BEFORE_END_HOOK="recap"
EOF

  if (
    cd "$smoke_test_dir" || return 1
    printf '\npost codex review change\n' >> README.md || return 1
    printf 'post codex review staged\n' > docs/post-codex-review-staged.txt || return 1
    git add docs/post-codex-review-staged.txt || return 1
    printf 'scratch\n' > post-codex-review-scratch.txt || return 1
    cat > "$review_failure_log" <<'EOF'
FAIL: docs-check - broken link in docs/INDEX.md
tail line
EOF
    TMPDIR="$review_tmp_root" REPO_AUTOMATION_OUTPUT_DIR="$review_output_root" repo-automation/bin/post-codex-review --packet > "$review_summary_file"
    TMPDIR="$review_tmp_root" REPO_AUTOMATION_OUTPUT_DIR="$review_output_root" repo-automation/bin/post-codex-review --packet > "$review_default_file"
    TMPDIR="$review_tmp_root" REPO_AUTOMATION_OUTPUT_DIR="$review_output_root" repo-automation/bin/post-codex-review --quiet --packet > "$review_quiet_file"
    TMPDIR="$review_tmp_root" REPO_AUTOMATION_OUTPUT_DIR="$review_output_root" repo-automation/bin/post-codex-review --explain --packet > "$review_explain_file"
    TMPDIR="$review_tmp_root" REPO_AUTOMATION_OUTPUT_DIR="$review_output_root" repo-automation/bin/post-codex-review --json --packet > "$review_json_file"
  ); then
    :
  else
    test_fail "post-codex-review final summary runs successfully"
    status=1
  fi

  review_packet_line="$(sed -n '10p' "$review_summary_file" 2>/dev/null || true)"
  review_packet_path="${review_packet_line#packet=}"
  review_packet_file="$review_packet_path"

  if [ "$(wc -l < "$review_summary_file" | tr -d '[:space:]')" -eq 12 ] && grep -Fxq '===== FINAL SUMMARY =====' "$review_summary_file" && [ "$(sed -n '2p' "$review_summary_file")" = 'mark' ] && grep -Eq '^branch=main$' "$review_summary_file" && grep -Eq '^status_count=3$' "$review_summary_file" && grep -Fxq 'changed=README.md' "$review_summary_file" && grep -Fxq 'staged=docs/post-codex-review-staged.txt' "$review_summary_file" && grep -Fxq 'untracked=post-codex-review-scratch.txt' "$review_summary_file" && grep -Fxq 'first_failure=docs-check' "$review_summary_file" && grep -Fxq "log=$review_failure_log" "$review_summary_file" && grep -Eq '^packet=.*/post-codex-review-.*\.zip$' "$review_summary_file" && [ "$(sed -n '11p' "$review_summary_file")" = 'recap' ] && [ -f "$review_packet_file" ] && grep -Fxq '===== END =====' "$review_summary_file"; then
    test_pass "post-codex-review final summary stays compact and packet-aware"
  else
    test_fail "post-codex-review final summary stays compact and packet-aware"
    status=1
  fi

  if [ "$(wc -l < "$review_default_file" | tr -d '[:space:]')" -eq 12 ] && grep -Fxq '===== FINAL SUMMARY =====' "$review_default_file" && [ "$(sed -n '2p' "$review_default_file")" = 'mark' ] && [ "$(sed -n '11p' "$review_default_file")" = 'recap' ] && grep -Fxq '===== END =====' "$review_default_file"; then
    test_pass "post-codex-review default prints compact final summary"
  else
    test_fail "post-codex-review default prints compact final summary"
    status=1
  fi

  if [ ! -s "$review_quiet_file" ]; then
    test_pass "post-codex-review quiet stays silent on success"
  else
    test_fail "post-codex-review quiet stays silent on success"
    status=1
  fi

  if [ "$(wc -l < "$review_explain_file" | tr -d '[:space:]')" -eq 12 ] && grep -Fxq '===== FINAL SUMMARY =====' "$review_explain_file" && [ "$(sed -n '2p' "$review_explain_file")" = 'mark' ] && [ "$(sed -n '11p' "$review_explain_file")" = 'recap' ] && grep -Fxq '===== END =====' "$review_explain_file"; then
    test_pass "post-codex-review explain ends with final summary"
  else
    test_fail "post-codex-review explain ends with final summary"
    status=1
  fi

  if python3 - "$review_json_file" "$review_failure_log" <<'PY'
import json
import pathlib
import sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
assert data["script"] == "post-codex-review"
assert data["status"] == "fail"
assert isinstance(data["changed"], list)
assert isinstance(data["staged"], list)
assert isinstance(data["untracked"], list)
assert data["first_failure"] == "docs-check"
assert data["log"] == sys.argv[2]
assert data["packet"] is not None and data["packet"].endswith(".zip")
PY
  then
    test_pass "post-codex-review json emits actionable facts"
  else
    test_fail "post-codex-review json emits actionable facts"
    status=1
  fi

  if grep -Eq '===== FINAL SUMMARY =====|WARN:|^fail:' "$review_json_file"; then
    test_fail "post-codex-review json stays compact and JSON-only"
    status=1
  else
    test_pass "post-codex-review json stays compact and JSON-only"
  fi

  rm -f "$review_summary_file" "$review_failure_log" >/dev/null 2>&1 || true
  rm -f "$review_default_file" "$review_quiet_file" "$review_explain_file" "$review_json_file" >/dev/null 2>&1 || true
  rm -f "$review_local_config" >/dev/null 2>&1 || true
  rm -rf "$review_output_root" "$review_tmp_root" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_review_pack_contract() {
  local status=0
  local output_root=""
  local codex_stub_dir=""
  local codex_called_file=""
  local codex_no_transfer_output_file=""
  local codex_no_transfer_stderr_file=""
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
  local copy_format_stderr=""
  local copy_missing_stderr=""
  local copy_empty_stderr=""
  local scp_format_stderr=""
  local scp_missing_stderr=""
  local scp_empty_stderr=""
  local codex_copy_stderr=""
  local local_config_both_stderr=""
  local review_pack_target_name="review"
  local review_pack_output_file=""
  local review_pack_stderr_file=""
  local review_pack_explain_file=""
  local review_pack_full_explain_file=""
  local review_pack_lean_path=""
  local review_pack_full_output_file=""
  local review_pack_full_path=""
  local review_pack_full_dir=""
  local review_pack_full_summary_file=""
  local review_pack_full_post_codex_output=""
  local review_pack_full_post_codex_path=""
  local review_pack_full_repo_zip_output=""
  local review_pack_full_repo_zip_path=""
  local review_pack_copy_output_file=""
  local review_pack_copy_path=""
  local review_pack_full_copy_output_file=""
  local review_pack_full_copy_path=""
  local review_pack_scp_output_file=""
  local review_pack_scp_path=""
  local review_pack_no_transfer_output_file=""
  local review_pack_no_transfer_path=""
  local review_pack_local_copy_dir=""
  local review_pack_explicit_copy_dir=""
  local review_pack_local_scp_target=""
  local review_pack_explicit_scp_target=""
  local review_pack_scp_called_file=""
  local review_pack_scp_stub_dir=""
  local review_pack_local_config=""
  local codex_output_file=""
  local codex_stderr_file=""
  local codex_prompt_file=""

  smoke_setup_temp_repo || return 1
  smoke_write_artifact_safety_fixture "$smoke_test_dir" || return 1
  output_root="$smoke_test_base/review-pack-output"
  codex_stub_dir="$smoke_test_base/review-pack-codex-stub"
  codex_called_file="$smoke_test_base/review-pack-codex-called.txt"
  codex_no_transfer_output_file="$smoke_test_base/review-pack-codex-no-transfer.out"
  codex_no_transfer_stderr_file="$smoke_test_base/review-pack-codex-no-transfer.err"
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
  copy_format_stderr="$smoke_test_base/review-pack-copy-format.stderr"
  copy_missing_stderr="$smoke_test_base/review-pack-copy-missing.stderr"
  copy_empty_stderr="$smoke_test_base/review-pack-copy-empty.stderr"
  scp_format_stderr="$smoke_test_base/review-pack-scp-format.stderr"
  scp_missing_stderr="$smoke_test_base/review-pack-scp-missing.stderr"
  scp_empty_stderr="$smoke_test_base/review-pack-scp-empty.stderr"
  codex_copy_stderr="$smoke_test_base/review-pack-codex-copy.stderr"
  local_config_both_stderr="$smoke_test_base/review-pack-local-config-both.stderr"
  review_pack_output_file="$smoke_test_base/review-pack-output.out"
  review_pack_stderr_file="$smoke_test_base/review-pack-output.err"
  review_pack_explain_file="$smoke_test_base/review-pack-explain.out"
  review_pack_full_explain_file="$smoke_test_base/review-pack-full-explain.out"
  review_pack_full_output_file="$smoke_test_base/review-pack-full.out"
  review_pack_copy_output_file="$smoke_test_base/review-pack-copy.out"
  review_pack_full_copy_output_file="$smoke_test_base/review-pack-full-copy.out"
  review_pack_scp_output_file="$smoke_test_base/review-pack-scp.out"
  review_pack_no_transfer_output_file="$smoke_test_base/review-pack-no-transfer.out"
  codex_output_file="$smoke_test_base/review-pack-codex.out"
  codex_stderr_file="$smoke_test_base/review-pack-codex.err"
  review_pack_local_copy_dir="$smoke_test_base/review-pack-local-copy/delivery"
  review_pack_explicit_copy_dir="$smoke_test_base/review-pack-explicit-copy/delivery"
  review_pack_local_scp_target="review-bundle@example.org:/path/to/review-packets/local-scp.zip"
  review_pack_explicit_scp_target="review-bundle@example.org:/path/to/review-packets/explicit-scp.zip"
  review_pack_scp_called_file="$smoke_test_base/review-pack-scp-called.txt"
  review_pack_scp_stub_dir="$smoke_test_base/review-pack-scp-stub"
  review_pack_local_config="$smoke_test_dir/.repo-automation.local.conf"

  mkdir -p "$codex_stub_dir" || return 1
  cat > "$codex_stub_dir/codex" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${SMOKE_CODEX_CALLED_FILE:-/dev/null}"
printf 'codex invoked unexpectedly\n' >&2
exit 99
EOF
  chmod +x "$codex_stub_dir/codex" || return 1

  mkdir -p "$review_pack_scp_stub_dir" || return 1
  cat > "$review_pack_scp_stub_dir/scp" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$1" >> "${SMOKE_SCP_CALLED_FILE:-/dev/null}"
printf '%s\n' "$2" >> "${SMOKE_SCP_CALLED_FILE:-/dev/null}"
exit 0
EOF
  chmod +x "$review_pack_scp_stub_dir/scp" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --help > "$help_file"
  ) && grep -Fq -- "--target=<${review_pack_target_name}|codex>" "$help_file" && grep -Fq -- '--out-dir=<path>' "$help_file" && grep -Fq -- '--label=<text>' "$help_file" && grep -Fq -- '--full' "$help_file" && grep -Fq -- '--copy-to=<dir>' "$help_file" && grep -Fq -- '--scp-to=<target>' "$help_file" && grep -Fq -- '--no-transfer' "$help_file" && grep -Fq -- '--explain' "$help_file"; then
    test_pass "review-pack help shows strict value syntax"
  else
    test_fail "review-pack help shows strict value syntax"
    status=1
  fi

  if ! grep -Eq '/tmp|/var/tmp' "$smoke_repo_root/repo-automation/docs/review-pack.md"; then
    test_pass "review-pack docs avoid private temp paths"
  else
    test_fail "review-pack docs avoid private temp paths"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --target "$review_pack_target_name" >/dev/null 2> "$target_format_stderr"
  ); then
    test_fail "review-pack rejects --target <value>"
    status=1
  elif smoke_assert_flag_error_shape "$target_format_stderr" "flag format not accepted" "--target" "use --target=<review|codex>"; then
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
  elif smoke_assert_flag_error_shape "$target_missing_stderr" "missing flag value" "--target" "use --target=<review|codex>"; then
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
  elif smoke_assert_flag_error_shape "$target_empty_stderr" "empty flag value" "--target" "use --target=<review|codex>"; then
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
  elif smoke_assert_flag_error_shape "$target_unknown_stderr" "unsupported flag value" "--target" "use --target=<review|codex>"; then
    test_pass "review-pack rejects unsupported target values"
  else
    test_fail "review-pack rejects unsupported target values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --out-dir review-pack-output --target="$review_pack_target_name" >/dev/null 2> "$out_dir_format_stderr"
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
    repo-automation/bin/review-pack --out-dir --target="$review_pack_target_name" >/dev/null 2> "$out_dir_missing_stderr"
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
    repo-automation/bin/review-pack --out-dir= --target="$review_pack_target_name" >/dev/null 2> "$out_dir_empty_stderr"
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
    repo-automation/bin/review-pack --label review --target="$review_pack_target_name" >/dev/null 2> "$label_format_stderr"
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
    repo-automation/bin/review-pack --label --target="$review_pack_target_name" >/dev/null 2> "$label_missing_stderr"
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
    repo-automation/bin/review-pack --label= --target="$review_pack_target_name" >/dev/null 2> "$label_empty_stderr"
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
    repo-automation/bin/review-pack --copy-to review-pack-output --target="$review_pack_target_name" >/dev/null 2> "$copy_format_stderr"
  ); then
    test_fail "review-pack rejects --copy-to <value>"
    status=1
  elif smoke_assert_flag_error_shape "$copy_format_stderr" "flag format not accepted" "--copy-to" "use --copy-to=<dir>"; then
    test_pass "review-pack rejects --copy-to <value>"
  else
    test_fail "review-pack rejects --copy-to <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --copy-to --target="$review_pack_target_name" >/dev/null 2> "$copy_missing_stderr"
  ); then
    test_fail "review-pack rejects missing --copy-to value"
    status=1
  elif smoke_assert_flag_error_shape "$copy_missing_stderr" "missing flag value" "--copy-to" "use --copy-to=<dir>"; then
    test_pass "review-pack rejects missing --copy-to value"
  else
    test_fail "review-pack rejects missing --copy-to value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --copy-to= --target="$review_pack_target_name" >/dev/null 2> "$copy_empty_stderr"
  ); then
    test_fail "review-pack rejects empty --copy-to value"
    status=1
  elif smoke_assert_flag_error_shape "$copy_empty_stderr" "empty flag value" "--copy-to" "use --copy-to=<dir>"; then
    test_pass "review-pack rejects empty --copy-to value"
  else
    test_fail "review-pack rejects empty --copy-to value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --scp-to review-pack-output --target="$review_pack_target_name" >/dev/null 2> "$scp_format_stderr"
  ); then
    test_fail "review-pack rejects --scp-to <value>"
    status=1
  elif smoke_assert_flag_error_shape "$scp_format_stderr" "flag format not accepted" "--scp-to" "use --scp-to=<target>"; then
    test_pass "review-pack rejects --scp-to <value>"
  else
    test_fail "review-pack rejects --scp-to <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --scp-to --target="$review_pack_target_name" >/dev/null 2> "$scp_missing_stderr"
  ); then
    test_fail "review-pack rejects missing --scp-to value"
    status=1
  elif smoke_assert_flag_error_shape "$scp_missing_stderr" "missing flag value" "--scp-to" "use --scp-to=<target>"; then
    test_pass "review-pack rejects missing --scp-to value"
  else
    test_fail "review-pack rejects missing --scp-to value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --scp-to= --target="$review_pack_target_name" >/dev/null 2> "$scp_empty_stderr"
  ); then
    test_fail "review-pack rejects empty --scp-to value"
    status=1
  elif smoke_assert_flag_error_shape "$scp_empty_stderr" "empty flag value" "--scp-to" "use --scp-to=<target>"; then
    test_pass "review-pack rejects empty --scp-to value"
  else
    test_fail "review-pack rejects empty --scp-to value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --target="$review_pack_target_name" --no-transfer --scp-to="$review_pack_explicit_scp_target" >/dev/null 2> "$copy_empty_stderr"
  ); then
    test_fail "review-pack rejects --no-transfer with scp transfer"
    status=1
  elif grep -Fxq 'fail: --no-transfer is mutually exclusive with transfer flags' "$copy_empty_stderr" && grep -Fxq 'fix: use either --no-transfer or --copy-to/--scp-to' "$copy_empty_stderr"; then
    test_pass "review-pack rejects --no-transfer with scp transfer"
  else
    test_fail "review-pack rejects --no-transfer with scp transfer"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/review-pack --target=codex --copy-to="$review_pack_explicit_copy_dir" >/dev/null 2> "$codex_copy_stderr"
  ); then
    test_fail "review-pack rejects transfer flags for codex target"
    status=1
  elif grep -Fxq 'fail: transfer flags require --target=review' "$codex_copy_stderr" && grep -Fxq 'fix: rerun with --target=review or drop transfer flags' "$codex_copy_stderr"; then
    test_pass "review-pack rejects transfer flags for codex target"
  else
    test_fail "review-pack rejects transfer flags for codex target"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target=codex --no-transfer
  ) > "$codex_no_transfer_output_file" 2> "$codex_no_transfer_stderr_file"; then
    :
  else
    test_fail "review-pack codex no-transfer run succeeds"
    status=1
  fi

  codex_no_transfer_path="$(sed -n '1p' "$codex_no_transfer_output_file" 2>/dev/null || true)"
  if smoke_assert_single_path_output "$codex_no_transfer_output_file" && [ -f "$codex_no_transfer_path" ] && [ ! -e "$smoke_test_dir/review-pack" ] && grep -Fq 'Task' "$codex_no_transfer_path"; then
    test_pass "review-pack codex target allows no-transfer and creates prompt artifact"
  else
    test_fail "review-pack codex target allows no-transfer and creates prompt artifact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    SMOKE_CODEX_CALLED_FILE="$codex_called_file" PATH="$codex_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --label=review
  ) > "$review_pack_output_file" 2> "$review_pack_stderr_file"; then
    :
  else
    test_fail "review-pack lean target run succeeds"
    status=1
  fi

  review_pack_lean_path="$(sed -n '1p' "$review_pack_output_file" 2>/dev/null || true)"
  if smoke_assert_single_path_output "$review_pack_output_file" && [ -f "$review_pack_lean_path" ] && grep -Fq '/post-codex/' "$review_pack_lean_path" && ! grep -Fq '/evidence-bundle/' "$review_pack_output_file" && [ ! -e "$smoke_test_dir/review-pack" ] && python3 - "$review_pack_lean_path" <<'PY'
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(zip_path) as archive:
    names = set(archive.namelist())
    assert 'summary.txt' in names
    assert not any('repo-zip/' in name for name in names)
    assert not any('evidence-bundle/' in name for name in names)
PY
  then
    test_pass "review-pack lean target creates a post-codex packet"
  else
    test_fail "review-pack lean target creates a post-codex packet"
    status=1
  fi

  if [ -f "$codex_called_file" ]; then
    test_fail "review-pack target does not invoke Codex"
    status=1
  else
    test_pass "review-pack target does not invoke Codex"
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --label=review --explain
  ) > "$review_pack_explain_file"; then
    :
  else
    test_fail "review-pack lean explain summary runs successfully"
    status=1
  fi

  review_pack_lean_path="$(sed -n '1p' "$review_pack_explain_file" 2>/dev/null || true)"
  if [ "$(wc -l < "$review_pack_explain_file" | tr -d '[:space:]')" -eq 10 ] && [ "$(sed -n '2p' "$review_pack_explain_file")" = '===== FINAL SUMMARY =====' ] && grep -Fxq "artifact=$review_pack_lean_path" "$review_pack_explain_file" && grep -Fxq 'packet_mode=lean' "$review_pack_explain_file" && grep -Fxq 'transfer=none' "$review_pack_explain_file" && grep -Fxq 'destination=none' "$review_pack_explain_file" && grep -Fxq "output=$review_pack_lean_path" "$review_pack_explain_file" && grep -Eq '^size_bytes=[1-9][0-9]*$' "$review_pack_explain_file" && grep -Eq '^status_count=0$' "$review_pack_explain_file" && grep -Fxq '===== END =====' "$review_pack_explain_file"; then
    test_pass "review-pack explain summary includes lean packet mode"
  else
    test_fail "review-pack explain summary includes lean packet mode"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --full --label=review
  ) > "$review_pack_full_output_file" 2> "$review_pack_stderr_file"; then
    :
  else
    test_fail "review-pack full target run succeeds"
    status=1
  fi

  review_pack_full_path="$(sed -n '1p' "$review_pack_full_output_file" 2>/dev/null || true)"
  review_pack_full_dir="${review_pack_full_path%.zip}"
  review_pack_full_summary_file="$review_pack_full_dir/summary.txt"
  review_pack_full_post_codex_output="$review_pack_full_dir/post-codex/output.txt"
  review_pack_full_repo_zip_output="$review_pack_full_dir/repo-zip/output.txt"
  review_pack_full_post_codex_path="$(sed -n '1p' "$review_pack_full_post_codex_output" 2>/dev/null | tr -d '
')"
  review_pack_full_repo_zip_path="$(sed -n '1p' "$review_pack_full_repo_zip_output" 2>/dev/null | tr -d '
')"

  if smoke_assert_single_path_output "$review_pack_full_output_file" && [ -f "$review_pack_full_path" ] && [ -d "$review_pack_full_dir" ] && [ -f "$review_pack_full_summary_file" ] && [ -f "$review_pack_full_post_codex_output" ] && [ -n "$review_pack_full_post_codex_path" ] && [ -f "$review_pack_full_post_codex_path" ] && [ -f "$review_pack_full_repo_zip_output" ] && [ -n "$review_pack_full_repo_zip_path" ] && [ -f "$review_pack_full_repo_zip_path" ] && [ ! -e "$smoke_test_dir/review-pack" ] && grep -Fq '/evidence-bundle/' "$review_pack_full_path"; then
    test_pass "review-pack full target creates a staged evidence bundle"
  else
    test_fail "review-pack full target creates a staged evidence bundle"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --full --label=review --explain
  ) > "$review_pack_full_explain_file"; then
    :
  else
    test_fail "review-pack full explain summary runs successfully"
    status=1
  fi

  review_pack_full_path="$(sed -n '1p' "$review_pack_full_explain_file" 2>/dev/null || true)"
  if [ "$(wc -l < "$review_pack_full_explain_file" | tr -d '[:space:]')" -eq 10 ] && [ "$(sed -n '2p' "$review_pack_full_explain_file")" = '===== FINAL SUMMARY =====' ] && grep -Fxq "artifact=$review_pack_full_path" "$review_pack_full_explain_file" && grep -Fxq 'packet_mode=full' "$review_pack_full_explain_file" && grep -Fxq 'transfer=none' "$review_pack_full_explain_file" && grep -Fxq 'destination=none' "$review_pack_full_explain_file" && grep -Fxq "output=$review_pack_full_path" "$review_pack_full_explain_file" && grep -Eq '^size_bytes=[1-9][0-9]*$' "$review_pack_full_explain_file" && grep -Eq '^status_count=0$' "$review_pack_full_explain_file" && grep -Fxq '===== END =====' "$review_pack_full_explain_file"; then
    test_pass "review-pack explain summary includes full packet mode"
  else
    test_fail "review-pack explain summary includes full packet mode"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --copy-to="$review_pack_explicit_copy_dir"
  ) > "$review_pack_copy_output_file" 2> "$review_pack_stderr_file"; then
    :
  else
    test_fail "review-pack lean copy transfer runs successfully"
    status=1
  fi

  review_pack_copy_path="$(sed -n '1p' "$review_pack_copy_output_file" 2>/dev/null || true)"
  if smoke_assert_single_path_output "$review_pack_copy_output_file" && [ -f "$review_pack_copy_path" ] && case "$review_pack_copy_path" in "$review_pack_explicit_copy_dir/"*) true ;; *) false ;; esac; then
    test_pass "review-pack lean copy transfer copies the packet"
  else
    test_fail "review-pack lean copy transfer copies the packet"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --full --copy-to="$review_pack_explicit_copy_dir"
  ) > "$review_pack_full_copy_output_file" 2> "$review_pack_stderr_file"; then
    :
  else
    test_fail "review-pack full copy transfer runs successfully"
    status=1
  fi

  review_pack_full_copy_path="$(sed -n '1p' "$review_pack_full_copy_output_file" 2>/dev/null || true)"
  if smoke_assert_single_path_output "$review_pack_full_copy_output_file" && [ -f "$review_pack_full_copy_path" ] && case "$review_pack_full_copy_path" in "$review_pack_explicit_copy_dir/"*) true ;; *) false ;; esac; then
    test_pass "review-pack full copy transfer copies the evidence bundle"
  else
    test_fail "review-pack full copy transfer copies the evidence bundle"
    status=1
  fi

  if [ -f "$codex_called_file" ]; then
    test_fail "review-pack target does not invoke Codex"
    status=1
  else
    test_pass "review-pack target does not invoke Codex"
  fi

  cat > "$review_pack_local_config" <<EOF
REVIEW_PACK_COPY_TO="$review_pack_local_copy_dir"
EOF

  if (
    cd "$smoke_test_dir" || return 1
    SMOKE_SCP_CALLED_FILE="$review_pack_scp_called_file" PATH="$review_pack_scp_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --label=review --scp-to="$review_pack_explicit_scp_target"
  ) > "$review_pack_scp_output_file" 2> "$review_pack_stderr_file"; then
    :
  else
    test_fail "review-pack explicit scp transfer runs successfully"
    status=1
  fi

  review_pack_scp_path="$(sed -n '1p' "$review_pack_scp_output_file" 2>/dev/null || true)"
  if smoke_assert_single_path_output "$review_pack_scp_output_file" && [ "$review_pack_scp_path" = "$review_pack_explicit_scp_target" ] && [ -f "$review_pack_scp_called_file" ] && [ -f "$(sed -n '1p' "$review_pack_scp_called_file")" ] && [ "$(sed -n '2p' "$review_pack_scp_called_file")" = "$review_pack_explicit_scp_target" ]; then
    test_pass "review-pack explicit scp transfer targets the supplied destination"
  else
    test_fail "review-pack explicit scp transfer targets the supplied destination"
    status=1
  fi

  rm -f "$review_pack_scp_called_file" >/dev/null 2>&1 || true
  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --label=review
  ) > "$review_pack_copy_output_file" 2> "$review_pack_stderr_file"; then
    :
  else
    test_fail "review-pack local copy default runs successfully"
    status=1
  fi

  review_pack_copy_path="$(sed -n '1p' "$review_pack_copy_output_file" 2>/dev/null || true)"
  if smoke_assert_single_path_output "$review_pack_copy_output_file" && [ -f "$review_pack_copy_path" ] && case "$review_pack_copy_path" in "$review_pack_local_copy_dir/"*) true ;; *) false ;; esac; then
    test_pass "review-pack local copy default copies the bundle"
  else
    test_fail "review-pack local copy default copies the bundle"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --label=review --no-transfer
  ) > "$review_pack_no_transfer_output_file" 2> "$review_pack_stderr_file"; then
    :
  else
    test_fail "review-pack no-transfer overrides local config"
    status=1
  fi

  review_pack_no_transfer_path="$(sed -n '1p' "$review_pack_no_transfer_output_file" 2>/dev/null || true)"
  if smoke_assert_single_path_output "$review_pack_no_transfer_output_file" && [ -f "$review_pack_no_transfer_path" ] && [ ! -e "$review_pack_local_copy_dir/$(basename "$review_pack_no_transfer_path")" ]; then
    test_pass "review-pack no-transfer keeps the local bundle"
  else
    test_fail "review-pack no-transfer keeps the local bundle"
    status=1
  fi

  rm -f "$review_pack_scp_called_file" >/dev/null 2>&1 || true
  if (
    cd "$smoke_test_dir" || return 1
    SMOKE_SCP_CALLED_FILE="$review_pack_scp_called_file" PATH="$review_pack_scp_stub_dir:$PATH" REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --label=review --scp-to="$review_pack_explicit_scp_target"
  ) > "$review_pack_scp_output_file" 2> "$review_pack_stderr_file"; then
    :
  else
    test_fail "review-pack explicit scp overrides local copy config"
    status=1
  fi

  review_pack_scp_path="$(sed -n '1p' "$review_pack_scp_output_file" 2>/dev/null || true)"
  if smoke_assert_single_path_output "$review_pack_scp_output_file" && [ "$review_pack_scp_path" = "$review_pack_explicit_scp_target" ] && [ -f "$review_pack_scp_called_file" ] && [ -f "$(sed -n '1p' "$review_pack_scp_called_file")" ] && [ "$(sed -n '2p' "$review_pack_scp_called_file")" = "$review_pack_explicit_scp_target" ] && [ ! -e "$review_pack_local_copy_dir/$(basename "$review_pack_scp_path")" ]; then
    test_pass "review-pack explicit scp overrides local copy config"
  else
    test_fail "review-pack explicit scp overrides local copy config"
    status=1
  fi

  rm -f "$review_pack_scp_called_file" >/dev/null 2>&1 || true
  cat > "$review_pack_local_config" <<EOF
REVIEW_PACK_COPY_TO="$review_pack_local_copy_dir"
REVIEW_PACK_SCP_TO="$review_pack_local_scp_target"
EOF
  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/review-pack --target="$review_pack_target_name" --label=review
  ) >/dev/null 2> "$local_config_both_stderr"; then
    test_fail "review-pack rejects conflicting local transfer defaults"
    status=1
  elif grep -Fxq 'fail: REVIEW_PACK_COPY_TO and REVIEW_PACK_SCP_TO are mutually exclusive' "$local_config_both_stderr" && grep -Fxq 'fix: set only one review-pack transfer default in .repo-automation.local.conf' "$local_config_both_stderr"; then
    test_pass "review-pack rejects conflicting local transfer defaults"
  else
    test_fail "review-pack rejects conflicting local transfer defaults"
    status=1
  fi

  cat > "$review_pack_local_config" <<EOF
REVIEW_PACK_COPY_TO="$review_pack_local_copy_dir"
EOF
  rm -f "$review_pack_scp_called_file" >/dev/null 2>&1 || true
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

  rm -f "$review_pack_local_config" >/dev/null 2>&1 || true

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
    repo-automation/bin/repair-prompt --target=review --source=ci >/dev/null 2> "$target_unknown_stderr"
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
  pr_ci_log_output_file="$pr_bundle_dir/ci-log-dump/output.txt"
  pr_ci_log_path=""
  pr_bundle_root="$(basename "$pr_bundle_dir")"

  if grep -Eq '^PR number: 123$' "$pr_summary_file" && grep -Eq '^Included sections: .*ci-log-dump' "$pr_summary_file" && grep -Eq '^CI log dump dir: ' "$pr_summary_file"; then
    test_pass "evidence-bundle PR mode records ci-log-dump metadata"
  else
    test_fail "evidence-bundle PR mode records ci-log-dump metadata"
    status=1
  fi

  pr_ci_log_path="$(tr -d '\r' < "$pr_ci_log_output_file")"
  if smoke_assert_single_path_output "$pr_output_log" && smoke_assert_single_path_output "$pr_ci_log_output_file" && [ -f "$pr_ci_log_path" ] && case "$pr_ci_log_path" in "$pr_bundle_dir/ci-log-dump/"*) true ;; *) false ;; esac; then
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

smoke_check_ci_failure_artifacts_contract() {
  local status=0
  local help_file="$smoke_test_base/ci-failure-artifacts-help-$$.txt"
  local unknown_stderr="$smoke_test_base/ci-failure-artifacts-unknown-$$.stderr"
  local out_dir_format_stderr="$smoke_test_base/ci-failure-artifacts-out-dir-format-$$.stderr"
  local out_dir_empty_stderr="$smoke_test_base/ci-failure-artifacts-out-dir-empty-$$.stderr"
  local run_tests_format_stderr="$smoke_test_base/ci-failure-artifacts-run-tests-format-$$.stderr"
  local run_tests_empty_stderr="$smoke_test_base/ci-failure-artifacts-run-tests-empty-$$.stderr"
  local missing_out_dir_stderr="$smoke_test_base/ci-failure-artifacts-missing-out-dir-$$.stderr"
  local default_dir="$smoke_test_base/ci-failure-artifacts-default-$$"
  local default_out="$smoke_test_base/ci-failure-artifacts-default-$$.txt"
  local quiet_dir="$smoke_test_base/ci-failure-artifacts-quiet-$$"
  local quiet_out="$smoke_test_base/ci-failure-artifacts-quiet-$$.txt"
  local quiet_err="$smoke_test_base/ci-failure-artifacts-quiet-$$.stderr"
  local json_dir="$smoke_test_base/ci-failure-artifacts-json-$$"
  local json_out="$smoke_test_base/ci-failure-artifacts-json-$$.json"
  local json_missing_dir="$smoke_test_base/ci-failure-artifacts-missing-$$"
  local json_missing_out="$smoke_test_base/ci-failure-artifacts-missing-$$.txt"
  local rich_out_dir="$smoke_test_base/ci-failure-artifacts-rich-$$"
  local rich_stdout="$smoke_test_base/ci-failure-artifacts-rich-$$.txt"
  local rich_input_dir="$smoke_test_base/ci-failure-artifacts-inputs-$$"
  local rich_run_tests="$rich_input_dir/run-tests.log"
  local rich_shellcheck="$rich_input_dir/shellcheck.log"
  local rich_portability="$rich_input_dir/check-portability.log"
  local rich_repo_doctor_log="$rich_input_dir/repo-doctor.log"
  local rich_repo_doctor_json="$rich_input_dir/repo-doctor.json"
  local rich_repo_doctor_stderr="$rich_input_dir/repo-doctor.stderr"
  local rich_failure_log="$rich_out_dir/failure-log.txt"
  local rich_failure_excerpt="$rich_out_dir/failure-excerpt.txt"
  local rich_policy_summary="$rich_out_dir/policy-summary.md"
  local rich_machine_summary="$rich_out_dir/machine-summary.json"
  local fallback_out_dir="$smoke_test_base/ci-failure-artifacts-fallback-$$"
  local fallback_stdout="$smoke_test_base/ci-failure-artifacts-fallback-$$.txt"
  local fallback_input_dir="$smoke_test_base/ci-failure-artifacts-fallback-inputs-$$"
  local fallback_run_tests="$fallback_input_dir/run-tests.log"
  local fallback_shellcheck="$fallback_input_dir/shellcheck.log"
  local fallback_failure_log="$fallback_out_dir/failure-log.txt"
  local fallback_machine_summary="$fallback_out_dir/machine-summary.json"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-failure-artifacts --help > "$help_file"
  ) && grep -Fq -- '--out-dir=<path>' "$help_file" && grep -Fq -- '--run-tests-log=<path>' "$help_file" && grep -Fq -- '--repo-doctor-stderr=<path>' "$help_file" && ! grep -Fq -- '--out-dir PATH' "$help_file" && ! grep -Fq -- '--run-tests-log PATH' "$help_file"; then
    test_pass "ci-failure-artifacts help shows strict value syntax"
  else
    test_fail "ci-failure-artifacts help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-failure-artifacts --bogus >/dev/null 2> "$unknown_stderr"
  ); then
    test_fail "ci-failure-artifacts rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_stderr" "unknown flag" "--bogus" "run repo-automation/bin/ci-failure-artifacts --help"; then
    test_pass "ci-failure-artifacts rejects unknown flags"
  else
    test_fail "ci-failure-artifacts rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-failure-artifacts --out-dir "$default_dir" >/dev/null 2> "$out_dir_format_stderr"
  ); then
    test_fail "ci-failure-artifacts rejects --out-dir <path>"
    status=1
  elif smoke_assert_flag_error_shape "$out_dir_format_stderr" "flag format not accepted" "--out-dir" "use --out-dir=<path>"; then
    test_pass "ci-failure-artifacts rejects --out-dir <path>"
  else
    test_fail "ci-failure-artifacts rejects --out-dir <path>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-failure-artifacts --out-dir= >/dev/null 2> "$out_dir_empty_stderr"
  ); then
    test_fail "ci-failure-artifacts rejects empty --out-dir"
    status=1
  elif smoke_assert_flag_error_shape "$out_dir_empty_stderr" "empty flag value" "--out-dir" "use --out-dir=<path>"; then
    test_pass "ci-failure-artifacts rejects empty --out-dir"
  else
    test_fail "ci-failure-artifacts rejects empty --out-dir"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-failure-artifacts --out-dir >/dev/null 2> "$missing_out_dir_stderr"
  ); then
    test_fail "ci-failure-artifacts rejects missing --out-dir"
    status=1
  elif smoke_assert_flag_error_shape "$missing_out_dir_stderr" "missing flag value" "--out-dir" "use --out-dir=<path>"; then
    test_pass "ci-failure-artifacts rejects missing --out-dir"
  else
    test_fail "ci-failure-artifacts rejects missing --out-dir"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-failure-artifacts --run-tests-log "$default_dir/run-tests.log" >/dev/null 2> "$run_tests_format_stderr"
  ); then
    test_fail "ci-failure-artifacts rejects --run-tests-log <path>"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_format_stderr" "flag format not accepted" "--run-tests-log" "use --run-tests-log=<path>"; then
    test_pass "ci-failure-artifacts rejects --run-tests-log <path>"
  else
    test_fail "ci-failure-artifacts rejects --run-tests-log <path>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-failure-artifacts --run-tests-log= >/dev/null 2> "$run_tests_empty_stderr"
  ); then
    test_fail "ci-failure-artifacts rejects empty --run-tests-log"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_empty_stderr" "empty flag value" "--run-tests-log" "use --run-tests-log=<path>"; then
    test_pass "ci-failure-artifacts rejects empty --run-tests-log"
  else
    test_fail "ci-failure-artifacts rejects empty --run-tests-log"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/ci-failure-artifacts --out-dir="$default_dir" > "$default_out"
  ) && smoke_assert_single_path_output "$default_out" && [ "$(cat "$default_out")" = "$default_dir" ]; then
    test_pass "ci-failure-artifacts default success prints the output directory"
  else
    test_fail "ci-failure-artifacts default success prints the output directory"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/ci-failure-artifacts --out-dir="$quiet_dir" --quiet > "$quiet_out" 2> "$quiet_err"
  ) && [ ! -s "$quiet_out" ] && [ ! -s "$quiet_err" ]; then
    test_pass "ci-failure-artifacts quiet success is silent"
  else
    test_fail "ci-failure-artifacts quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/ci-failure-artifacts --out-dir="$json_dir" --json > "$json_out"
  ) && python3 -m json.tool "$json_out" >/dev/null && smoke_json_assert "$json_out" 'data.get("script") == "ci-failure-artifacts" and data.get("overall_status") == "fail" and data.get("artifact_generation_status") == "pass" and data.get("output_dir") == "'"$json_dir"'" and isinstance(data.get("primary_failure"), dict) and isinstance(data.get("artifacts"), dict)'; then
    test_pass "ci-failure-artifacts json success is valid"
  else
    test_fail "ci-failure-artifacts json success is valid"
    status=1
  fi

  mkdir -p "$rich_input_dir" "$rich_out_dir" || return 1
  cat > "$rich_run_tests" <<'EOF'
fail: repo-automation/tests/docs-check.sh
fix: repo-automation/bin/run-tests --changed --quiet
EOF
  cat > "$rich_shellcheck" <<'EOF'
shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting.
EOF
  cat > "$rich_portability" <<'EOF'
warn: portability advisory findings
EOF
  cat > "$rich_repo_doctor_log" <<'EOF'
WARN: repo-doctor - repo health warning
EOF
  cat > "$rich_repo_doctor_json" <<'EOF'
{"script":"repo-doctor","overall_status":"warn","pass_count":4,"warn_count":2,"fail_count":1}
EOF
  cat > "$rich_repo_doctor_stderr" <<'EOF'
repo-doctor stderr line
EOF

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/ci-failure-artifacts \
      --out-dir="$rich_out_dir" \
      --run-tests-log="$rich_run_tests" \
      --shellcheck-log="$rich_shellcheck" \
      --check-portability-log="$rich_portability" \
      --repo-doctor-json="$rich_repo_doctor_json" \
      --repo-doctor-log="$rich_repo_doctor_log" \
      --repo-doctor-stderr="$rich_repo_doctor_stderr" > "$rich_stdout"
  ) && smoke_assert_single_path_output "$rich_stdout" && [ "$(cat "$rich_stdout")" = "$rich_out_dir" ] &&
    [ -f "$rich_out_dir/run-tests.log" ] &&
    [ -f "$rich_out_dir/shellcheck.log" ] &&
    [ -f "$rich_out_dir/check-portability.log" ] &&
    [ -f "$rich_out_dir/repo-doctor.log" ] &&
    [ -f "$rich_out_dir/repo-doctor.json" ] &&
    [ -f "$rich_out_dir/repo-doctor.stderr" ] &&
    cmp -s "$rich_run_tests" "$rich_failure_log" &&
    cmp -s "$rich_run_tests" "$rich_out_dir/run-tests.log" &&
    grep -Fq 'docs-check' "$rich_failure_excerpt" &&
    grep -Fq 'suggested next command: `repo-automation/tests/docs-check.sh`' "$rich_policy_summary" &&
    grep -Fq 'repo-doctor: `warn`' "$rich_policy_summary" &&
    python3 -m json.tool "$rich_machine_summary" >/dev/null &&
    smoke_json_assert "$rich_machine_summary" 'data.get("overall_status") == "fail" and data.get("artifact_generation_status") == "pass" and data.get("primary_failure", {}).get("source") == "run-tests.log" and data.get("primary_failure", {}).get("label") == "docs-check" and data.get("primary_failure", {}).get("suggested_command") == "repo-automation/tests/docs-check.sh" and data.get("artifacts", {}).get("run_tests_log") == "run-tests.log" and data.get("artifacts", {}).get("shellcheck_log") == "shellcheck.log" and data.get("artifacts", {}).get("repo_doctor_json") == "repo-doctor.json" and data.get("repo_doctor", {}).get("overall_status") == "warn" and data.get("repo_doctor", {}).get("fail_count") == 1 and data.get("repo_doctor", {}).get("warn_count") == 2 and data.get("missing_inputs") == []'; then
    test_pass "ci-failure-artifacts assembles stable artifacts and summaries"
  else
    test_fail "ci-failure-artifacts assembles stable artifacts and summaries"
    status=1
  fi

  mkdir -p "$fallback_input_dir" "$fallback_out_dir" || return 1
  : > "$fallback_run_tests"
  cat > "$fallback_shellcheck" <<'EOF'
shellcheck: repo-automation/bin/check-portability:1:1: SC2034: warning example
EOF

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/ci-failure-artifacts \
      --out-dir="$fallback_out_dir" \
      --run-tests-log="$fallback_run_tests" \
      --shellcheck-log="$fallback_shellcheck" > "$fallback_stdout"
  ) && cmp -s "$fallback_shellcheck" "$fallback_failure_log" &&
    smoke_json_assert "$fallback_out_dir/machine-summary.json" 'data.get("overall_status") == "fail" and data.get("artifact_generation_status") == "pass" and data.get("primary_failure", {}).get("source") == "shellcheck.log" and data.get("primary_failure", {}).get("label") == "shellcheck"'; then
    test_pass "ci-failure-artifacts falls back to the first non-empty evidence file"
  else
    test_fail "ci-failure-artifacts falls back to the first non-empty evidence file"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/ci-failure-artifacts \
      --out-dir="$json_missing_dir" \
      --run-tests-log="$json_missing_dir/run-tests.log" \
      --shellcheck-log="$json_missing_dir/shellcheck.log" \
      --check-portability-log="$json_missing_dir/check-portability.log" \
      --repo-doctor-json="$json_missing_dir/repo-doctor.json" \
      --repo-doctor-log="$json_missing_dir/repo-doctor.log" \
      --repo-doctor-stderr="$json_missing_dir/repo-doctor.stderr" > "$json_missing_out"
  ) && smoke_json_assert "$json_missing_dir/machine-summary.json" 'sorted(data.get("missing_inputs", [])) == ["check-portability.log", "repo-doctor.json", "repo-doctor.log", "repo-doctor.stderr", "run-tests.log", "shellcheck.log"]'; then
    test_pass "ci-failure-artifacts records missing optional inputs without failing"
  else
    test_fail "ci-failure-artifacts records missing optional inputs without failing"
    status=1
  fi

  rm -rf "$rich_input_dir" "$fallback_input_dir" "$default_dir" "$quiet_dir" "$json_dir" "$json_missing_dir" "$rich_out_dir" "$fallback_out_dir" >/dev/null 2>&1 || true
  rm -f "$help_file" "$unknown_stderr" "$out_dir_format_stderr" "$out_dir_empty_stderr" "$run_tests_format_stderr" "$run_tests_empty_stderr" "$missing_out_dir_stderr" "$default_out" "$quiet_out" "$quiet_err" "$json_out" "$json_missing_out" "$rich_stdout" "$fallback_stdout" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/artifacts.sh EOF
