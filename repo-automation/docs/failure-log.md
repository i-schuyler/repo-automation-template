# Failure Log

`repo-automation/bin/failure-log` prints the latest useful failure excerpt from existing local logs without rerunning anything.

It looks in the same temp-log root used by `repo-automation/bin/run-tests` and `repo-automation/bin/repo-doctor`:

    ${TMPDIR:-$HOME/.cache}/repo-automation-template

Supported flags:

- `--latest` picks the newest matching log. This is the default behavior.
- `--kind=run-tests|repo-doctor|any` narrows the search.
- `--lines=N` sets how many lines of context to show.
- `--machine-json` returns machine-readable output.

Examples:

    repo-automation/bin/failure-log
    repo-automation/bin/failure-log --kind=run-tests --lines=24
    repo-automation/bin/failure-log --kind=repo-doctor --machine-json

The helper prints a compact excerpt only. It does not rerun checks, and it does not require you to paste a temp log path by hand.
