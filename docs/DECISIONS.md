# Decisions

This file records public repo decisions for `repo-automation-template`.

## LOCKED

| Decision | Value |
| --- | --- |
| Repo name | `repo-automation-template` |
| Owner | `i-schuyler` |
| Visibility | public |
| License | Apache-2.0 |
| First implementation phase | docs-only bootstrap |
| Current version line | starts at 0.1.0 |
| Canonical install default | pinned/copy release bundle into downstream repos, with provenance recorded |
| Downstream feedback | downstream repos must include a clear process for filing upstream bugs/features against `i-schuyler/repo-automation-template` |
| Terminal upstream report helper | `scripts/repo-automation-report-upstream` is in the session DoD and must complete entirely from terminal using GitHub CLI, not by opening a browser, and must preview the generated issue body before submission |
| Downstream installed-context block | downstream installed docs must include a copyable installed-version/context block for upstream bug reports |
| Monetization CTAs | public monetization CTAs remain "coming soon" until a support/payment path is live |
| Version drift | version drift across root, docs, scripts, release metadata, and downstream examples is a tracked drift risk |
| Repo-local config entry point | `.repo-automation.conf` is the repo-local config entry point for future automation scripts |
| Shared Bash library source | repo-local scripts must source `scripts/lib/repo-automation-common.sh` instead of duplicating shared helper logic |
| Branch cleanup safety mode | branch cleanup defaults to plan-only and requires `--apply` for deletion |
| Branch cleanup safety boundary | branch cleanup must never delete remote branches or force-delete local branches |
| Codex preflight scope | codex slice preflight may create/check out a requested branch but must not create PRs or merge PRs |
| Preflight branch deletion flag | preflight branch deletion requires explicit `--delete-safe-stale` |
| JSON stdout contract | JSON mode stdout must be valid JSON only for branch cleanup and preflight |
| Config failure contract | invalid config and secret-scan failures must stop rather than silently falling back in behavior-changing scripts |
| Branch classification contract | branch cleanup must classify all local branches with explicit skipped reasons |
| CI permission boundary | CI must use minimal permissions by default |
| Test credential boundary | test scaffolds must be local-only and must not require private GitHub credentials |
| Version consistency gate | version consistency must be checked in CI before release automation exists |
| Preflight prompt contract | future Codex prompts should use `scripts/codex-slice-preflight` rather than repeating manual branch hygiene when the script exists |

## TENTATIVE

| Decision | Status |
| --- | --- |
| Git subtree support | deferred until script paths, config, and API stabilize |
| Template repository mode | may be enabled after v0.1.0 docs/script structure stabilizes |
| GitHub Sponsors | planned monetization path |
| Paid setup guide | planned monetization path |
| Done-for-you setup | planned monetization path |
| Workflow audit checklist product | planned monetization path |
| Sponsors-only early recipes/templates | planned monetization path |
| Paid non-GitHub provider support | planned monetization path |
