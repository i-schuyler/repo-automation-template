# repo-automation/tests/lib/contracts/portability.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base and smoke_test_dir are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_portability_make_path_fixture() {
  local fixture_dir="$1"

  mkdir -p "$fixture_dir" || return 1
  ln -sf "$(command -v bash)" "$fixture_dir/bash" || return 1
  ln -sf "$(command -v dirname)" "$fixture_dir/dirname" || return 1
}

smoke_check_portability_clear_advisories() {
  python3 - "$smoke_test_dir" <<'PY' || return 1
from pathlib import Path
import sys

root = Path(sys.argv[1])
replacements = {
    root / "repo-automation" / "bin" / "repo-doctor": [
        ("-printf '%P\\n'", "-print"),
    ],
    root / "repo-automation" / "bin" / "post-codex-packet": [
        ("size=\"$(stat -c '%s' \"$path\" 2>/dev/null || printf '0')\"", "size=0"),
    ],
    root / "repo-automation" / "bin" / "repo-zip": [
        ("stat -c", "candidate_timestamp=0"),
    ],
    root / "repo-automation" / "bin" / "evidence-bundle": [
        ("stat -c", "candidate_mtime=0"),
    ],
    root / "repo-automation" / "bin" / "status-packet": [
        ("candidate_mtime=\"$(stat -c '%Y' \"$candidate\" 2>/dev/null || printf '0')\"", "candidate_mtime=0"),
    ],
    root / "repo-automation" / "bin" / "post-codex-review": [
        ("printf '%s\\t%s\\n' \"$(stat -c '%Y' \"$candidate\" 2>/dev/null || printf '0')\" \"$candidate\"", "printf '0\\t%s\\n' \"$candidate\""),
        ("candidate_timestamp=\"$(stat -c '%Y' \"$candidate\" 2>/dev/null || printf '0')\"", "candidate_timestamp=0"),
    ],
    root / "repo-automation" / "bin" / "failure-log": [
        ("candidate_mtime=\"$(stat -c '%Y' \"$candidate\" 2>/dev/null || printf '0')\"", "candidate_mtime=0"),
    ],
    root / "repo-automation" / "tests" / "docs-check.sh": [
        ("/tmp", "PRIVATE_TMP"),
        ("/var/tmp", "PRIVATE_VAR_TMP"),
    ],
    root / "repo-automation" / "tests" / "contracts" / "repo-flow.sh": [
        ("/tmp/example", "PRIVATE_TMP/example"),
    ],
    root / "repo-automation" / "tests" / "lib" / "contracts" / "artifacts.sh": [
        ("/tmp", "PRIVATE_TMP"),
        ("/var/tmp", "PRIVATE_VAR_TMP"),
    ],
    root / "repo-automation" / "tests" / "lib" / "contracts" / "repo-health.sh": [
        ("/tmp", "PRIVATE_TMP"),
        ("/var/tmp", "PRIVATE_VAR_TMP"),
        ("grep -P", "grep -E"),
    ],
    root / "repo-automation" / "tests" / "lib" / "contracts" / "portability.sh": [
        ("stat -c", "stat -f"),
    ],
}

for path, edits in replacements.items():
    text = path.read_text(encoding="utf-8")
    for old, new in edits:
        text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")

safe_stubs = {
    root / "repo-automation" / "bin" / "failure-log": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "bin" / "post-codex-packet": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "bin" / "post-codex-review": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "bin" / "repo-doctor": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "bin" / "status-packet": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "tests" / "contracts" / "repo-flow.sh": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "tests" / "docs-check.sh": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "tests" / "lib" / "contracts" / "artifacts.sh": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "tests" / "lib" / "contracts" / "portability.sh": "#!/usr/bin/env bash\nset -u\n:\n",
    root / "repo-automation" / "tests" / "lib" / "contracts" / "repo-health.sh": "#!/usr/bin/env bash\nset -u\n:\n",
}

for path, content in safe_stubs.items():
    path.write_text(content, encoding="utf-8")
PY
}

