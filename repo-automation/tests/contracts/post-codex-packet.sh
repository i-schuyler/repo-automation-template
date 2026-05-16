#!/usr/bin/env bash
# repo-automation/tests/contracts/post-codex-packet.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

# shellcheck disable=SC2154
smoke_main() {
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

  trap 'test_cleanup' EXIT INT TERM

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
  mkdir -p keys || return 1
  printf 'nested ssh private key packet content\n' > keys/id_rsa || return 1
  printf 'nested ssh private key packet content\n' > keys/id_ed25519 || return 1
  mkdir -p secrets || return 1
  printf 'token packet content\n' > secrets/token.txt || return 1
  printf 'credential packet content\n' > credentials-note.txt || return 1
  python3 - <<'PY' > packet-oversized.bin
import sys
sys.stdout.write('x' * 262145)
PY

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

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_OUTPUT_DIR="$output_root" repo-automation/bin/post-codex-packet --label=review --keep-dir --max-bytes=262144 > "$output_log"
  ); then
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

  if [ "$(wc -l < "$output_log" | tr -d '[:space:]')" = "1" ] && ! grep -Eq '^(INFO|PASS):|^packet dir:|^packet zip:|^tracked unstaged files:|^staged files:|^untracked files:|^copied untracked files:|^skipped untracked files:' "$output_log" && [ -d "$packet_dir" ] && [ -f "$packet_zip" ] && [ -f "$summary_file" ] && [ -f "$index_file" ]; then
    test_pass "post-codex-packet helper creates packet artifacts"
  else
    test_fail "post-codex-packet helper creates packet artifacts"
    status=1
  fi

  if grep -Eq '^Branch: main$' "$summary_file" && grep -Eq '^HEAD: [0-9a-f]{40}$' "$summary_file" && grep -Eq '^Repo path: ' "$summary_file" && grep -Eq '^Packet path: ' "$summary_file" && grep -Eq '^Zip path: ' "$summary_file" && grep -Eq '^Tracked unstaged files: 1$' "$summary_file" && grep -Eq '^Staged files: 1$' "$summary_file" && grep -Eq '^Untracked files: 9$' "$summary_file" && grep -Eq '^Copied untracked files: 1$' "$summary_file" && grep -Eq '^Skipped untracked files: 8$' "$summary_file" && grep -Eq '^Max untracked copy bytes: 262144$' "$summary_file"; then
    test_pass "post-codex-packet summary reports packet metadata"
  else
    test_fail "post-codex-packet summary reports packet metadata"
    status=1
  fi

  if grep -Eq '^README.md$' "$packet_dir/tracked-unstaged/name-list.txt" && grep -Eq '^docs/testing.md$' "$packet_dir/staged/name-list.txt" && grep -Eq '^packet-safe-nested/deep.txt$' "$packet_dir/untracked/non-ignored.txt" && grep -Eq '^\.env[[:space:]]' "$skipped_file" && grep -Eq '^config/\.env[[:space:]]' "$skipped_file" && grep -Eq '^config/\.env\.local[[:space:]]' "$skipped_file" && grep -Eq '^keys/id_rsa[[:space:]]' "$skipped_file" && grep -Eq '^keys/id_ed25519[[:space:]]' "$skipped_file" && grep -Eq '^secrets/token.txt[[:space:]]' "$skipped_file" && grep -Eq '^credentials-note.txt[[:space:]]' "$skipped_file" && grep -Eq '^packet-oversized.bin[[:space:]]' "$skipped_file" && [ -f "$copied_file" ]; then
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
assert 'untracked/skipped.txt' in names
assert 'untracked/copied/.env' not in names
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

smoke_main "$@"
# repo-automation/tests/contracts/post-codex-packet.sh EOF
