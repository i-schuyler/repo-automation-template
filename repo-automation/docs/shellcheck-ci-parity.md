# ShellCheck CI Parity

`repo-automation/bin/shellcheck-ci-parity` runs the same ShellCheck file set and `-e SC2317` exclusion used by CI.

Use it locally from the repo root to catch CI-only ShellCheck failures before pushing.

If ShellCheck is missing on Termux, install it with:

`pkg install shellcheck`
