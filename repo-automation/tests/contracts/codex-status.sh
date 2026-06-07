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
  local session_id="$2"
  local branch="$3"
  local commit="$4"
  local model_name="$5"
  local reasoning="$6"
  local current_total="$7"
  local cumulative_total="$8"
  local context_window="$9"
  local primary_used="${10}"
  local primary_window="${11}"
  local primary_resets="${12}"
  local secondary_used="${13}"
  local secondary_window="${14}"
  local secondary_resets="${15}"
  : "$primary_window" "$secondary_window"

  cat > "$path" <<EOF
{"type":"session_meta","timestamp":"2026-06-02T00:00:00Z","payload":{"session_id":"$session_id","source":"cli","originator":"operator","git":{"branch":"$branch","commit_hash":"$commit","repository_url":"git@example/repo.git"}}}
{"type":"turn_context","timestamp":"2026-06-02T00:00:01Z","payload":{"model":"$model_name","collaboration_mode":{"settings":{"reasoning_effort":"$reasoning"}}}}
{"type":"event_msg","timestamp":"2026-06-02T00:00:02Z","payload":{"type":"token_count","info":{"model_context_window":$context_window,"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":50,"reasoning_output_tokens":30,"total_tokens":$cumulative_total},"last_token_usage":{"input_tokens":12,"cached_input_tokens":2,"output_tokens":6,"reasoning_output_tokens":3,"total_tokens":$current_total}},"rate_limits":{"limit_id":"paid","plan_type":"plus","rate_limit_reached_type":"none","primary":{"used_percent":$primary_used,"window_minutes":$primary_window,"resets_at":$primary_resets},"secondary":{"used_percent":$secondary_used,"window_minutes":$secondary_window,"resets_at":$secondary_resets}}}}
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
  local out="$contract_root/out"
  local err="$contract_root/err"
  mkdir -p "$sess_dir" "$contract_root" || return 1

  codex_status_make_fixture "$sess_dir/sess-119.jsonl" "sess-119" "feature/119" "c119" "gpt-test" "high" 151 901 1000 81 300 1716500000 92 10080 1717100000
  sleep 1
  codex_status_make_fixture "$sess_dir/sess-120.jsonl" "sess-120" "feature/120" "c120" "gpt-test" "high" 152 902 1000 82 300 1716500001 91 10080 1717100001
  sleep 1
  codex_status_make_fixture "$sess_dir/sess-121.jsonl" "sess-121" "feature/121" "c121" "gpt-test" "high" 153 903 1000 83 300 1716500002 90 10080 1717100002
  sleep 1
  codex_status_make_fixture "$sess_dir/sess-122.jsonl" "sess-122" "feature/122" "c122" "gpt-test" "high" 154 904 1000 84 300 1716500003 89 10080 1717100003
  sleep 1
  codex_status_make_fixture "$sess_dir/sess-123.jsonl" "sess-123" "feature/codex-status-recent" "abc123" "gpt-5.4-mini" "medium" 150 900 1000 85 300 1716521460 93 10080 1717121460
  sleep 1

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --latest >"$out" 2>"$err" &&
     python3 - "$out" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
