# Repo Flow

`repo-automation/bin/repo-flow` is a first-pass helper for idempotent PR integration on the current branch.

It verifies the branch is not `main`, checks the worktree, reports ahead/behind versus `origin/main`, pushes the current branch when needed, and either reuses or creates the branch PR.

`--dry-run` / `--plan` reports the flow without pushing or creating a PR.

Usage examples:

    repo-automation/bin/repo-flow
    repo-automation/bin/repo-flow --dry-run
    repo-automation/bin/repo-flow --json
