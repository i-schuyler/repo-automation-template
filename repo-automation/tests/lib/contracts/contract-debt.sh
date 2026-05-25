# repo-automation/tests/lib/contracts/contract-debt.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.


smoke_check_contract_debt_report_contract() {
  local status=0
  smoke_setup_temp_repo || return 1
  local report_tmpdir="$smoke_test_base/contract-debt-report-$$"
  local report_dir="$report_tmpdir/repo-automation-template/contract-debt-report"
  local report_markdown="$report_dir/contract-debt-report.md"
  local report_json="$report_dir/contract-debt-report.json"
  local help_out="$smoke_test_base/contract-debt-help-$$.txt"
  local help_err="$smoke_test_base/contract-debt-help-$$.stderr"
  local unknown_err="$smoke_test_base/contract-debt-unknown-$$.stderr"
  local outdir_space_err="$smoke_test_base/contract-debt-outdir-space-$$.stderr"
  local outdir_empty_err="$smoke_test_base/contract-debt-outdir-empty-$$.stderr"
  local default_out="$smoke_test_base/contract-debt-default-$$.txt"
  local default_err="$smoke_test_base/contract-debt-default-$$.stderr"
  local quiet_out="$smoke_test_base/contract-debt-quiet-$$.txt"
  local quiet_err="$smoke_test_base/contract-debt-quiet-$$.stderr"
  local explain_out="$smoke_test_base/contract-debt-explain-$$.txt"
  local explain_err="$smoke_test_base/contract-debt-explain-$$.stderr"
  local json_out="$smoke_test_base/contract-debt-json-$$.json"
  local json_err="$smoke_test_base/contract-debt-json-$$.stderr"
  local seeded_large_file="$smoke_test_dir/repo-automation/bin/contract-debt-large-candidate"
  local large_json="$smoke_test_base/contract-debt-large-$$.json"
  local large_err="$smoke_test_base/contract-debt-large-$$.stderr"
  local shared_coverage_json="$smoke_test_base/contract-debt-shared-coverage-$$.json"
  local shared_coverage_err="$smoke_test_base/contract-debt-shared-coverage-$$.stderr"
  local missing_shared_json="$smoke_test_base/contract-debt-missing-shared-$$.json"
  local missing_shared_err="$smoke_test_base/contract-debt-missing-shared-$$.stderr"
  local missing_doc_json="$smoke_test_base/contract-debt-missing-doc-$$.json"
  local missing_doc_err="$smoke_test_base/contract-debt-missing-doc-$$.stderr"
  local missing_contract_json="$smoke_test_base/contract-debt-missing-contract-$$.json"
  local missing_contract_err="$smoke_test_base/contract-debt-missing-contract-$$.stderr"
  local gap_json="$smoke_test_base/contract-debt-gap-$$.json"
  local gap_err="$smoke_test_base/contract-debt-gap-$$.stderr"
  local metadata_guard_err="$smoke_test_base/contract-debt-metadata-guard-$$.stderr"
  local json_gap_file="$smoke_test_dir/repo-automation/tests/contracts/ci-failure-artifacts.sh"
  local quiet_gap_file="$smoke_test_dir/repo-automation/tests/contracts/repo-doctor.sh"
  local invalid_meta_err="$smoke_test_base/contract-debt-invalid-meta-$$.stderr"
  local invalid_meta_json="$smoke_test_base/contract-debt-invalid-meta-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/contract-debt-report --help >"$help_out" 2>"$help_err"
  ) && grep -Fq 'Usage: repo-automation/bin/contract-debt-report [--help] [--out-dir=<path>] [--quiet] [--explain] [--json]' "$help_out" &&
    grep -Fq 'Generate an advisory maintainability and contract debt report.' "$help_out" &&
    grep -Fq 'Debt findings warn but do not fail the command.' "$help_out" &&
    ! grep -Fq 'fail:' "$help_err"; then
    test_pass "contract-debt-report help shows usage and summary"
  else
    test_fail "contract-debt-report help shows usage and summary"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/contract-debt-report --bogus > /dev/null 2>"$unknown_err"
  ); then
    test_fail "contract-debt-report unknown flag is rejected"
    status=1
  elif grep -Fxq 'fail: unknown flag' "$unknown_err" &&
    grep -Fxq 'flag: --bogus' "$unknown_err" &&
    grep -Fxq 'fix: run repo-automation/bin/contract-debt-report --help' "$unknown_err"; then
    test_pass "contract-debt-report unknown flag is rejected"
  else
    test_fail "contract-debt-report unknown flag is rejected"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/contract-debt-report --out-dir "$report_tmpdir/space" > /dev/null 2>"$outdir_space_err"
  ); then
    test_fail "contract-debt-report rejects spaced out-dir syntax"
    status=1
  elif grep -Fxq 'fail: flag format not accepted' "$outdir_space_err" &&
    grep -Fxq 'flag: --out-dir' "$outdir_space_err" &&
    grep -Fxq 'fix: use --out-dir=<path>' "$outdir_space_err"; then
    test_pass "contract-debt-report rejects spaced out-dir syntax"
  else
    test_fail "contract-debt-report rejects spaced out-dir syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/contract-debt-report --out-dir= > /dev/null 2>"$outdir_empty_err"
  ); then
    test_fail "contract-debt-report rejects empty out-dir syntax"
    status=1
  elif grep -Fxq 'fail: empty flag value' "$outdir_empty_err" &&
    grep -Fxq 'flag: --out-dir' "$outdir_empty_err" &&
    grep -Fxq 'fix: use --out-dir=<path>' "$outdir_empty_err"; then
    test_pass "contract-debt-report rejects empty out-dir syntax"
  else
    test_fail "contract-debt-report rejects empty out-dir syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report >"$default_out" 2>"$default_err"
  ) && [ "$(cat "$default_out")" = "$report_markdown" ] && [ ! -s "$default_err" ] && [ -f "$report_markdown" ] && [ -f "$report_json" ]; then
    test_pass "contract-debt-report default output prints the markdown path"
  else
    test_fail "contract-debt-report default output prints the markdown path"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --quiet >"$quiet_out" 2>"$quiet_err"
  ) && [ ! -s "$quiet_out" ] && [ ! -s "$quiet_err" ]; then
    test_pass "contract-debt-report quiet output is silent"
  else
    test_fail "contract-debt-report quiet output is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --explain >"$explain_out" 2>"$explain_err"
  ) && [ ! -s "$explain_err" ] &&
    grep -Eq '^status: (pass|warn)$' "$explain_out" &&
    grep -Eq '^counts: warn=[0-9]+ fail=[0-9]+ total=[0-9]+ included=[0-9]+ omitted=[0-9]+$' "$explain_out" &&
    grep -Eq "^report_markdown: $report_markdown$" "$explain_out" &&
    grep -Eq "^report_json: $report_json$" "$explain_out" &&
    grep -Eq '^top_categories: ' "$explain_out"; then
    test_pass "contract-debt-report explain output includes counts and paths"
  else
    test_fail "contract-debt-report explain output includes counts and paths"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$json_out" 2>"$json_err"
  ) && [ ! -s "$json_err" ] && python3 -m json.tool "$json_out" >/dev/null &&
    smoke_json_assert "$json_out" 'data.get("script") == "contract-debt-report" and data.get("overall_status") in ("pass", "warn") and data.get("report_markdown", "").endswith("contract-debt-report.md") and data.get("report_json", "").endswith("contract-debt-report.json") and "script_large_lines" in data.get("thresholds", {}) and "max_findings_per_category" in data.get("thresholds", {})'; then
    cmp -s "$json_out" "$report_json" &&
      [ -f "$report_markdown" ] &&
      test_pass "contract-debt-report json output is valid and matches the report file"
  else
    test_fail "contract-debt-report json output is valid and matches the report file"
    status=1
  fi

  python3 - "$seeded_large_file" <<'PY' || return 1
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text("\n".join(f"line {i}" for i in range(1, 505)) + "\n", encoding="utf-8")
PY
  git -C "$smoke_test_dir" add repo-automation/bin/contract-debt-large-candidate || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$large_json" 2>"$large_err"
  ) && [ ! -s "$large_err" ] && python3 -m json.tool "$large_json" >/dev/null &&
    smoke_json_assert "$large_json" 'data.get("overall_status") == "warn" and any(f.get("severity") == "warn" and f.get("category") == "file-size" and f.get("path") == "repo-automation/bin/contract-debt-large-candidate" for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns on large files"
  else
    test_fail "contract-debt-report warns on large files"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    python3 - "$smoke_test_dir/repo-automation/helper-metadata.json" <<'PY' >/dev/null 2>"$metadata_guard_err"
