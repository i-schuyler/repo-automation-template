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
{"type":"session_meta","timestamp":"2026-06-02T00:00:00Z","payload":{"id":"sess-123","source":"cli","originator":"operator","git":{"branch":"feature/test","commit_hash":"abc123","repository_url":"git@example/repo.git"}}}
{"type":"turn_context","timestamp":"2026-06-02T00:00:01Z","payload":{"model":"gpt-test","collaboration_mode":{"settings":{"reasoning_effort":"high"}}}}
{"type":"event_msg","timestamp":"2026-06-02T00:00:02Z","payload":{"type":"token_count","info":{"model_context_window":1000,"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":50,"reasoning_output_tokens":30,"total_tokens":900},"last_token_usage":{"input_tokens":12,"cached_input_tokens":2,"output_tokens":6,"reasoning_output_tokens":3,"total_tokens":150}},"rate_limits":{"primary":{"used_percent":85,"window_minutes":300},"secondary":{"used_percent":93,"window_minutes":10080}}}}
EOF
}

codex_status_make_overflow_fixture() {
  local path="$1"
  cat > "$path" <<'EOF'
{"type":"session_meta","timestamp":"2026-06-02T00:00:00Z","payload":{"session_id":"sess-overflow","source":"cli"}}
{"type":"turn_context","timestamp":"2026-06-02T00:00:01Z","payload":{"model_name":"gpt-test"}}
{"type":"event_msg","timestamp":"2026-06-02T00:00:02Z","payload":{"type":"token_count","info":{"model_context_window":1000,"total_token_usage":{"total_tokens":1500},"last_token_usage":{"total_tokens":1200}},"rate_limits":{"primary":{"used_percent":85,"window_minutes":300},"secondary":{"used_percent":93,"window_minutes":10080}}}}
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
  local overflow_file="$sess_dir/overflow.jsonl"
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
assert data["git"]["branch"] == "feature/test"
assert data["git"]["commit"] == "abc123"
assert data["git"]["repository_url"] == "git@example/repo.git"
assert data["model"]["reasoning"] == "high"
assert data["tokens"]["total"] == 150
assert data["tokens"]["current_total"] == 150
assert data["tokens"]["cumulative_total"] == 900
assert data["tokens"]["current"]["total"] == 150
assert data["tokens"]["cumulative"]["total"] == 900
assert data["context"]["remaining"] == 850
assert round(data["context"]["used_percent"], 1) == 15.0
assert round(data["context"]["remaining_percent"], 1) == 85.0
assert data["context"]["remaining_summary"] == "85% remaining"
assert data["limits"]["five_hour"]["remaining_percent"] == 15
assert data["limits"]["weekly"]["remaining_percent"] == 7
assert data["limits"]["five_hour"]["used_percent"] == 85
assert data["limits"]["weekly"]["used_percent"] == 93
assert data["limits"]["five_hour"]["window_minutes"] == 300
assert data["limits"]["weekly"]["window_minutes"] == 10080
assert data["limits"]["five_hour"]["state"] == "warn"
assert data["limits"]["weekly"]["state"] == "block"
assert data["resume"]["resume_commands"][0] == "codex resume --include-non-interactive sess-123"
assert data["resume"]["resume_commands"][1] == 'codex exec resume sess-123 "<PROMPT>"'
PY
  then :; else test_fail "latest/json"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$latest_file" --pretty >"$out" 2>"$err" &&
     grep -Fq 'session: sess-123' "$out" &&
     grep -Fq 'model: gpt-test/high' "$out" &&
     grep -Fq 'tokens: current_total=150 cumulative_total=900' "$out" &&
     grep -Fq 'context: 85% remaining' "$out" &&
     grep -Fq 'five_hour_remaining=15%' "$out" &&
     grep -Fq 'weekly_remaining=7%' "$out" &&
     grep -Fq '5h: warn weekly: block' "$out"
  then :; else test_fail "pretty"; status=1; fi

  local uuid_file="$sess_dir/123e4567-e89b-12d3-a456-426614174000.jsonl"
  cat > "$uuid_file" <<'EOF'
{"type":"session_meta","timestamp":"2026-06-02T00:00:00Z","payload":{"source":"cli"}}
{"type":"event_msg","timestamp":"2026-06-02T00:00:02Z","payload":{"type":"token_count","info":{"model_context_window":1000,"total_token_usage":{"total_tokens":10},"rate_limits":{"primary":{"used_percent":1},"secondary":{"used_percent":2}}}}}
EOF
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$uuid_file" >"$out" 2>"$err" &&
     python3 - "$out" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
assert data["session"]["session_id"] == "123e4567-e89b-12d3-a456-426614174000"
PY
  then :; else test_fail "filename uuid"; status=1; fi

  codex_status_make_overflow_fixture "$overflow_file"
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$overflow_file" >"$out" 2>"$err" &&
     python3 - "$out" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
assert data["session"]["session_id"] == "sess-overflow"
assert data["context"]["remaining"] is None
assert data["context"]["used_percent"] is None
assert data["context"]["remaining_percent"] is None
assert data["context"]["remaining_summary"] == "unknown"
assert any("current token total exceeds model context window" in warning for warning in data["warnings"])
assert data["tokens"]["cumulative_total"] == 1500
PY
  then :; else test_fail "overflow"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$overflow_file" --pretty >"$out" 2>"$err" &&
     grep -Fq 'model: gpt-test/unknown' "$out" &&
     grep -Fq 'context: unknown' "$out" &&
     ! grep -Eiq 'context: -[0-9]' "$out" &&
     ! grep -Fq 'None' "$out"
  then :; else test_fail "overflow pretty"; status=1; fi

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
