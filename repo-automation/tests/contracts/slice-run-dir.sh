#!/usr/bin/env bash
# shellcheck disable=SC2154
# repo-automation/tests/contracts/slice-run-dir.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

slice_run_dir_script() {
  printf '%s/repo-automation/bin/slice-run-dir' "$smoke_repo_root"
}

slice_run_dir_run() {
  local stdout_file="$1"
  local stderr_file="$2"

  shift 2
  "$(slice_run_dir_script)" "$@" >"$stdout_file" 2>"$stderr_file"
}

slice_run_dir_write_marked_dir() {
  local run_dir="$1"
  local created_at="$2"
  local branch="$3"
  local run_id="$4"

  python3 - "$run_dir" "$created_at" "$branch" "$run_id" <<'PY'
from pathlib import Path
import os
import sys
import tempfile

run_dir = Path(sys.argv[1])
created_at = sys.argv[2]
branch = sys.argv[3]
run_id = sys.argv[4]

run_dir.mkdir(parents=True, exist_ok=True)
marker = run_dir / '.repo-automation-slice-run'
content = (
    'schema=repo-automation-slice-run/v1\n'
    f'created_at_epoch={created_at}\n'
    f'branch={branch}\n'
    f'run_id={run_id}\n'
)
with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=str(run_dir), prefix='.repo-automation-slice-run.', delete=False) as handle:
    handle.write(content)
    tmp_path = Path(handle.name)
os.replace(tmp_path, marker)
PY
}

slice_run_dir_create_stale_dir() {
  local run_dir="$1"
  local age_days="$2"
  local branch="${3:-feature/slice-run-dir}"
  local run_id="${4:-stale-run}"
  local now

  now="$(python3 - <<'PY'
import time
print(int(time.time()))
PY
)"
  slice_run_dir_write_marked_dir "$run_dir" "$((now - (age_days * 86400)))" "$branch" "$run_id"
}

slice_run_dir_make_wrong_schema_dir() {
  local run_dir="$1"

  mkdir -p "$run_dir" || return 1
  printf 'schema=wrong-schema\ncreated_at_epoch=1\nbranch=feature/wrong\nrun_id=wrong\n' >"$run_dir/.repo-automation-slice-run"
}

slice_run_dir_make_malformed_dir() {
  local run_dir="$1"

  mkdir -p "$run_dir" || return 1
  printf 'not-a-marker\n' >"$run_dir/.repo-automation-slice-run"
}

slice_run_dir_make_symlink_marker_dir() {
  local run_dir="$1"
  local target_file="$2"

  mkdir -p "$run_dir" || return 1
  ln -s "$target_file" "$run_dir/.repo-automation-slice-run"
}

slice_run_dir_make_symlink_candidate() {
  local link_path="$1"
  local target_path="$2"

  ln -s "$target_path" "$link_path"
}

