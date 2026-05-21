# Repo Flow

`repo-automation/bin/repo-flow` is a first-pass helper for idempotent PR integration on the current branch.

It verifies the branch is not `main`, checks the worktree, reports ahead/behind versus `origin/main`, pushes the current branch when needed, and either reuses or creates the branch PR.

`repo-automation/bin/repo-flow submit` is the guarded phone-first commit entrypoint.
Use `--modified` for tracked modified/deleted/renamed paths from both staged and unstaged diffs, `--paths=<path[,path...]>` for explicit repo-relative paths, or `--staged` to commit the current index.
Prefer `--modified` instead of shell-building a `--paths` CSV for tracked edits.
It refuses absolute paths, `..`, default-branch submits, and any unrequested dirty or untracked worktree changes before staging when `--paths` is used.
`--modified` blocks new files, including pre-staged additions and untracked paths; use `--paths=<path>` or `--staged` explicitly for new files.
When `EXPECTED_REMOTE_URL` is set, a matching GitHub SSH alias remote is also accepted if `ssh -G` resolves the alias to `github.com` and the repo path matches `UPSTREAM_REPO_FULL_NAME`.
When `repo-flow submit` creates a PR, it generates the canonical PR body headings and routes the body through `repo-automation/bin/pr-create`.
`--watch` hands off to the repo-native PR completion path with a bounded timeout; `--timeout=<seconds>` sets that limit.
When `--watch` is used, `repo-flow submit` pushes the current branch before PR lookup/create/watch.
`--diagnose-on-fail` is only forwarded with `--watch`.

`--watch` hands off to `repo-automation/bin/pr-finish --watch --merge --delete-branch --sync-main --pr=current` after the branch is pushed and a PR exists.
`pr-finish` is current-head-aware: missing or not-yet-attached checks stay pending until timeout, stale checks from older SHAs are ignored, and merges/deletes/syncs only happen after the current head is green.
Use `--explain` for the full human flow report; default success is compact `plan`, PR URL, or `pass`.
`--explain` ends with a compact `===== FINAL SUMMARY =====` handoff block.

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
    repo-automation/bin/repo-flow submit --modified --message="update repo-flow docs"
    repo-automation/bin/repo-flow submit --staged --message="commit staged work"
    repo-automation/bin/repo-flow submit --paths=docs/repo-flow.md --message="update repo-flow docs"
    repo-automation/bin/repo-flow status-card
    repo-automation/bin/repo-flow status-card --json
