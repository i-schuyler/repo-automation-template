# Check Tooling

`repo-automation/bin/check-tooling` is a read-only first-run audit helper.
It reports missing required and recommended tools and suggests copyable install commands for the detected platform.

## Checked tools

Required:

- `bash`
- `git`
- `python3`
- `sed`
- `awk`
- `find`
- `sort`
- `xargs`
- `df`

Recommended:

- `gh`
- `shellcheck`
- `timeout`
- `du`
- `ssh`

## Platform detection

Detected platforms:

- `termux-android`
- `ubuntu-debian`
- `fedora-rhel-centos`
- `macos`
- `windows-git-bash`
- `unknown`

Tests can override detection with:

- `REPO_AUTOMATION_TOOLING_PLATFORM=<platform>`
- `REPO_AUTOMATION_TOOLING_PATH=<path>`

## Output

- default: `pass`, `warn: missing recommended tools`, or `fail: missing required tools`
- quiet: success is silent
- explain: includes platform, checked tools, found/missing status, and the fix command
- json: machine-only JSON with the platform, status, tool lists, and fix command

The helper never installs anything.
