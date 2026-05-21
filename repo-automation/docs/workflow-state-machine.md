# Workflow State Machine

This doc is the source of truth for PR-loop state routes. [Helper Contracts](helper-contracts.md) summarizes the public surface.

| State | Route |
| --- | --- |
| repo-flow status-card | read-only observer / state screen |
| dirty tree | `fail: dirty-worktree` |
| no branch PR | create-or-reuse-pr path |
| PR exists | push/watch/diagnose path |
| guarded submit | explicit-path commit, then create-or-reuse-pr path |
| checks pending | `wait` |
| checks missing | `skip: no-checks` or configured no-checks behavior |
| checks failed | diagnose |
| GitHub unavailable | `fail: github-access` |
| CI green + merge requested | merge |
| after merge | sync main when requested |
| same-PR repair | patch same branch, never open a replacement PR by default |

Rules:

- Merge remains explicit and guarded.
- API failures do not trigger code patches.
- No helper silently creates a no-op commit or empty PR.
- Repair loops stay on the same PR branch unless the user explicitly changes direction.
- `repo-flow status-card` never mutates repo state.
- `repo-flow status-card` can recommend create branch, commit changes, dry-run `repo-flow`, `ci-watch --poll-seconds=5`, `pr-finish --merge --delete-branch --sync-main`, or inspect CI failure.
- `repo-flow submit` stages only explicit paths or current staged files, then delegates to the PR create-or-reuse path.
- `review-pack` is a fallback uploadable review packet; use the PR-first review path before it. It is lean by default, and `--full` opts into the heavier evidence bundle/repo-zip artifact.
- `review-pack --target=codex` and `repair-prompt --target=codex` create artifacts only and do not invoke Codex.
- `repo-flow autopilot --plan-only` is read-only and does not mutate repo state.