slice_run_dir_main_impl() {
  local status=0
  local contract_root="$smoke_test_base/slice-run-dir"
  local help_stdout="$smoke_test_base/slice-run-dir-help.out"
  local help_stderr="$smoke_test_base/slice-run-dir-help.err"
  local create_root="$smoke_test_base/slice-run-dir-create-root"
  local quiet_root="$smoke_test_base/slice-run-dir-quiet-root"
  local invalid_branch_root="$smoke_test_base/slice-run-dir-invalid-branch"
  local inside_repo_root="$smoke_repo_root/slice-run-dir-inside-repo"
  local split_root="$smoke_test_base/slice-run-dir-split-root"
  local empty_root="$smoke_test_base/slice-run-dir-empty-root"
  local plan_root="$smoke_test_base/slice-run-dir-plan-root"
  local apply_root="$smoke_test_base/slice-run-dir-apply-root"
  local preserve_same_root="$smoke_test_base/slice-run-dir-preserve-same"
  local preserve_inside_root="$smoke_test_base/slice-run-dir-preserve-inside"
  local preserve_contains_root="$smoke_test_base/slice-run-dir-preserve-contains"
  local keep_root="$smoke_test_base/slice-run-dir-keep-root"
  local max_age_root="$smoke_test_base/slice-run-dir-max-age-root"
  local branch="feature/slice-run-dir-smoke"
  local create_json_file
  local plan_json_file
  local apply_json_file
  local preserve_json_file
  local keep_json_file
  local max_age_json_file

  mkdir -p "$contract_root"

  if slice_run_dir_run "$help_stdout" "$help_stderr" --help &&
    grep -Fq 'Usage: repo-automation/bin/slice-run-dir --create --branch=<name>' "$help_stdout" &&
    grep -Fq 'repo-automation/bin/slice-run-dir --cleanup-stale [--root=<path>] [--max-age-days=<n>] [--keep=<n>] [--preserve-path=<path>] [--apply] [--json] [--quiet] [--help]' "$help_stdout" &&
    grep -Fq -- '--branch=<name>' "$help_stdout" &&
    grep -Fq -- '--root=<path>' "$help_stdout" &&
    grep -Fq -- '--max-age-days=<n>' "$help_stdout" &&
    grep -Fq -- '--keep=<n>' "$help_stdout" &&
    grep -Fq -- '--preserve-path=<path>' "$help_stdout" &&
    [ ! -s "$help_stderr" ]; then
    test_pass "help-shows-strict-value-syntax"
  else
    test_fail "help-shows-strict-value-syntax"
    status=1
  fi

  create_json_file="$smoke_test_base/slice-run-dir-create.json"
  if slice_run_dir_run "$smoke_test_base/slice-run-dir-create.out" "$smoke_test_base/slice-run-dir-create.err" \
    --create --branch="$branch" --root="$create_root" --json; then
    cp "$smoke_test_base/slice-run-dir-create.out" "$create_json_file"
    if [ ! -s "$smoke_test_base/slice-run-dir-create.err" ] &&
      python3 - "$create_json_file" "$smoke_repo_root" "$create_root" <<'PY'
from pathlib import Path
import json
import sys

json_path = Path(sys.argv[1])
repo_root = Path(sys.argv[2]).resolve()
root = Path(sys.argv[3]).resolve()
data = json.loads(json_path.read_text(encoding='utf-8'))
run_dir = Path(data['run_dir'])
marker = Path(data['marker_path'])
if data['mode'] != 'create':
    raise SystemExit(1)
if Path(data['root']).resolve() != root:
    raise SystemExit(1)
if not run_dir.is_dir():
    raise SystemExit(1)
try:
    run_dir.relative_to(repo_root)
except ValueError:
    pass
else:
    raise SystemExit(1)
if marker != run_dir / '.repo-automation-slice-run':
    raise SystemExit(1)
lines = marker.read_text(encoding='utf-8').splitlines()
if len(lines) != 4:
    raise SystemExit(1)
if lines[0] != 'schema=repo-automation-slice-run/v1':
    raise SystemExit(1)
if not lines[1].startswith('created_at_epoch='):
    raise SystemExit(1)
if lines[2] != f'branch={data["branch"]}':
    raise SystemExit(1)
if lines[3] != f'run_id={data["run_id"]}':
    raise SystemExit(1)
raise SystemExit(0)
PY
    then
      test_pass "create-json-emits-marker-and-outside-root"
    else
      test_fail "create-json-emits-marker-and-outside-root"
      status=1
    fi
  else
    test_fail "create-json-emits-marker-and-outside-root"
    status=1
  fi

  if slice_run_dir_run "$smoke_test_base/slice-run-dir-quiet.out" "$smoke_test_base/slice-run-dir-quiet.err" \
    --create --branch="$branch" --root="$quiet_root" --quiet; then
    if [ ! -s "$smoke_test_base/slice-run-dir-quiet.out" ] && [ ! -s "$smoke_test_base/slice-run-dir-quiet.err" ]; then
      if [ "$(find "$quiet_root" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')" = "1" ]; then
        test_pass "create-quiet-is-silent"
      else
        test_fail "create-quiet-is-silent"
        status=1
      fi
    else
      test_fail "create-quiet-is-silent"
      status=1
    fi
  else
    test_fail "create-quiet-is-silent"
    status=1
  fi

  if slice_run_dir_run "$smoke_test_base/slice-run-dir-invalid-branch.out" "$smoke_test_base/slice-run-dir-invalid-branch.err" \
    --create --branch='bad branch' --root="$invalid_branch_root"; then
    test_fail "invalid-branch-fails"
    status=1
  elif grep -Fq 'invalid branch:' "$smoke_test_base/slice-run-dir-invalid-branch.err"; then
    test_pass "invalid-branch-fails"
  else
    test_fail "invalid-branch-fails"
    status=1
  fi

  if slice_run_dir_run "$smoke_test_base/slice-run-dir-inside-repo.out" "$smoke_test_base/slice-run-dir-inside-repo.err" \
    --create --branch="$branch" --root="$inside_repo_root"; then
    test_fail "root-inside-repo-fails"
    status=1
  elif grep -Fq 'must resolve outside the repo root' "$smoke_test_base/slice-run-dir-inside-repo.err"; then
    test_pass "root-inside-repo-fails"
  else
    test_fail "root-inside-repo-fails"
    status=1
  fi

  if slice_run_dir_run "$smoke_test_base/slice-run-dir-split.out" "$smoke_test_base/slice-run-dir-split.err" \
    --create --branch "$branch" --root="$split_root"; then
    test_fail "split-form-flag-fails"
    status=1
  elif grep -Fq 'flag format not accepted' "$smoke_test_base/slice-run-dir-split.err"; then
    test_pass "split-form-flag-fails"
  else
    test_fail "split-form-flag-fails"
    status=1
  fi

  if slice_run_dir_run "$smoke_test_base/slice-run-dir-empty.out" "$smoke_test_base/slice-run-dir-empty.err" \
    --create --branch= --root="$empty_root"; then
    test_fail "empty-flag-value-fails"
    status=1
  elif grep -Fq 'empty flag value' "$smoke_test_base/slice-run-dir-empty.err"; then
    test_pass "empty-flag-value-fails"
  else
    test_fail "empty-flag-value-fails"
    status=1
  fi

  mkdir -p "$plan_root" || return 1
  slice_run_dir_create_stale_dir "$plan_root/stale-marked" 9
  mkdir -p "$plan_root/unmarked"
  plan_json_file="$smoke_test_base/slice-run-dir-plan.json"
  if slice_run_dir_run "$smoke_test_base/slice-run-dir-plan.out" "$smoke_test_base/slice-run-dir-plan.err" \
    --cleanup-stale --root="$plan_root" --json; then
    cp "$smoke_test_base/slice-run-dir-plan.out" "$plan_json_file"
    if [ ! -s "$smoke_test_base/slice-run-dir-plan.err" ] &&
      python3 - "$plan_json_file" "$plan_root/stale-marked" <<'PY'
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
stale = str(Path(sys.argv[2]).resolve())
if data['mode'] != 'cleanup-stale' or data['apply'] is not False:
    raise SystemExit(1)
if data['deleted'] != 0:
    raise SystemExit(1)
if data['deletable'] != 1:
    raise SystemExit(1)
if stale not in data['selected_paths']:
    raise SystemExit(1)
raise SystemExit(0)
PY
    then
      test_pass "cleanup-plan-json-is-pure-and-plan-only"
    else
      test_fail "cleanup-plan-json-is-pure-and-plan-only"
      status=1
    fi
    if [ -d "$plan_root/stale-marked" ]; then
      test_pass "cleanup-plan-keeps-selected-dirs"
    else
      test_fail "cleanup-plan-keeps-selected-dirs"
      status=1
    fi
  else
    test_fail "cleanup-plan-json-is-pure-and-plan-only"
    test_fail "cleanup-plan-keeps-selected-dirs"
    status=1
  fi

  mkdir -p "$apply_root" || return 1
  slice_run_dir_create_stale_dir "$apply_root/stale-marked" 9
  mkdir -p "$apply_root/unmarked"
  slice_run_dir_make_wrong_schema_dir "$apply_root/wrong-schema"
  slice_run_dir_make_malformed_dir "$apply_root/malformed"
  slice_run_dir_make_symlink_marker_dir "$apply_root/symlink-marker" "$smoke_test_base/slice-run-dir-symlink-target.txt"
  printf 'target\n' >"$smoke_test_base/slice-run-dir-symlink-target.txt"
  mkdir -p "$smoke_test_base/slice-run-dir-symlink-target-dir"
  slice_run_dir_make_symlink_candidate "$apply_root/symlink-candidate" "$smoke_test_base/slice-run-dir-symlink-target-dir"
  apply_json_file="$smoke_test_base/slice-run-dir-apply.json"
  if slice_run_dir_run "$smoke_test_base/slice-run-dir-apply.out" "$smoke_test_base/slice-run-dir-apply.err" \
    --cleanup-stale --root="$apply_root" --apply --json; then
    cp "$smoke_test_base/slice-run-dir-apply.out" "$apply_json_file"
    if [ ! -s "$smoke_test_base/slice-run-dir-apply.err" ] &&
      python3 - "$apply_json_file" "$apply_root" <<'PY'
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
root = Path(sys.argv[2])
if data['apply'] is not True or data['deleted'] != 1:
    raise SystemExit(1)
if not data['deleted_paths'] or str(root / 'stale-marked') not in data['deleted_paths']:
    raise SystemExit(1)
raise SystemExit(0)
PY
    then
      if [ ! -d "$apply_root/stale-marked" ] &&
        [ -d "$apply_root/unmarked" ] &&
        [ -d "$apply_root/wrong-schema" ] &&
        [ -d "$apply_root/malformed" ] &&
        [ -L "$apply_root/symlink-candidate" ] &&
        [ -L "$apply_root/symlink-marker/.repo-automation-slice-run" ]; then
        test_pass "cleanup-apply-deletes-only-selected-marked-dirs"
        test_pass "unmarked-and-invalid-dirs-survive-cleanup"
        test_pass "symlink-candidates-and-markers-are-ignored"
      else
        test_fail "cleanup-apply-deletes-only-selected-marked-dirs"
        test_fail "unmarked-and-invalid-dirs-survive-cleanup"
        test_fail "symlink-candidates-and-markers-are-ignored"
        status=1
      fi
    else
      test_fail "cleanup-apply-deletes-only-selected-marked-dirs"
      status=1
    fi
  else
    test_fail "cleanup-apply-deletes-only-selected-marked-dirs"
    status=1
  fi

  mkdir -p "$preserve_same_root"
  slice_run_dir_create_stale_dir "$preserve_same_root/preserved" 9
  preserve_json_file="$smoke_test_base/slice-run-dir-preserve-same.json"
  if slice_run_dir_run "$smoke_test_base/slice-run-dir-preserve-same.out" "$smoke_test_base/slice-run-dir-preserve-same.err" \
    --cleanup-stale --root="$preserve_same_root" --preserve-path="$preserve_same_root/preserved" --apply --json; then
    cp "$smoke_test_base/slice-run-dir-preserve-same.out" "$preserve_json_file"
    if [ ! -s "$smoke_test_base/slice-run-dir-preserve-same.err" ] && [ -d "$preserve_same_root/preserved" ]; then
      test_pass "preserve-path-same-path"
    else
      test_fail "preserve-path-same-path"
      status=1
    fi
  else
    test_fail "preserve-path-same-path"
    status=1
  fi

  mkdir -p "$preserve_inside_root"
  slice_run_dir_create_stale_dir "$preserve_inside_root/preserved" 9
  mkdir -p "$preserve_inside_root/preserved/keep-me"
  if slice_run_dir_run "$smoke_test_base/slice-run-dir-preserve-inside.out" "$smoke_test_base/slice-run-dir-preserve-inside.err" \
    --cleanup-stale --root="$preserve_inside_root" --preserve-path="$preserve_inside_root/preserved/keep-me" --apply; then
    if [ -d "$preserve_inside_root/preserved" ]; then
      test_pass "preserve-path-candidate-contains-preserve-path"
    else
      test_fail "preserve-path-candidate-contains-preserve-path"
      status=1
    fi
  else
    test_fail "preserve-path-candidate-contains-preserve-path"
    status=1
  fi

  mkdir -p "$preserve_contains_root/child"
  slice_run_dir_create_stale_dir "$preserve_contains_root/child/stale-marked" 9
  if slice_run_dir_run "$smoke_test_base/slice-run-dir-preserve-contains.out" "$smoke_test_base/slice-run-dir-preserve-contains.err" \
    --cleanup-stale --root="$preserve_contains_root" --preserve-path="$preserve_contains_root" --apply; then
    if [ -d "$preserve_contains_root/child/stale-marked" ]; then
      test_pass "preserve-path-contains-candidate"
    else
      test_fail "preserve-path-contains-candidate"
      status=1
    fi
  else
    test_fail "preserve-path-contains-candidate"
    status=1
  fi

  mkdir -p "$keep_root"
  slice_run_dir_write_marked_dir "$keep_root/newest" "$(python3 - <<'PY'
import time
print(int(time.time()))
PY
)" feature/keep newest-1
  slice_run_dir_write_marked_dir "$keep_root/middle" "$(python3 - <<'PY'
