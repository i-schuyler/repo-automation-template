# PR Finish

`repo-automation/bin/pr-finish` is a terminal helper for safely finishing the current branch PR.

Default behavior is plan/status-only. It does not merge unless `--merge` is explicitly passed.

`--pr=latest` selects the latest open PR in the current repo.

`--pr=current` resolves the PR associated with the current branch.

`--watch` waits on required checks but does not merge by itself.
If checks are briefly missing right after PR creation or reuse, `--watch` retries a few times before failing.
`--watch --diagnose-on-fail` also runs `repo-automation/bin/ci-log-dump --pr=<number>` when the final checks status is blocked/red and prints a short diagnosis path/excerpt.

`--watch --merge` still re-reads PR state and checks before merge and only proceeds when all gates are green.

`--sync-main` switches to `main` and runs `git pull --ff-only` after a successful merge.

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

    repo-automation/bin/pr-finish --status
    repo-automation/bin/pr-finish --watch
    repo-automation/bin/pr-finish --watch --diagnose-on-fail
    repo-automation/bin/pr-finish --watch --merge --squash
    repo-automation/bin/pr-finish --watch --pr=latest
    repo-automation/bin/pr-finish --status --pr=current
    repo-automation/bin/pr-finish --merge --pr=123 --delete-branch
    repo-automation/bin/pr-finish --merge --pr=current --sync-main
    repo-automation/bin/pr-finish --json --status
