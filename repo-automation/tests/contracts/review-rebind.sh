#!/usr/bin/env bash
# repo-automation/tests/contracts/review-rebind.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

# shellcheck disable=SC2154
# smoke_test_base and smoke_test_dir are shared harness globals initialized by
# repo-automation/tests/lib/smoke-common.sh before contract checks run.
smoke_check_review_rebind_contract() {
  local status=0
  local gh_stub_dir="$smoke_test_base/gh-stub-review-rebind"
  local success_json="$smoke_test_base/review-rebind-success.json"
  local success_err="$smoke_test_base/review-rebind-success.err"
  local strict_json="$smoke_test_base/review-rebind-strict.json"
  local strict_err="$smoke_test_base/review-rebind-strict.err"
  local no_checkpoint_json="$smoke_test_base/review-rebind-no-checkpoint.json"
  local malformed_json="$smoke_test_base/review-rebind-malformed.json"
  local incomplete_json="$smoke_test_base/review-rebind-incomplete.json"
  local runtime_ci_log="$smoke_test_base/review-rebind-runtime-ci.log"
  local path_ci_log="$smoke_test_base/review-rebind-path-ci.log"
  local runtime_ci="$smoke_test_dir/repo-automation/bin/ci-status"

  smoke_write_gh_stub "$gh_stub_dir" || return 1

  cat >"$runtime_ci" <<'EOF'
#!/usr/bin/env bash
if [ -n "${REVIEW_REBIND_RUNTIME_CI_LOG:-}" ]; then
  printf '%s\n' "$*" >>"$REVIEW_REBIND_RUNTIME_CI_LOG"
fi
if [ "${REVIEW_REBIND_CI_CHILD_JSON+x}" = x ]; then
  printf '%s\n' "$REVIEW_REBIND_CI_CHILD_JSON"
else
  printf '%s\n' '{"schema":"repo-automation-helper-output/v1","script":"ci-status","mode":"json","result":"pass","overall_status":"pass","head_sha":"head-new","pr":"3"}'
fi
EOF
  chmod +x "$runtime_ci" || return 1

  cat >"$gh_stub_dir/ci-status" <<'EOF'
#!/usr/bin/env bash
if [ -n "${REVIEW_REBIND_PATH_CI_LOG:-}" ]; then
  printf '%s\n' "$*" >>"$REVIEW_REBIND_PATH_CI_LOG"
fi
printf '%s\n' 'PATH ci-status must not be used' >&2
exit 97
EOF
  chmod +x "$gh_stub_dir/ci-status" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/review-rebind --pr 3 --json >"$strict_json" 2>"$strict_err"
  ); then
    test_fail "review-rebind rejects separated --pr syntax"
    status=1
  elif [ ! -s "$strict_err" ] && python3 -m json.tool "$strict_json" >/dev/null 2>&1 && \
    smoke_json_assert "$strict_json" 'data.get("result") == "fail" and data.get("code") == "flag-format-not-accepted" and data.get("step") == "flag-parse"'; then
    test_pass "review-rebind rejects separated --pr syntax"
  else
    test_fail "review-rebind rejects separated --pr syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$runtime_ci_log" "$path_ci_log"
    GH_STUB_REPO_NAME_WITH_OWNER='i-schuyler/repo-automation-template' \
    GH_STUB_DEFAULT_BRANCH_NAME='main' \
    GH_STUB_PR_VIEW_NUMBER='3' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='true' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='head-new' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/review-rebind' \
    GH_STUB_PR_VIEW_BASE_SHA='base-old' \
    GH_STUB_PR_VIEW_BASE_REF='main' \
    GH_STUB_PR_VIEW_BODY_TEXT='bounded PR body {fixture}' \
    GH_STUB_DEFAULT_BRANCH_REF_JSON='{"ref":"refs/heads/main","object":{"sha":"main-new"}}' \
    GH_STUB_PR_REVIEWS_JSON='[[{"id":11,"state":"APPROVED","submitted_at":"2026-08-18T20:00:00Z","commit_id":"head-new","body":"looks good","user":{"login":"reviewer-a"}},{"id":12,"state":"COMMENTED","submitted_at":"2026-08-18T20:01:00Z","commit_id":"head-new","body":"note {kept}","user":{"login":"reviewer-b"}}]]' \
    GH_STUB_PR_FILES_JSON='[[{"filename":"z-last.txt"}],[{"filename":"a-first.txt"},{"filename":"z-last.txt"}]]' \
    GH_STUB_ISSUE_COMMENTS_JSON='[[{"id":170,"updated_at":"2026-08-18T20:02:00Z","body":"<!-- pr-review-checkpoint:v1 -->\n- Sequence: 17\n- Reviewed head: old-17\n- Base/current main: old-main\n- Lifecycle: REVIEW_IN_PROGRESS\n- Current item: PRG-G4"},{"id":180,"updated_at":"2026-08-18T20:03:00Z","body":"<!-- pr-review-checkpoint:v1 -->\n- Sequence: 18\n- Review generation: 2\n- Reviewed head: head-old\n- Base/current main: main-old\n- Lifecycle state: REPAIR_IN_PROGRESS\n- Current item: PRG-G5\n- Verdict: pending"}]]' \
    GH_STUB_REVIEW_THREADS_JSON='[{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"T1","isResolved":true,"comments":{"totalCount":1,"nodes":[{"databaseId":101,"body":"done","createdAt":"2026-08-18T20:00:00Z","updatedAt":"2026-08-18T20:00:00Z","author":{"login":"reviewer-a"},"path":"a-first.txt"}]}},{"id":"T2","isResolved":false,"comments":{"totalCount":1,"nodes":[{"databaseId":102,"body":"open","createdAt":"2026-08-18T20:01:00Z","updatedAt":"2026-08-18T20:01:00Z","author":{"login":"reviewer-b"},"path":"z-last.txt"}]}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}]' \
    REVIEW_REBIND_RUNTIME_CI_LOG="$runtime_ci_log" \
    REVIEW_REBIND_PATH_CI_LOG="$path_ci_log" \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/review-rebind --pr=3 --json >"$success_json" 2>"$success_err"
  ); then
    test_pass "review-rebind success fixture runs"
  else
    test_fail "review-rebind success fixture runs"
    status=1
  fi

  if [ ! -s "$success_err" ] && python3 -m json.tool "$success_json" >/dev/null 2>&1 && \
    smoke_json_assert "$success_json" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "review-rebind" and data.get("result") == "pass" and data.get("repository") == "i-schuyler/repo-automation-template" and data.get("pr") == 3 and data.get("pr_state", {}).get("open") is True and data.get("pr_state", {}).get("draft") is True and data.get("pr_state", {}).get("merged") is False and data.get("head") == {"ref":"feature/review-rebind","sha":"head-new"} and data.get("base") == {"ref":"main","sha":"base-old"} and data.get("default_branch") == {"ref":"main","sha":"main-new"} and str(data.get("body", {}).get("fingerprint", "")).startswith("sha256:") and data.get("reviews", {}).get("count") == 2 and data.get("review_threads", {}).get("total") == 2 and data.get("review_threads", {}).get("unresolved") == 1 and data.get("review_threads", {}).get("completeness") == "complete" and data.get("checkpoint", {}).get("comment_id") == 180 and data.get("checkpoint", {}).get("sequence") == 18 and data.get("checkpoint", {}).get("review_generation") == "2" and data.get("checkpoint", {}).get("lifecycle") == "REPAIR_IN_PROGRESS" and data.get("checkpoint", {}).get("verdict") == "pending" and data.get("changed_files") == {"count":2,"filenames":["a-first.txt","z-last.txt"]} and data.get("ci", {}).get("script") == "ci-status" and {item.get("field") for item in data.get("binding_mismatches", [])} == {"checkpoint.reviewed_head","checkpoint.base_current_main","pr.base_sha"}'; then
    test_pass "review-rebind normalizes bindings, pagination, activity, checkpoint, and mismatches"
  else
    test_fail "review-rebind normalizes bindings, pagination, activity, checkpoint, and mismatches"
    status=1
  fi

  if grep -Fxq -- '--pr=3 --json' "$runtime_ci_log" && [ ! -e "$path_ci_log" ]; then
    test_pass "review-rebind resolves ci-status at the repo-relative runtime path"
  else
    test_fail "review-rebind resolves ci-status at the repo-relative runtime path"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_REPO_NAME_WITH_OWNER='i-schuyler/repo-automation-template' \
    GH_STUB_DEFAULT_BRANCH_NAME='main' \
    GH_STUB_PR_VIEW_NUMBER='3' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_HEAD_SHA='head-new' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/review-rebind' \
    GH_STUB_PR_VIEW_BASE_SHA='main-new' \
    GH_STUB_PR_VIEW_BASE_REF='main' \
    GH_STUB_DEFAULT_BRANCH_REF_JSON='{"ref":"refs/heads/main","object":{"sha":"main-new"}}' \
    GH_STUB_PR_REVIEWS_JSON='[[]]' \
    GH_STUB_PR_FILES_JSON='[[]]' \
    GH_STUB_ISSUE_COMMENTS_JSON='[[]]' \
    GH_STUB_REVIEW_THREADS_JSON='[{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}]' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/review-rebind --pr=3 --json >"$no_checkpoint_json"
  ) && smoke_json_assert "$no_checkpoint_json" 'data.get("result") == "pass" and data.get("checkpoint") == {"available":False}'; then
    test_pass "review-rebind represents checkpoint absence without invented state"
  else
    test_fail "review-rebind represents checkpoint absence without invented state"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_REPO_NAME_WITH_OWNER='i-schuyler/repo-automation-template' \
    GH_STUB_DEFAULT_BRANCH_NAME='main' \
    GH_STUB_PR_VIEW_NUMBER='3' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_HEAD_SHA='head-new' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/review-rebind' \
    GH_STUB_PR_VIEW_BASE_SHA='main-new' \
    GH_STUB_PR_VIEW_BASE_REF='main' \
    GH_STUB_DEFAULT_BRANCH_REF_JSON='{"ref":"refs/heads/main","object":{"sha":"main-new"}}' \
    GH_STUB_PR_REVIEWS_JSON='[[]]' \
    GH_STUB_PR_FILES_JSON='[[]]' \
    GH_STUB_ISSUE_COMMENTS_JSON='[[{"id":999,"body":"<!-- pr-review-checkpoint:v1 -->\n- Sequence: not-a-number\n- Reviewed head: head-new"}]]' \
    GH_STUB_REVIEW_THREADS_JSON='[{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}]' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/review-rebind --pr=3 --json >"$malformed_json"
  ); then
    test_fail "review-rebind fails explicit malformed checkpoint"
    status=1
  elif smoke_json_assert "$malformed_json" 'data.get("result") == "fail" and data.get("code") == "malformed-checkpoint" and data.get("step") == "checkpoint-parse"'; then
    test_pass "review-rebind fails explicit malformed checkpoint"
  else
    test_fail "review-rebind fails explicit malformed checkpoint"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_REPO_NAME_WITH_OWNER='i-schuyler/repo-automation-template' \
    GH_STUB_DEFAULT_BRANCH_NAME='main' \
    GH_STUB_PR_VIEW_NUMBER='3' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_HEAD_SHA='head-new' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/review-rebind' \
    GH_STUB_PR_VIEW_BASE_SHA='main-new' \
    GH_STUB_PR_VIEW_BASE_REF='main' \
    GH_STUB_DEFAULT_BRANCH_REF_JSON='{"ref":"refs/heads/main","object":{"sha":"main-new"}}' \
    GH_STUB_PR_REVIEWS_JSON='[[]]' \
    GH_STUB_PR_FILES_JSON='[[]]' \
    GH_STUB_ISSUE_COMMENTS_JSON='[[]]' \
    GH_STUB_REVIEW_THREADS_JSON='[{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"T3","isResolved":false,"comments":{"totalCount":2,"nodes":[{"databaseId":103,"body":"partial","createdAt":"2026-08-18T20:00:00Z","updatedAt":"2026-08-18T20:00:00Z","author":{"login":"reviewer-c"},"path":"a-first.txt"}]}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}]' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/review-rebind --pr=3 --json >"$incomplete_json"
  ) && smoke_json_assert "$incomplete_json" 'data.get("result") == "pass" and data.get("review_threads", {}).get("completeness") == "incomplete" and "review_thread_comment_details" in data.get("unknowns", [])'; then
    test_pass "review-rebind surfaces incomplete review-thread detail"
  else
    test_fail "review-rebind surfaces incomplete review-thread detail"
    status=1
  fi

  return "$status"
}

smoke_main_impl() {
  local status=0
  trap 'test_cleanup' EXIT INT TERM
  smoke_setup_temp_repo || return 1
  smoke_run_named_check "smoke:review-rebind-contract" smoke_check_review_rebind_contract || status=1
  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/review-rebind.sh EOF
