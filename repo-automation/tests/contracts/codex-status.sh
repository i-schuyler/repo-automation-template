#!/usr/bin/env bash
# repo-automation/tests/contracts/codex-status.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are initialized by
# smoke-common before the focused contract body runs.

codex_status_make_fixture() {
  local path="$1"
  cat > "$path" <<'EOF'
{"type":"session_meta","timestamp":"2026-06-02T00:00:00Z","payload":{"session_id":"sess-123","source":"cli","originator":"operator","branch":"feature/test","commit":"abc123","repository_url":"git@example/repo.git"}}
{"type":"turn_context","timestamp":"2026-06-02T00:00:01Z","payload":{"model_name":"gpt-test","reasoning":"high","model_context_window":1000}}
{"type":"event_msg","timestamp":"2026-06-02T00:00:02Z","payload":{"type":"token_count","usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":50,"reasoning_output_tokens":30,"total_tokens":900,"five_hour_remaining_percent":15,"weekly_remaining_percent":7}}}
EOF
}

# shellcheck disable=SC2154
codex_status_main() {
  local status=0
  smoke_setup_temp_repo || return 1
  cd "$smoke_test_dir" || return 1
  local contract_root="$smoke_test_base/codex-status-contract"
  local codex_home="$contract_root/home"
  local sess_dir="$codex_home/sessions"
  local latest_file="$sess_dir/latest.jsonl"
  local older_file="$sess_dir/older.jsonl"
  local out="$contract_root/out"
  local err="$contract_root/err"
  mkdir -p "$sess_dir" "$contract_root" || return 1
  codex_status_make_fixture "$older_file"
  sleep 1
  codex_status_make_fixture "$latest_file"

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --latest >"$out" 2>"$err" &&
     python3 - "$out" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
assert data["ok"] is True
assert data["session"]["session_id"] == "sess-123"
assert data["context"]["remaining"] == 100
assert data["limits"]["five_hour"]["remaining_percent"] == 15
assert data["limits"]["weekly"]["remaining_percent"] == 7
assert data["limits"]["five_hour"]["state"] == "warn"
assert data["limits"]["weekly"]["state"] == "block"
PY
  then :; else test_fail "latest/json"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$latest_file" --pretty >"$out" 2>"$err" &&
     grep -Fq 'session: sess-123' "$out" &&
     grep -Fq 'model: gpt-test/high' "$out" &&
     grep -Fq 'five_hour_remaining=15%' "$out" &&
     grep -Fq 'weekly_remaining=7%' "$out" &&
     grep -Fq '5h: warn weekly: block' "$out"
  then :; else test_fail "pretty"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$latest_file" --check-limits >/dev/null 2>"$err"; then
    test_fail "check-limits exit"; status=1
  elif [ "$?" -eq 2 ]; then :; else test_fail "check-limits exit"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --human >/dev/null 2>"$err" && false; then :; else grep -Fq 'unsupported flag' "$err" || { test_fail "human unsupported"; status=1; }; fi
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --quiet >/dev/null 2>"$err" && false; then :; else grep -Fq 'unsupported flag' "$err" || { test_fail "quiet unsupported"; status=1; }; fi

  if ! PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --session-file="$contract_root/missing.jsonl" >/dev/null 2>"$err"; then
    grep -Fq 'missing or unreadable session file' "$err" || { test_fail "missing session"; status=1; }
  else
    test_fail "missing session"; status=1
  fi

  rm -f "$out" "$err" >/dev/null 2>&1 || true
  return "$status"
}

smoke_run_focused_contract_wrapper codex_status_main "$@"