assert data["ok"] is True
assert data["session"]["session_id"] == "sess-123"
assert data["git"]["branch"] == "feature/codex-status-recent"
assert data["git"]["commit"] == "abc123"
assert data["git"]["repository_url"] == "git@example/repo.git"
assert data["model"]["reasoning"] == "medium"
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

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --latest --pretty >"$out" 2>"$err" &&
     grep -Fq 'codex-status' "$out" &&
     grep -Fq 'selected: latest' "$out" &&
     grep -Fq 'session_id: sess-123' "$out" &&
     grep -Fq 'updated:' "$out" &&
     grep -Fq 'source: cli / operator' "$out" &&
     grep -Fq 'model: gpt-5.4-mini / medium' "$out" &&
     grep -Fq 'context: 85% remaining' "$out" &&
     grep -Fq '5h: 15% left, resets ' "$out" &&
     grep -Fq 'week: 7% left, resets ' "$out" &&
     grep -Fq 'resume:' "$out" &&
     grep -Fq 'codex resume --include-non-interactive sess-123' "$out" &&
     ! grep -Fq 'session:' "$out" &&
     ! grep -Fq 'current_total=' "$out" &&
     ! grep -Fq 'cumulative_total=' "$out" &&
     ! grep -Fq '5h: ok weekly: ok' "$out"
  then :; else test_fail "pretty"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --latest --pretty --verbose >"$out" 2>"$err" &&
     grep -Fq 'tokens:' "$out" &&
     grep -Fq 'input: 12' "$out" &&
     grep -Fq 'cached_input: 2' "$out" &&
     grep -Fq 'output: 6' "$out" &&
     grep -Fq 'reasoning_output: 3' "$out" &&
     grep -Fq 'current_total: 150' "$out" &&
     grep -Fq 'cumulative_total: 900' "$out"
  then :; else test_fail "pretty verbose"; status=1; fi

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

  codex_status_make_overflow_fixture "$sess_dir/overflow.jsonl"
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$sess_dir/overflow.jsonl" >"$out" 2>"$err" &&
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

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$sess_dir/overflow.jsonl" --pretty >"$out" 2>"$err" &&
     grep -Fq 'model: gpt-test / unknown' "$out" &&
     grep -Fq 'context: unknown' "$out" &&
     ! grep -Eiq 'context: -[0-9]' "$out" &&
     ! grep -Fq 'None' "$out"
  then :; else test_fail "overflow pretty"; status=1; fi

  local recent_codex_home="$contract_root/recent-home"
  local recent_sess_dir="$recent_codex_home/sessions"
  mkdir -p "$recent_sess_dir" || return 1
  codex_status_make_fixture "$recent_sess_dir/sess-119.jsonl" "sess-119" "feature/119" "c119" "gpt-test" "high" 151 901 1000 81 300 1716500000 92 10080 1717100000
  sleep 1
  codex_status_make_fixture "$recent_sess_dir/sess-120.jsonl" "sess-120" "feature/120" "c120" "gpt-test" "high" 152 902 1000 82 300 1716500001 91 10080 1717100001
  sleep 1
  codex_status_make_fixture "$recent_sess_dir/sess-121.jsonl" "sess-121" "feature/121" "c121" "gpt-test" "high" 153 903 1000 83 300 1716500002 90 10080 1717100002
  sleep 1
  codex_status_make_fixture "$recent_sess_dir/sess-122.jsonl" "sess-122" "feature/122" "c122" "gpt-test" "high" 154 904 1000 84 300 1716500003 89 10080 1717100003
  sleep 1
  codex_status_make_fixture "$recent_sess_dir/sess-123.jsonl" "sess-123" "feature/codex-status-recent" "abc123" "gpt-5.4-mini" "medium" 150 900 1000 85 300 1716521460 93 10080 1717121460
  sleep 1
  cat > "$recent_sess_dir/malformed.jsonl" <<'EOF'
{"type":"event_msg","timestamp":"2026-06-02T00:00:02Z","payload":{"type":"token_count"
EOF

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$recent_codex_home" repo-automation/bin/codex-status --recent >"$out" 2>"$err" &&
     python3 - "$out" <<'PY'
import json, sys
from pathlib import Path
data=json.load(open(sys.argv[1]))
assert data["schema"] == "repo-automation-codex-status-recent/v1"
assert data["ok"] is True
assert data["result"] == "pass"
assert data["status"] == "pass"
assert len(data["sessions"]) == 5
assert [session["session_id"] for session in data["sessions"][:3]] == ["sess-123", "sess-122", "sess-121"]
assert data["rate_limits"]["five_hour"]["resets_at"] is not None
assert data["rate_limits"]["five_hour"]["resets_at_iso"] is not None
assert data["rate_limits"]["five_hour"]["resets_at_local"] is not None
assert data["rate_limits"]["weekly"]["resets_at"] is not None
assert data["rate_limits"]["weekly"]["resets_at_iso"] is not None
assert data["rate_limits"]["weekly"]["resets_at_local"] is not None
assert "rate_limits" not in data["sessions"][0]
assert data["sessions"][0]["resume"]["command"] == "codex resume --include-non-interactive sess-123"
assert any("skipped malformed session file" in warning for warning in data["warnings"])
PY
  then :; else test_fail "recent default json"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$recent_codex_home" repo-automation/bin/codex-status --recent=1 >"$out" 2>"$err" &&
     python3 - "$out" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
assert data["schema"] == "repo-automation-codex-status-recent/v1"
assert len(data["sessions"]) == 1
assert data["sessions"][0]["session_id"] == "sess-123"
assert data["sessions"][0]["resume"]["command"] == "codex resume --include-non-interactive sess-123"
PY
  then :; else test_fail "recent one json"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$recent_codex_home" repo-automation/bin/codex-status --recent --pretty >"$out" 2>"$err" &&
     grep -Fq 'codex-status' "$out" &&
     grep -Fq '5h:' "$out" &&
     grep -Fq 'week:' "$out" &&
     grep -Fq 'recent sessions' "$out" &&
     grep -Fq 'resume:' "$out" &&
     grep -Fq 'codex resume --include-non-interactive sess-123' "$out" &&
     ! grep -Fqi 'rate limits' "$out" &&
     ! grep -Fqi 'plan: plus' "$out"
  then :; else test_fail "recent pretty"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --help --pretty >"$out" 2>"$err" &&
     grep -Fq 'codex-status' "$out" &&
     grep -Fq 'Session selection:' "$out" &&
     grep -Fq -- '--recent' "$out" &&
     grep -Fq -- '--recent=<n>' "$out" &&
     grep -Fq -- '--verbose' "$out" &&
     grep -Fq 'Add token breakdown details to pretty single-session output.' "$out" &&
     grep -Fq 'Valid range: 1..50.' "$out" &&
     grep -Fq 'Unsupported:' "$out" &&
     grep -Fq -- '--quiet' "$out" &&
     grep -Fq -- '--json' "$out" &&
     grep -Fq -- '--all-sessions' "$out" &&
     ! grep -Fq -- '--session-id <id>' "$out"
  then :; else test_fail "help pretty"; status=1; fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --verbose >/dev/null 2>"$err"; then
    test_fail "verbose without pretty"; status=1
  else
    grep -Fq 'invalid flag combination' "$err" || { test_fail "verbose without pretty"; status=1; }
  fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --recent=0 >/dev/null 2>"$err"; then
    test_fail "recent zero"; status=1
  else
    grep -Fq 'invalid recent count' "$err" || { test_fail "recent zero"; status=1; }
  fi
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --recent=-1 >/dev/null 2>"$err"; then
    test_fail "recent negative"; status=1
  else
    grep -Fq 'invalid recent count' "$err" || { test_fail "recent negative"; status=1; }
  fi
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --recent=abc >/dev/null 2>"$err"; then
    test_fail "recent text"; status=1
  else
    grep -Fq 'invalid recent count' "$err" || { test_fail "recent text"; status=1; }
  fi
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --recent=51 >/dev/null 2>"$err"; then
    test_fail "recent cap"; status=1
  else
    grep -Fq 'invalid recent count' "$err" || { test_fail "recent cap"; status=1; }
  fi
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --recent 1 >/dev/null 2>"$err"; then
    test_fail "recent space form"; status=1
  else
    grep -Fq 'unsupported flag' "$err" || { test_fail "recent space form"; status=1; }
  fi
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --recent=1 --session >/dev/null 2>"$err"; then
    test_fail "recent session conflict"; status=1
  else
    grep -Fq 'unsupported flag' "$err" || { test_fail "recent session conflict"; status=1; }
  fi
  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" repo-automation/bin/codex-status --all-sessions >/dev/null 2>"$err"; then
    test_fail "all-sessions unsupported"; status=1
  else
    grep -Fq 'unsupported flag' "$err" || { test_fail "all-sessions unsupported"; status=1; }
  fi

  if PATH="$smoke_test_dir/repo-automation/bin:$PATH" CODEX_HOME="$codex_home" repo-automation/bin/codex-status --session-file="$contract_root/missing.jsonl" >/dev/null 2>"$err"; then
    test_fail "missing session"; status=1
  else
    grep -Fq 'missing or unreadable session file' "$err" || { test_fail "missing session"; status=1; }
  fi

  rm -f "$out" "$err" >/dev/null 2>&1 || true
  return "$status"
}

smoke_run_focused_contract_wrapper codex_status_main "$@"