from pathlib import Path
import json
import sys

helpers = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("helpers")
if not isinstance(helpers, list):
    raise SystemExit(1)

def supports_quiet(name):
    for helper in helpers:
      if isinstance(helper, dict) and helper.get("name") == name:
        if "supports_quiet" not in helper:
          raise SystemExit(1)
        return helper["supports_quiet"]
    raise SystemExit(1)

if supports_quiet("check-tooling") is not True:
    raise SystemExit(1)
if supports_quiet("failure-log") is not False:
    raise SystemExit(1)
PY
  ); then
    test_pass "contract-debt-report helper metadata keeps named quiet support truth"
  else
    test_fail "contract-debt-report helper metadata keeps named quiet support truth"
    status=1
  fi

  cat > "$smoke_test_dir/repo-automation/tests/lib/contracts/contract-debt-shared-coverage.sh" <<'EOF'
# shellcheck shell=bash

smoke_check_contract_debt_shared_coverage_contract() {
  # shared contract coverage markers
  # --json python3 -m json.tool
  # --quiet quiet success
  # unknown flag fail: fix:
  return 0
}
EOF

  cat > "$smoke_test_dir/repo-automation/tests/contracts/contract-debt-shared-coverage.sh" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/contract-debt-shared-coverage.sh"

smoke_main_impl() {
  local status=0

  smoke_run_named_check "smoke:contract-debt-shared-coverage-contract" smoke_check_contract_debt_shared_coverage_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
EOF

  cat > "$smoke_test_dir/repo-automation/bin/contract-debt-shared-coverage" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

echo contract-debt-shared-coverage
EOF

  cat > "$smoke_test_dir/repo-automation/docs/contract-debt-shared-coverage.md" <<'EOF'
# Contract Debt Shared Coverage

`repo-automation/bin/contract-debt-shared-coverage` is a focused helper used by the contract-debt-report smoke checks.

```sh
repo-automation/bin/contract-debt-shared-coverage
```
EOF

  cat > "$smoke_test_dir/repo-automation/tests/lib/contracts/contract-debt-missing-shared.sh" <<'EOF'
# shellcheck shell=bash

smoke_check_contract_debt_missing_shared_support() {
  return 0
}
EOF

  cat > "$smoke_test_dir/repo-automation/tests/contracts/aa-contract-debt-missing-shared.sh" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/contract-debt-missing-shared.sh"

smoke_main_impl() {
  local status=0

  # shared wrapper coverage markers
  # --json python3 -m json.tool
  # --quiet quiet success
  # unknown flag fail: fix:
  smoke_run_named_check "smoke:contract-debt-missing-shared-contract" smoke_check_contract_debt_missing_shared_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
EOF

  cat > "$smoke_test_dir/repo-automation/bin/aa-contract-debt-missing-shared" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

echo contract-debt-missing-shared
EOF

  cat > "$smoke_test_dir/repo-automation/docs/aa-contract-debt-missing-shared.md" <<'EOF'
# Contract Debt Missing Shared

`repo-automation/bin/aa-contract-debt-missing-shared` is a focused helper used by the contract-debt-report smoke checks.

```sh
repo-automation/bin/aa-contract-debt-missing-shared
```
EOF

  cat > "$smoke_test_dir/repo-automation/bin/contract-debt-gap-doc" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

echo contract-debt-gap-doc
EOF

  cat > "$smoke_test_dir/repo-automation/bin/contract-debt-gap-contract" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

echo contract-debt-gap-contract
EOF

  cat > "$smoke_test_dir/repo-automation/docs/contract-debt-gap-contract.md" <<'EOF'
# Contract Debt Gap Contract

`repo-automation/bin/contract-debt-gap-contract` is a focused helper used by the contract-debt-report smoke checks.

```sh
repo-automation/bin/contract-debt-gap-contract
```
EOF

  python3 - "$smoke_test_dir/repo-automation/helper-metadata.json" "$smoke_test_dir/repo-automation/manifest.json" <<'PY' || return 1
from pathlib import Path
import json
import sys

metadata_path = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])

metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
helpers = metadata.setdefault("helpers", [])

helper_entries = [
    {
        "name": "contract-debt-shared-coverage",
        "path": "repo-automation/bin/contract-debt-shared-coverage",
        "doc_path": "repo-automation/docs/contract-debt-shared-coverage.md",
        "contract_test_path": "repo-automation/tests/contracts/contract-debt-shared-coverage.sh",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    },
    {
        "name": "contract-debt-aa-missing-shared",
        "path": "repo-automation/bin/aa-contract-debt-missing-shared",
        "doc_path": "repo-automation/docs/aa-contract-debt-missing-shared.md",
        "contract_test_path": "repo-automation/tests/contracts/aa-contract-debt-missing-shared.sh",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    },
    {
        "name": "contract-debt-gap-doc",
        "path": "repo-automation/bin/contract-debt-gap-doc",
        "contract_test_path": "repo-automation/tests/contracts/contract-debt-shared-coverage.sh",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    },
    {
        "name": "contract-debt-gap-contract",
        "path": "repo-automation/bin/contract-debt-gap-contract",
        "doc_path": "repo-automation/docs/contract-debt-gap-contract.md",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    },
]

known_helpers = {entry.get("name") for entry in helpers if isinstance(entry, dict)}
for entry in helper_entries:
    if entry["name"] not in known_helpers:
        helpers.append(entry)

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
managed_files = manifest.setdefault("managed_files", [])
known_paths = {entry.get("path") for entry in managed_files if isinstance(entry, dict)}

