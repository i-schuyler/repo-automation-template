# Repo Flow

`repo-automation/bin/repo-flow` is a first-pass helper for idempotent PR integration on the current branch.

It verifies the branch is not `main`, checks the worktree, reports ahead/behind versus `origin/main`, pushes the current branch when needed, and either reuses or creates the branch PR.

`repo-automation/bin/repo-flow submit` is the guarded phone-first commit entrypoint.
Use `--paths=<path[,path...]>` to stage only explicit repo-relative paths, or `--staged` to commit the current index.
It refuses absolute paths, `..`, default-branch submits, pre-staged changes, and any unrequested dirty or untracked worktree changes before staging when `--paths` is used.
When `EXPECTED_REMOTE_URL` is set, a matching GitHub SSH alias remote is also accepted if `ssh -G` resolves the alias to `github.com` and the repo path matches `UPSTREAM_REPO_FULL_NAME`.
`--watch` hands off to the repo-native PR completion path with a bounded timeout; `--timeout=<seconds>` sets that limit.
`--diagnose-on-fail` is only forwarded with `--watch`.

`--watch` hands off to `repo-automation/bin/pr-finish --watch --merge --delete-branch --sync-main --pr=current` after the branch is pushed and a PR exists.
`pr-finish` watches the current PR head SHA, retries briefly while checks attach, and merges/deletes/syncs only after the current head is green.
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
    repo-automation/bin/repo-flow submit --paths=docs/repo-flow.md --message="update repo-flow docs"
    repo-automation/bin/repo-flow submit --staged --message="commit staged work"
    repo-automation/bin/repo-flow status-card
    repo-automation/bin/repo-flow status-card --json
