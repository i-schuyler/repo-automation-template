# repo-automation/tests/lib/contracts/shellcheck.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_shellcheck_ci_parity_contract() {
  local status=0
  local shellcheck_help="$smoke_test_base/shellcheck-ci-parity-help-$$.txt"
  local shellcheck_unknown_stderr="$smoke_test_base/shellcheck-ci-parity-unknown.stderr"
  local shellcheck_paths="$smoke_test_base/shellcheck-ci-parity-paths-$$.txt"
  local shellcheck_paths_check="$smoke_test_base/shellcheck-ci-parity-paths-check-$$.stderr"
  local shellcheck_paths_status=0
  local shellcheck_workflow="$smoke_test_base/shellcheck-ci-parity-workflow-$$.txt"
  local shellcheck_temp_disk_path="$smoke_test_dir/repo-automation/lib/temp-disk.sh"
  local shellcheck_temp_disk_backup="$smoke_test_base/shellcheck-ci-parity-temp-disk-backup-$$.sh"
  local shellcheck_missing_temp_disk_out="$smoke_test_base/shellcheck-ci-parity-missing-temp-disk-$$.txt"
  local shellcheck_missing_temp_disk_err="$smoke_test_base/shellcheck-ci-parity-missing-temp-disk-$$.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/shellcheck-ci-parity --help > "$shellcheck_help"
  ) && grep -Fq -- 'Usage: repo-automation/bin/shellcheck-ci-parity [--help]' "$shellcheck_help" && grep -Fq -- 'Run ShellCheck against the metadata-driven CI file set with the CI parity exclusion.' "$shellcheck_help" && grep -Fq -- 'Use --print-paths to show the exact file set.' "$shellcheck_help"; then
    test_pass "shellcheck-ci-parity help works before shellcheck availability"
  else
    test_fail "shellcheck-ci-parity help works before shellcheck availability"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/shellcheck-ci-parity --whatever >/dev/null 2> "$shellcheck_unknown_stderr"
  ); then
    test_fail "shellcheck-ci-parity rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$shellcheck_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/shellcheck-ci-parity --help"; then
    test_pass "shellcheck-ci-parity rejects unknown flags"
  else
    test_fail "shellcheck-ci-parity rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    mv "$shellcheck_temp_disk_path" "$shellcheck_temp_disk_backup" || return 1
    repo-automation/bin/shellcheck-ci-parity --print-paths > "$shellcheck_missing_temp_disk_out" 2> "$shellcheck_missing_temp_disk_err"
    rc=$?
    mv "$shellcheck_temp_disk_backup" "$shellcheck_temp_disk_path" || return 1
    exit "$rc"
  ); then
    test_fail "shellcheck-ci-parity requires active checkout temp-disk library"
    status=1
  elif [ ! -s "$shellcheck_missing_temp_disk_out" ] &&
    grep -Fxq 'fail: missing shellcheck path: repo-automation/lib/temp-disk.sh' "$shellcheck_missing_temp_disk_err"; then
    test_pass "shellcheck-ci-parity requires active checkout temp-disk library"
  else
    test_fail "shellcheck-ci-parity requires active checkout temp-disk library"
    status=1
    mv "$shellcheck_temp_disk_backup" "$shellcheck_temp_disk_path" >/dev/null 2>&1 || true
  fi

  if (
    cd "$smoke_test_dir/repo-automation/tests" || return 1
    ../bin/shellcheck-ci-parity --print-paths > "$shellcheck_paths"
  ); then
    python3 - "$smoke_test_dir/repo-automation/helper-metadata.json" "$shellcheck_paths" <<'PY' >/dev/null 2> "$shellcheck_paths_check" || shellcheck_paths_status=1
import json
import sys
from pathlib import Path

metadata_path = Path(sys.argv[1])
paths_path = Path(sys.argv[2])
repo_root = metadata_path.parent.parent

try:
    helper_metadata = json.loads(metadata_path.read_text())
except Exception as exc:
    print(f"fail: unable to parse helper metadata: {metadata_path}", file=sys.stderr)
    print(f"detail: {exc}", file=sys.stderr)
    raise SystemExit(1)

helpers = helper_metadata.get("helpers")
if not isinstance(helpers, list):
    print(f"fail: helper metadata missing helpers array: {metadata_path}", file=sys.stderr)
    raise SystemExit(1)

expected = []
seen = set()