for path in [
    "repo-automation/bin/contract-debt-shared-coverage",
    "repo-automation/docs/contract-debt-shared-coverage.md",
    "repo-automation/tests/contracts/contract-debt-shared-coverage.sh",
    "repo-automation/bin/contract-debt-missing-shared",
    "repo-automation/bin/aa-contract-debt-missing-shared",
    "repo-automation/docs/aa-contract-debt-missing-shared.md",
    "repo-automation/tests/contracts/aa-contract-debt-missing-shared.sh",
    "repo-automation/bin/contract-debt-gap-doc",
    "repo-automation/bin/contract-debt-gap-contract",
    "repo-automation/docs/contract-debt-gap-contract.md",
]:
    if path not in known_paths:
        managed_files.append({"path": path})

metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$shared_coverage_json" 2>"$shared_coverage_err"
  ) && [ ! -s "$shared_coverage_err" ] && python3 -m json.tool "$shared_coverage_json" >/dev/null &&
    smoke_json_assert "$shared_coverage_json" 'not any(f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "contract-debt-shared-coverage" for f in data.get("findings", []))'; then
    test_pass "contract-debt-report uses shared contract bodies for coverage"
  else
    test_fail "contract-debt-report uses shared contract bodies for coverage"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$missing_shared_json" 2>"$missing_shared_err"
  ) && [ ! -s "$missing_shared_err" ] && python3 -m json.tool "$missing_shared_json" >/dev/null &&
    smoke_json_assert "$missing_shared_json" 'not any(f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "check-tooling" and "missing shared contract function" in f.get("message", "") for f in data.get("findings", [])) and sum(1 for f in data.get("findings", []) if f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "contract-debt-aa-missing-shared" and "missing shared contract function" in f.get("message", "")) == 1'; then
    test_pass "contract-debt-report ignores wrapper-local smoke checks and warns on missing shared functions"
  else
    test_fail "contract-debt-report ignores wrapper-local smoke checks and warns on missing shared functions"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$missing_doc_json" 2>"$missing_doc_err"
  ) && [ ! -s "$missing_doc_err" ] && python3 -m json.tool "$missing_doc_json" >/dev/null &&
    smoke_json_assert "$missing_doc_json" 'any(f.get("severity") == "warn" and f.get("category") == "metadata-gap" and f.get("helper") == "contract-debt-gap-doc" and "doc_path metadata is missing or empty" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when doc_path metadata is missing"
  else
    test_fail "contract-debt-report warns when doc_path metadata is missing"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$missing_contract_json" 2>"$missing_contract_err"
  ) && [ ! -s "$missing_contract_err" ] && python3 -m json.tool "$missing_contract_json" >/dev/null &&
    smoke_json_assert "$missing_contract_json" 'any(f.get("severity") == "warn" and f.get("category") == "metadata-gap" and f.get("helper") == "contract-debt-gap-contract" and "contract_test_path metadata is missing or empty" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when contract_test_path metadata is missing"
  else
    test_fail "contract-debt-report warns when contract_test_path metadata is missing"
    status=1
  fi

  python3 - "$smoke_test_dir/repo-automation/helper-metadata.json" <<'PY' || return 1
