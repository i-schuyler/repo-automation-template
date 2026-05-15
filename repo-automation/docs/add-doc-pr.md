# Add Doc PR

`repo-automation/bin/add-doc-pr` is a terminal helper for preparing docs-only pull requests with explicit safety checks.

Default behavior is plan-only. It does not commit, push, or create a PR unless `--create-pr` is explicitly supplied.

`--dry-run` performs validation and shows what would happen without creating commits, pushes, or PRs.

Value flags use `--flag=<value>` syntax. Space-separated values are rejected.

## Docs-Only Boundary

Default allowed paths:

- `README.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `SUPPORT.md`
- `docs/`
- `examples/downstream/docs/`
- `.github/pull_request_template.md`
- `.github/ISSUE_TEMPLATE/`

By default, changes under `repo-automation/bin/`, `repo-automation/tests/`, `.github/workflows/`, `VERSION`, `LICENSE`, and `.repo-automation.conf` are blocked.

Use `--allow=<FILE_OR_DIR>` to add one or more additional allowed paths for a single run.

If any changed file is outside the allowed set, the helper stops and reports blocked paths.

## PR Creation Gate

`--create-pr` requires:

- a valid target branch
- docs-only/public-safe changed files
- `--commit-message`
- `--title`
- either `--body-file` or `--body`
- passing checks (`git diff --check` and `repo-automation/bin/run-tests`)

The helper does not merge PRs and does not delete branches.

## JSON Contract

With `--json`, stdout is valid JSON only and human logs go to stderr.

JSON includes:

- `mode`
- `branch`
- `base_branch`
- `allowed_paths`
- `changed_files`
- `blocked_files`
- `checks_run`
- `commit_created`
- `pushed`
- `pr_created`
- `pr_number`
- `pr_url`
- `action_taken`
- `stop_reason`

Usage examples:

    repo-automation/bin/add-doc-pr --plan --json
    repo-automation/bin/add-doc-pr --dry-run --branch=docs/my-doc-update
    repo-automation/bin/add-doc-pr --plan --allow=templates/
    repo-automation/bin/add-doc-pr --create-pr --branch=docs/my-doc-update --commit-message="docs: update contract wording" --title="Docs: update contract wording" --body-file=/path/to/body.md
