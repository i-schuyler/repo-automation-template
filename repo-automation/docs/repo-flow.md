# Repo Flow

`repo-automation/bin/repo-flow` is a first-pass helper for idempotent PR integration on the current branch.

It verifies the branch is not `main`, checks the worktree, reports ahead/behind versus `origin/main`, pushes the current branch when needed, and either reuses or creates the branch PR.

`--watch` hands off to `repo-automation/bin/pr-finish --watch --pr=current` after the branch is pushed and a PR exists.
`--diagnose-on-fail` is forwarded when combined with `--watch`; blocked checks then surface the first-failure diagnosis from `ci-log-dump`.
`pr-finish` retries briefly if checks are not registered yet right after PR creation or reuse.
Use `--explain` for the full human flow report; default success is compact `plan`, PR URL, or `pass`.

`--dry-run` / `--plan` reports the flow without pushing or creating a PR.
`status-card` is a read-only state screen. It never pushes, creates a PR, watches CI, or mutates the repo.
`status-card` reports these human keys:

- `branch`
- `default`
- `worktree`
- `tracked_changed`
- `untracked`
- `range_vs_default`
- `ahead_behind`
- `pr`
- `checks`
- `next`

`status-card --json` emits valid JSON only.
GitHub lookup failures do not make `status-card` fail; local state still prints.

Usage examples:

    repo-automation/bin/repo-flow
    repo-automation/bin/repo-flow --dry-run
    repo-automation/bin/repo-flow --watch
    repo-automation/bin/repo-flow --watch --diagnose-on-fail
    repo-automation/bin/repo-flow --json
    repo-automation/bin/repo-flow status-card
    repo-automation/bin/repo-flow status-card --json
