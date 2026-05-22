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

It rejects missing headings, duplicate headings, out-of-order headings, the passive monetization section, and placeholder-only scaffolding.
It also requires a regular readable file and rejects directories, missing files, and unreadable files.

Value flags use `--body-file=<path>` syntax. `--body-file <path>` is rejected.

Default success output is `pass`. `--quiet` makes success silent.

Usage examples:

    repo-automation/bin/pr-body-check --body-file=.github/pull_request_template.md
    repo-automation/bin/pr-body-check --quiet --body-file=${TMPDIR:-$HOME/.cache}/pr-body.md