smoke_check_portability_contract() {
  local status=0
  local help_out="$smoke_test_base/check-portability-help-$$.txt"
  local help_err="$smoke_test_base/check-portability-help-$$.stderr"
  local unknown_err="$smoke_test_base/check-portability-unknown-$$.stderr"
  local targets_out="$smoke_test_base/check-portability-targets-$$.txt"
  local targets_err="$smoke_test_base/check-portability-targets-$$.stderr"
  local advisory_out="$smoke_test_base/check-portability-advisory-$$.txt"
  local advisory_err="$smoke_test_base/check-portability-advisory-$$.stderr"
  local quiet_out="$smoke_test_base/check-portability-quiet-$$.txt"
  local quiet_err="$smoke_test_base/check-portability-quiet-$$.stderr"
  local json_out="$smoke_test_base/check-portability-json-$$.json"
  local json_err="$smoke_test_base/check-portability-json-$$.stderr"
  local clean_json_out="$smoke_test_base/check-portability-clean-json-$$.json"
  local clean_json_err="$smoke_test_base/check-portability-clean-json-$$.stderr"
  local allowed_out="$smoke_test_base/check-portability-allowed-$$.txt"
  local allowed_err="$smoke_test_base/check-portability-allowed-$$.stderr"
  local temp_out="$smoke_test_base/check-portability-temp-$$.txt"
  local temp_err="$smoke_test_base/check-portability-temp-$$.stderr"
  local portable_out="$smoke_test_base/check-portability-portable-$$.txt"
  local portable_err="$smoke_test_base/check-portability-portable-$$.stderr"
  local python_out="$smoke_test_base/check-portability-python-$$.txt"
  local python_err="$smoke_test_base/check-portability-python-$$.stderr"
  local workflow_path="$smoke_test_dir/.github/workflows/ci.yml"
  local path_fixture="$smoke_test_base/check-portability-path-fixture-$$"
  smoke_check_portability_make_path_fixture "$path_fixture" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$path_fixture" repo-automation/bin/check-portability --help >"$help_out" 2>"$help_err"
  ) && grep -Fqx 'Usage: repo-automation/bin/check-portability [--help] [--quiet] [--explain] [--json] [--print-targets]' "$help_out" &&
    grep -Fq -- '--print-targets' "$help_out" &&
    ! grep -Fq -- '--print-targets=' "$help_out" &&
    [ ! -s "$help_err" ]; then
    test_pass "check-portability help works before shellcheck availability"
  else
    test_fail "check-portability help works before shellcheck availability"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability --bogus >"$help_out" 2>"$unknown_err"
  ); then
    test_fail "check-portability rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_err" "unknown flag" "--bogus" "run repo-automation/bin/check-portability --help"; then
    test_pass "check-portability rejects unknown flags"
  else
    test_fail "check-portability rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir/repo-automation/tests" || return 1
    ../bin/check-portability --print-targets >"$targets_out"
  ); then
    if python3 - "$targets_out" <<'PY' >/dev/null 2>"$targets_err"
import sys
from pathlib import Path

targets = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
if targets != sorted(targets):
    raise SystemExit(1)
if len(targets) != len(set(targets)):
    raise SystemExit(1)
required = {
    "repo-automation/bin/check-portability",
    ".github/workflows/ci.yml",
}
if not required.issubset(set(targets)):
    raise SystemExit(1)