import time
print(int(time.time()) - 1)
PY
)" feature/keep newest-2
  slice_run_dir_write_marked_dir "$keep_root/oldest" "$(python3 - <<'PY'
import time
print(int(time.time()) - 2)
PY
)" feature/keep newest-3
  python3 - "$keep_root" <<'PY'
from pathlib import Path
import time
import sys

root = Path(sys.argv[1])
epoch = int(time.time())
for name, delta in [('newest', 0), ('middle', 1), ('oldest', 2)]:
    marker = root / name / '.repo-automation-slice-run'
    lines = [
        'schema=repo-automation-slice-run/v1',
        f'created_at_epoch={epoch - delta}',
        'branch=feature/keep',
        f'run_id={name}',
    ]
    marker.write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY
  keep_json_file="$smoke_test_base/slice-run-dir-keep.json"
  if slice_run_dir_run "$smoke_test_base/slice-run-dir-keep.out" "$smoke_test_base/slice-run-dir-keep.err" \
    --cleanup-stale --root="$keep_root" --keep=2 --max-age-days=3650 --apply --json; then
    cp "$smoke_test_base/slice-run-dir-keep.out" "$keep_json_file"
    if [ ! -s "$smoke_test_base/slice-run-dir-keep.err" ] && [ ! -d "$keep_root/oldest" ] && [ -d "$keep_root/newest" ] && [ -d "$keep_root/middle" ]; then
      test_pass "keep-newest-marked-dirs"
    else
      test_fail "keep-newest-marked-dirs"
      status=1
    fi
  else
    test_fail "keep-newest-marked-dirs"
    status=1
  fi

  mkdir -p "$max_age_root"
  python3 - "$max_age_root" <<'PY'
