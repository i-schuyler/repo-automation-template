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
| Terminal upstream report helper | `scripts/repo-automation-report-upstream` is in the session DoD and must complete entirely from terminal using GitHub CLI, not by opening a browser |

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
