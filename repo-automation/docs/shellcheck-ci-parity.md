# ShellCheck CI Parity

`repo-automation/bin/shellcheck-ci-parity` derives its file set from `repo-automation/helper-metadata.json`, adds the shared test/library files, and runs the same ShellCheck `-e SC2317` exclusion used by CI.

Public helpers added to `repo-automation/helper-metadata.json` are included automatically as long as their `repo-automation/bin/` path exists.

To print the exact CI/parity file set, use:

    repo-automation/bin/shellcheck-ci-parity --print-paths

Use it locally from the repo root to catch CI-only ShellCheck failures before pushing.

Help:

    repo-automation/bin/shellcheck-ci-parity --help

If ShellCheck is missing on Termux, install it with:

`pkg install shellcheck`