def add(path: Path) -> None:
    rel_path = path.relative_to(repo_root).as_posix()
    if rel_path in seen:
        print(f"fail: duplicate shellcheck path: {rel_path}", file=sys.stderr)
        raise SystemExit(1)
    if not path.exists():
        print(f"fail: missing shellcheck path: {rel_path}", file=sys.stderr)
        raise SystemExit(1)
    if not path.is_file():
        print(f"fail: expected file path: {rel_path}", file=sys.stderr)
        raise SystemExit(1)
    seen.add(rel_path)
    expected.append(rel_path)


for helper in helpers:
    if not isinstance(helper, dict):
        continue
    helper_path = helper.get("path")
    if isinstance(helper_path, str) and helper_path.startswith("repo-automation/bin/"):
        add(repo_root / helper_path)

for path in sorted((repo_root / "repo-automation" / "lib").glob("*.sh")):
    add(path)

for pattern in (
    "repo-automation/tests/lib/*.sh",
    "repo-automation/tests/lib/contracts/*.sh",
    "repo-automation/tests/contracts/*.sh",
):
    matches = sorted(repo_root.glob(pattern))
    if not matches:
        print(f"fail: no shellcheck paths matched {pattern}", file=sys.stderr)
        raise SystemExit(1)
    for path in matches:
        add(path)

for relative_path in (
    "repo-automation/tests/docs-check.sh",
    "repo-automation/tests/smoke.sh",
    "repo-automation/tests/version-consistency.sh",
):
    add(repo_root / relative_path)

actual = paths_path.read_text().splitlines()
if actual != sorted(expected):
    print("fail: shellcheck-ci-parity --print-paths output mismatch", file=sys.stderr)
    print("expected:", file=sys.stderr)
    for path in sorted(expected):
        print(path, file=sys.stderr)
    print("actual:", file=sys.stderr)
    for path in actual:
        print(path, file=sys.stderr)
    raise SystemExit(1)

if len(actual) != len(set(actual)):
    print("fail: shellcheck-ci-parity --print-paths contains duplicate lines", file=sys.stderr)
    raise SystemExit(1)

if "repo-automation/bin/check-tooling" not in actual:
    print("fail: shellcheck-ci-parity --print-paths is missing repo-automation/bin/check-tooling", file=sys.stderr)
    raise SystemExit(1)

if "repo-automation/bin/shellcheck-ci-parity" not in actual:
    print("fail: shellcheck-ci-parity --print-paths is missing repo-automation/bin/shellcheck-ci-parity", file=sys.stderr)
    raise SystemExit(1)

if "repo-automation/lib/common.sh" not in actual:
    print("fail: shellcheck-ci-parity --print-paths is missing repo-automation/lib/common.sh", file=sys.stderr)
    raise SystemExit(1)

if "repo-automation/lib/temp-disk.sh" not in actual:
    print("fail: shellcheck-ci-parity --print-paths is missing repo-automation/lib/temp-disk.sh", file=sys.stderr)
    raise SystemExit(1)
PY
    if [ "$shellcheck_paths_status" -eq 0 ]; then
      test_pass "shellcheck-ci-parity prints the metadata-driven file set"
    else
      test_fail "shellcheck-ci-parity prints the metadata-driven file set"
      status=1
    fi
  else
    test_fail "shellcheck-ci-parity prints the metadata-driven file set"
    status=1
  fi

  if grep -Fq -- 'mapfile -t shellcheck_paths < <(repo-automation/bin/shellcheck-ci-parity --print-paths)' "$smoke_repo_root/.github/workflows/ci.yml" && \
    ! grep -Fq -- 'bash -n repo-automation/bin/' "$smoke_repo_root/.github/workflows/ci.yml" && \
    ! grep -Fq -- 'shellcheck -e SC2317 repo-automation/bin/' "$smoke_repo_root/.github/workflows/ci.yml"; then
    test_pass "ci workflow uses shellcheck-ci-parity --print-paths"
  else
    test_fail "ci workflow uses shellcheck-ci-parity --print-paths"
    status=1
  fi

  rm -f "$shellcheck_help" >/dev/null 2>&1 || true
  rm -f "$shellcheck_paths" "$shellcheck_paths_check" "$shellcheck_workflow" "$shellcheck_missing_temp_disk_out" "$shellcheck_missing_temp_disk_err" "$shellcheck_temp_disk_backup" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/shellcheck.sh EOF
