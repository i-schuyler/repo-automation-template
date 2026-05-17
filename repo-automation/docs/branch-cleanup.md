# Branch Cleanup

`repo-automation/bin/branch-cleanup` inspects local branches and only deletes branches that are safe stale local branches.

Safe stale local branch means all of the following:

- local branch only
- not the current branch
- not the default branch
- fully merged into `origin/<default-branch>`
- no unique commits needing preservation
- branch name passes shared branch validation

Default behavior is plan-only. No deletion happens unless `--apply` is passed.
Use `--explain` for the detailed branch summary; default success is compact `plan` or `pass`.

The script never deletes remote branches and never force-deletes local branches.

All local branches are classified as either a deletion candidate or a skipped branch with a reason.

`--json` prints machine-parseable JSON on stdout only. Human INFO/WARN/STOP logs are written to stderr in JSON mode.

`--json` output includes:

- mode
- default branch
- current branch
- candidates
- skipped branches with `branch` and `reason`
- deleted branches
- stop reason

Expected skip reasons include:

- `current-branch`
- `default-branch`
- `not-merged-into-origin-default`
- `has-unique-commits`
- `invalid-branch-name`
- `ambiguous-status`

Config loading is strict for this script. Invalid config, secret-scan failure, or config source failure stops execution instead of silently falling back. `--apply` requires valid config.

Usage examples:

    repo-automation/bin/branch-cleanup --plan
    repo-automation/bin/branch-cleanup --json --plan
    repo-automation/bin/branch-cleanup --apply

Test coverage:

- `repo-automation/tests/smoke.sh` validates plan mode, JSON parseability, candidate classification, and skipped reason reporting.
