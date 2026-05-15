# PR Create

`repo-automation/bin/pr-create` is a terminal helper for creating pull requests for mixed code/docs/test changes.

Default behavior is PR creation through `gh pr create`. It does not merge.

`--dry-run` validates inputs without creating a PR.

Value flags use `--flag=<value>` syntax. Space-separated values are rejected.

The helper expects the current repo automation GitHub workflow conventions already used elsewhere in this repo:

- SSH-style GitHub remotes by default
- `DEFAULT_BRANCH` / `REMOTE_NAME` / `EXPECTED_REMOTE_URL` from `.repo-automation.conf`
- a committed, clean worktree on the target branch

## Title and Body

`--title=<text>` is required.

Provide the body with either:

- `--body-file=<path>`
- `--body=<text>`

The helper writes `--body` text to a temporary file before calling `gh pr create`.

## JSON Contract

With `--json`, stdout is valid JSON only and human logs go to stderr.

JSON includes:

- `mode`
- `branch`
- `base_branch`
- `title`
- `pr_number`
- `pr_url`
- `action_taken`
- `stop_reason`

Usage examples:

    repo-automation/bin/pr-create --branch=feature/mixed-change --base=main --title="Mixed change" --body-file=/path/to/body.md
    repo-automation/bin/pr-create --branch=feature/mixed-change --base=main --title="Mixed change" --body="Short body text"
    repo-automation/bin/pr-create --dry-run --branch=feature/mixed-change --base=main --title="Mixed change" --body="Short body text"
