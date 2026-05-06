# Branch Cleanup

`scripts/branch-cleanup` inspects local branches and only deletes branches that are safe stale local branches.

Safe stale local branch means all of the following:

- local branch only
- not the current branch
- not the default branch
- fully merged into `origin/<default-branch>`
- no unique commits needing preservation
- branch name passes shared branch validation

Default behavior is plan-only. No deletion happens unless `--apply` is passed.

The script never deletes remote branches and never force-deletes local branches.

`--json` prints structured output for later ChatGPT/Codex parsing:

- mode
- default branch
- current branch
- candidates
- skipped branches with reasons
- deleted branches
- stop reason

Usage examples:

    scripts/branch-cleanup --plan
    scripts/branch-cleanup --json --plan
    scripts/branch-cleanup --apply
