# PR Body Check

`repo-automation/bin/pr-body-check` validates the canonical PR body contract used by CI and `pr-create`.

It requires:

- `## Scope`
- `## What changed`
- `## What did not change`
- `## Verification status`
- `## User-visible behavior changes`
- `## Stop conditions encountered`
- `## Re-entry hint`

It validates the heading names and order, rejects missing headings, duplicate headings, out-of-order headings, the passive monetization section, and placeholder-only scaffolding.
It also requires a regular readable file and rejects directories, missing files, and unreadable files.

`--print-template` prints the canonical PR body template to stdout. It does not read `--body-file`.

Value flags use `--body-file=<path>` syntax. `--body-file <path>` is rejected.

Default success output is `pass`. `--quiet` makes success silent.

Usage examples:

    repo-automation/bin/pr-body-check --print-template
    repo-automation/bin/pr-body-check --body-file=.github/pull_request_template.md
    repo-automation/bin/pr-body-check --quiet --body-file=${TMPDIR:-$HOME/.cache}/pr-body.md

Minimal valid custom body:

    ## Scope

    None

    ## What changed

    None

    ## What did not change

    None

    ## Verification status

    None

    ## User-visible behavior changes

    None

    ## Stop conditions encountered

    None

    ## Re-entry hint

    Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.

`## Re-entry hint` is the next reviewer/operator step after the PR is opened. Use it to say what should happen after review starts, usually the merge/watch follow-up.
