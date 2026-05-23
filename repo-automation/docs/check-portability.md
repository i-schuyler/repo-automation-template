# Check Portability

`repo-automation/bin/check-portability` scans metadata-driven source/workflow targets for high-confidence portability drift.

Target discovery comes from:

- `repo-automation/bin/shellcheck-ci-parity --print-paths`
- `.github/workflows/*.yml`
- tracked executable repo files discovered through Git that are not already in the set

Use `repo-automation/bin/check-portability --print-targets` to print the exact target list.

Blocking findings cover executable `python` command-token drift.
Advisories warn on source/workflow portability risks such as temp-path assumptions and GNU-specific command options.

Advisory-only findings still exit 0.
When a fix needs a temp path, use `${TMPDIR:-$HOME/.cache}` instead of a hardcoded temp directory.
