# GitHub Settings Check

`repo-automation/bin/github-settings-check` is a read-only helper that reports GitHub repository settings readiness for the current checkout or an explicit repo.

It does not create, update, merge, close, delete, or configure anything.

What it reports where practical:

- default branch
- delete-branch-on-merge setting
- merge method availability for merge, squash, and rebase
- Actions availability and allowed-actions visibility
- branch protection or branch ruleset presence for the default branch
- local pull request template presence
- local issue template presence
- local CI workflow presence

If `gh` is missing, unauthenticated, offline, or the repo cannot be inferred from `origin`, the helper warns and skips the GitHub queries cleanly. Local file checks still run.

Default human output:

    repo-automation/bin/github-settings-check

Check an explicit repo:

    repo-automation/bin/github-settings-check --repo=OWNER/REPO

Machine output:

    repo-automation/bin/github-settings-check --machine-json

Quiet human output:

    repo-automation/bin/github-settings-check --quiet

The helper uses read-only `gh api` calls only.
