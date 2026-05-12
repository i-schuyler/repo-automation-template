# Touched Files

`repo-automation/bin/touched-files` prints a read-only list of changed files for the current repo.

Default behavior:

- compares `main...HEAD`
- lists tracked files from `git diff --name-only`
- falls back to uncommitted tracked and untracked files only when the commit range has no changes
- never prints full diffs

Supported flags:

- `--base=REF` selects the left side of the diff range
- `--head=REF` selects the right side of the diff range
- `--machine-json` returns machine-readable output

Examples:

    repo-automation/bin/touched-files
    repo-automation/bin/touched-files --base=main --head=HEAD
    repo-automation/bin/touched-files --machine-json

The helper is read-only and does not write commits, tags, or GitHub objects.
