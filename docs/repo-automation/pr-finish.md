# PR Finish

`scripts/pr-finish` is a terminal helper for safely finishing the current branch PR.

Default behavior is plan/status-only. It does not merge unless `--merge` is explicitly passed.

`--watch` waits on required checks but does not merge by itself.

`--watch --merge` still re-reads PR state and checks before merge and only proceeds when all gates are green.

Merge is blocked when any of the following are true:

- PR is closed
- PR is draft
- PR is not mergeable
- required checks are pending, failed, cancelled, skipped, missing, or ambiguous
- local working tree is dirty

Branch deletion after merge is explicit with `--delete-branch`. No direct `git push` branch deletion is used by this helper.

`--json` writes valid JSON only to stdout. Human INFO/WARN/STOP logs go to stderr in JSON mode.

JSON output includes:

- `mode`
- `current_branch`
- `pr_number`
- `pr_url`
- `pr_state`
- `is_draft`
- `mergeable`
- `checks_status`
- `checks_summary`
- `merge_mode`
- `delete_branch`
- `can_merge`
- `block_reasons`
- `action_taken`
- `stop_reason`

Usage examples:

    scripts/pr-finish --status
    scripts/pr-finish --watch
    scripts/pr-finish --watch --merge --squash
    scripts/pr-finish --merge --pr 123 --delete-branch
    scripts/pr-finish --json --status