from pathlib import Path
import json
import sys
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
helpers = data.setdefault("helpers", [])
helpers.append(
    {
        "name": "contract-debt-gap",
        "path": "repo-automation/bin/contract-debt-gap",
        "doc_path": "repo-automation/docs/contract-debt-gap.md",
        "contract_test_path": "repo-automation/tests/contracts/contract-debt-gap.sh",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    }
)
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$gap_json" 2>"$gap_err"
  ) && [ ! -s "$gap_err" ] && python3 -m json.tool "$gap_json" >/dev/null &&
    smoke_json_assert "$gap_json" 'data.get("overall_status") == "warn" and any(f.get("severity") == "warn" and f.get("category") == "metadata-gap" and f.get("path") in ("repo-automation/docs/contract-debt-gap.md", "repo-automation/tests/contracts/contract-debt-gap.sh", "repo-automation/bin/contract-debt-gap") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns on helper metadata and file gaps"
  else
    test_fail "contract-debt-report warns on helper metadata and file gaps"
    status=1
  fi

  cat > "$json_gap_file" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

# smoke:ci-failure-artifacts contract coverage stub
echo contract-debt-report
EOF
  chmod +x "$json_gap_file" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$gap_json" 2>"$gap_err"
  ) && [ ! -s "$gap_err" ] && python3 -m json.tool "$gap_json" >/dev/null &&
    smoke_json_assert "$gap_json" 'any(f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "ci-failure-artifacts" and "supports_json" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when supports_json coverage is missing"
  else
    test_fail "contract-debt-report warns when supports_json coverage is missing"
    status=1
  fi

  cat > "$quiet_gap_file" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

# smoke:repo-doctor contract coverage stub
echo contract-debt-report
EOF
  chmod +x "$quiet_gap_file" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$large_json" 2>"$large_err"
  ) && [ ! -s "$large_err" ] && python3 -m json.tool "$large_json" >/dev/null &&
    smoke_json_assert "$large_json" 'any(f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "ci-failure-artifacts" and "quiet" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when supports_quiet coverage is missing"
  else
    test_fail "contract-debt-report warns when supports_quiet coverage is missing"
    status=1
  fi

  cat > "$smoke_test_dir/repo-automation/helper-metadata.json" <<'EOF'
not-json
EOF

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$invalid_meta_json" 2>"$invalid_meta_err"
  ); then
    test_fail "contract-debt-report fails on invalid helper metadata"
    status=1
  elif python3 -m json.tool "$invalid_meta_json" >/dev/null &&
    smoke_json_assert "$invalid_meta_json" 'data.get("overall_status") == "fail" and any(f.get("severity") == "fail" for f in data.get("findings", []))'; then
    test_pass "contract-debt-report fails on invalid helper metadata"
  else
    test_fail "contract-debt-report fails on invalid helper metadata"
    status=1
  fi

  rm -f "$help_out" "$help_err" "$unknown_err" "$outdir_space_err" "$outdir_empty_err" "$default_out" "$default_err" "$quiet_out" "$quiet_err" "$explain_out" "$explain_err" "$json_out" "$json_err" "$large_json" "$large_err" "$shared_coverage_json" "$shared_coverage_err" "$missing_shared_json" "$missing_shared_err" "$missing_doc_json" "$missing_doc_err" "$missing_contract_json" "$missing_contract_err" "$gap_json" "$gap_err" "$metadata_guard_err" "$invalid_meta_json" "$invalid_meta_err" >/dev/null 2>&1 || true
  rm -f "$seeded_large_file" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/contract-debt.sh EOF