from pathlib import Path
import time
import sys

root = Path(sys.argv[1])
epoch = int(time.time())
for name, delta in [('old', 3), ('new', 0)]:
    run_dir = root / name
    run_dir.mkdir(parents=True, exist_ok=True)
    marker = run_dir / '.repo-automation-slice-run'
    marker.write_text(
        '\n'.join([
            'schema=repo-automation-slice-run/v1',
            f'created_at_epoch={epoch - (delta * 86400)}',
            'branch=feature/max-age',
            f'run_id={name}',
        ]) + '\n',
        encoding='utf-8',
    )
PY
  max_age_json_file="$smoke_test_base/slice-run-dir-max-age.json"
  if slice_run_dir_run "$smoke_test_base/slice-run-dir-max-age.out" "$smoke_test_base/slice-run-dir-max-age.err" \
    --cleanup-stale --root="$max_age_root" --max-age-days=1 --apply --json; then
    cp "$smoke_test_base/slice-run-dir-max-age.out" "$max_age_json_file"
    if [ ! -s "$smoke_test_base/slice-run-dir-max-age.err" ] && [ ! -d "$max_age_root/old" ] && [ -d "$max_age_root/new" ]; then
      test_pass "max-age-selects-older-dirs"
    else
      test_fail "max-age-selects-older-dirs"
      status=1
    fi
  else
    test_fail "max-age-selects-older-dirs"
    status=1
  fi

  return "$status"
}

smoke_main_impl() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:slice-run-dir-contract" slice_run_dir_main_impl || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
