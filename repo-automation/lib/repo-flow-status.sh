#!/usr/bin/env bash
# repo-automation/lib/repo-flow-status.sh

repo_flow_status_card_classify_checks() {
  local checks_json="${1:-}"
  local checks_state="unknown"

  if command -v python3 >/dev/null 2>&1; then
    checks_state="$(STATUS_CARD_CHECKS_JSON="$checks_json" python3 - <<'PY'
from __future__ import annotations

import json
import os

raw = os.environ.get("STATUS_CARD_CHECKS_JSON", "")
try:
    data = json.loads(raw) if raw else []
except Exception:
    print("unknown")
    raise SystemExit(0)

if not isinstance(data, list) or len(data) == 0:
    print("unknown")
    raise SystemExit(0)

pending_states = {"pending", "queued", "in_progress", "requested", "waiting", "action_required"}
blocked_states = {"fail", "failed", "failure", "cancel", "cancelled", "canceled", "timed_out", "timeout", "error"}
green_states = {"pass", "passed", "success", "succeeded", "completed"}
pending = False
blocked = False
green = False

for item in data:
    if not isinstance(item, dict):
        continue
    bucket = str(item.get("bucket", "")).lower()
    state = str(item.get("state", "")).lower()
    if bucket == "pending" or state in pending_states:
        pending = True
    elif bucket in {"fail", "failed", "failure", "cancel"} or state in blocked_states:
        blocked = True
    elif bucket in {"pass", "success"} or state in green_states:
        green = True

if blocked:
    print("blocked")
elif pending:
    print("pending")
elif green:
    print("green")
else:
    print("unknown")
PY
)"
  fi

  printf '%s' "$checks_state"
}

# repo-automation/lib/repo-flow-status.sh EOF
