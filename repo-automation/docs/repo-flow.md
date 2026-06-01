# Repo Flow

`repo-automation/bin/repo-flow` is a first-pass helper for idempotent PR integration on the current branch.

It verifies the branch is not `main`, checks the worktree, reports ahead/behind versus `origin/main`, pushes the current branch when needed, and either reuses or creates the branch PR.

`repo-automation/bin/repo-flow submit` is the guarded phone-first commit entrypoint.
Use `--all` when all Codex-edited files in the current repo should be included, `--modified` for tracked modified/deleted/renamed paths from both staged and unstaged diffs, `--paths=<path[,path...]>` for explicit repo-relative paths, or `--staged` to commit the current index.
Prefer `--all` for Codex/operator submits when you want every non-ignored working-tree change included.
Prefer `--modified` instead of shell-building a `--paths` CSV for tracked edits.
It refuses absolute paths, `..`, default-branch submits, and any unrequested dirty or untracked worktree changes before staging when `--paths` is used.
When submit stops for unrequested worktree changes, human failure output prints a compact `unrequested_paths=...` excerpt before the final summary.
`--modified` blocks new files, including pre-staged additions and untracked paths; use `--paths=<path>` or `--staged` explicitly for new files.
`--all` stages all non-ignored working-tree changes with `git add -A -- .` and is mutually exclusive with `--modified`, `--paths`, and `--staged`.
For most PRs, use the generated body from `repo-flow`; it is the default and easiest path. Use `--body-file=<path>` only for a human-authored custom PR body that passes `repo-automation/bin/pr-body-check`.
Use `--review-request-file=<path>` or `--review-request-id=<id>` when `repo-flow submit --explain` should print a PR-review handoff after the PR exists.
`--review-request-file` reads a regular readable non-empty text template.
`--review-request-id` resolves `.prompts/<id>.md` under the repo root; IDs are conservative basenames with letters, digits, underscores, and hyphens only, and no slashes, leading dot, leading dash, shell metacharacters, or `..`.
The two review-request flags are mutually exclusive.
If neither is supplied, submit output is unchanged and no `PR REVIEW REQUEST` block is invented.
Review-request templates support these repo-flow placeholders:

- `<PR_URL>`: the created or existing PR URL
- `<TITLE>`: the submit commit message passed with `--message`
- `<BRANCH>`: the current submit branch

`repo-flow submit` does not support `<RUN_DIR>`; lower-layer submit has no stable run directory.
If the rendered text does not otherwise contain the PR URL, `repo-flow submit` appends a `PR URL: ...` line so the explain handoff is actionable.
On successful `--explain` runs with a review-request source, `repo-flow submit` writes `review-request.txt` and `pr-review-request-block.txt` artifacts under a temporary artifact directory, prints the `FINAL SUMMARY` first, then a blank line, then:

```text
===== PR REVIEW REQUEST =====
...
===== END PR REVIEW REQUEST =====
```

When `EXPECTED_REMOTE_URL` is set, a matching GitHub SSH alias remote is also accepted if `ssh -G` resolves the alias to `github.com` and the repo path matches `UPSTREAM_REPO_FULL_NAME`.
When `--body-file` is omitted, `repo-flow submit` generates the canonical PR body headings and routes the body through `repo-automation/bin/pr-create`. When it reuses an existing PR, it refreshes that canonical body in place so staged paths and stop notes stay current. The generated PR body re-entry hint is: `Review the PR, then run repo-automation/bin/repo-flow merge --explain`.
`--watch` hands off to the repo-native PR completion path with a bounded timeout and stops after CI is green; `--timeout=<seconds>` sets that limit.
When `--watch` is used, `repo-flow submit` pushes the current branch before PR lookup/create/watch.
`--diagnose-on-fail` is only forwarded with `--watch`.
`repo-automation/bin/repo-flow merge` is the explicit merge/delete/sync step after review. It uses the current PR by default, waits for the current head to be green, then merges, deletes the branch, and syncs `main`.
Successful merge explain summaries include the resolved `pr=<number>` and, when available, `url_or_stop=<pr_url>`. `pr=unknown` is reserved for cases where PR identity could not be resolved.
`repo-flow merge --explain` also prints a compact timing line and includes `elapsed_seconds=<n>` in the final summary.
It hands PR identity and timing back from `pr-finish` through a temporary `PR_FINISH_STATE_FILE`.
`pr-finish` is current-head-aware: missing or not-yet-attached checks stay pending until timeout, stale checks from older SHAs are ignored, and merges/deletes/syncs only happen after the current head is green.
Use `--explain` for the full human flow report; default success is compact `plan`, PR URL, or `pass`.
`--explain` ends with a compact `===== FINAL SUMMARY =====` handoff block.
For `submit --watch`, that handoff includes explicit `watched=` and `ci=` keys so the review step can see whether CI completed, failed, timed out, or is unknown.

`--dry-run` / `--plan` reports the flow without pushing or creating a PR.
`status-card` is a read-only state screen. It never pushes, creates a PR, watches CI, or mutates the repo.
`status-card` reports these human keys:

- `branch`
- `default`
- `worktree`
- `tracked_changed`
- `untracked`
- `range_vs_default`
- `ahead_behind`
- `pr`
- `checks`
- `next`

`status-card --json` emits valid JSON only.
GitHub lookup failures do not make `status-card` fail; local state still prints.

Usage examples:

    repo-automation/bin/repo-flow
    repo-automation/bin/repo-flow --dry-run
    repo-automation/bin/repo-flow --watch
    repo-automation/bin/repo-flow --watch --diagnose-on-fail
    repo-automation/bin/repo-flow --json
    repo-automation/bin/repo-flow submit --modified --message="update repo-flow docs"
    repo-automation/bin/repo-flow submit --all --message="include all Codex edits"
    repo-automation/bin/repo-flow submit --staged --message="commit staged work"
    repo-automation/bin/repo-flow submit --staged --message="commit staged work" --review-request-id=repo-review --explain
    repo-automation/bin/repo-flow submit --paths=README.md --message="commit docs" --review-request-file=.prompts/repo-review.md --explain
    repo-automation/bin/repo-flow submit --staged --message="commit staged work" --watch --timeout=900 --diagnose-on-fail --explain
    repo-automation/bin/repo-flow submit --paths=docs/repo-flow.md --message="update repo-flow docs"
    repo-automation/bin/repo-flow merge --explain
    repo-automation/bin/repo-flow status-card
    repo-automation/bin/repo-flow status-card --json

Recommended review flow: submit/watch, review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