PY
    then
    test_pass "check-portability prints the metadata-driven file set"
    else
      test_fail "check-portability prints the metadata-driven file set"
      status=1
    fi
  else
    test_fail "check-portability prints the metadata-driven file set"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$advisory_out" 2>"$advisory_err"
  ) && grep -Fq 'warn: portability advisory findings' "$advisory_out" &&
    [ -s "$advisory_out" ] &&
    [ ! -s "$advisory_err" ]; then
    test_pass "check-portability advisory findings exit 0"
  else
    test_fail "check-portability advisory findings exit 0"
    status=1
  fi

  smoke_check_portability_clear_advisories || return 1

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: echo ready
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability --quiet >"$quiet_out" 2>"$quiet_err"
  ) && [ ! -s "$quiet_out" ] && [ ! -s "$quiet_err" ]; then
    test_pass "check-portability quiet success is silent"
  else
    test_fail "check-portability quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability --json >"$json_out" 2>"$json_err"
  ) && [ ! -s "$json_err" ] && python3 -m json.tool "$json_out" >/dev/null &&
    smoke_json_assert "$json_out" 'data.get("script") == "check-portability" and data.get("status") == "pass" and data.get("target_count") > 0 and data.get("fail_count") == 0 and data.get("warn_count") == 0 and isinstance(data.get("targets"), list) and isinstance(data.get("findings"), list) and isinstance(data.get("target_sources"), dict)'; then
    test_pass "check-portability json is valid"
  else
    test_fail "check-portability json is valid"
    status=1
  fi

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: python3 script.py
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$allowed_out" 2>"$allowed_err"
  ) && grep -Fqx 'pass' "$allowed_out" && [ ! -s "$allowed_err" ]; then
    test_pass "check-portability allows python3 command tokens"
  else
    test_fail "check-portability allows python3 command tokens"
    status=1
  fi

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: /tmp/cache
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$temp_out" 2>"$temp_err"
  ) && grep -Fq 'warn:' "$temp_out" && grep -Fq 'portability-temp-path' "$temp_out" &&
    grep -Fq "\${TMPDIR:-\$HOME/.cache}" "$temp_out" && [ ! -s "$temp_err" ]; then
    test_pass "check-portability warns on tmp-path portability drift"
  else
    test_fail "check-portability warns on tmp-path portability drift"
    status=1
  fi

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: grep -P '^x$' /dev/null
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$portable_out" 2>"$portable_err"
  ) && grep -Fq 'warn:' "$portable_out" && grep -Fq 'portability-grep-p' "$portable_out" && [ ! -s "$portable_err" ]; then
    test_pass "check-portability warns on GNU/BSD-sensitive drift"
  else
    test_fail "check-portability warns on GNU/BSD-sensitive drift"
    status=1
  fi

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: __PYTHON_CMD__ - <<'PY'
          print('bad')
        PY
EOF

  cmd_bin="py"
  cmd_bin="${cmd_bin}thon"
  cmd_line="      - run: ${cmd_bin} - <<'PY'"
  cmd_line="${cmd_line#__PYTHON_CMD__}"
  sed -i "s|^      - run: __PYTHON_CMD__ - <<'PY'|$cmd_line|" "$workflow_path"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$python_out" 2>"$python_err"
  ); then
    test_fail "check-portability rejects executable python command tokens"
    status=1
  elif grep -Fq 'fail: portability drift' "$python_out" || grep -Fq 'fail: portability drift' "$python_err"; then
    test_pass "check-portability rejects executable python command tokens"
  else
    test_fail "check-portability rejects executable python command tokens"
    status=1
  fi

  if grep -Fq "repo-automation/bin/check-portability 2>&1 | tee \"\$check_portability_log\"" "$smoke_repo_root/.github/workflows/ci.yml" &&
    grep -Fq "repo-automation/bin/repo-doctor --quick --no-run-tests --json --json-level=warn --log-file=\"\$RUNNER_TEMP/repo-doctor.log\"" "$smoke_repo_root/.github/workflows/ci.yml" &&
    grep -Fq "repo-automation/bin/ci-failure-artifacts --out-dir=\"\$RUNNER_TEMP/ci-failure-artifacts\"" "$smoke_repo_root/.github/workflows/ci.yml" &&
    grep -Fq "\${{ runner.temp }}/ci-failure-artifacts/**" "$smoke_repo_root/.github/workflows/ci.yml"; then
    test_pass "ci workflow captures portability and failure artifacts"
  else
    test_fail "ci workflow captures portability and failure artifacts"
    status=1
  fi

  rm -f "$help_out" "$help_err" "$unknown_err" "$targets_out" "$targets_err" "$advisory_out" "$advisory_err" "$quiet_out" "$quiet_err" "$json_out" "$json_err" "$clean_json_out" "$clean_json_err" "$allowed_out" "$allowed_err" "$temp_out" "$temp_err" "$portable_out" "$portable_err" "$python_out" "$python_err" >/dev/null 2>&1 || true
  return "$status"
}
