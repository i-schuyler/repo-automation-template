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
| PR finish default mode | `scripts/pr-finish` defaults to status/plan-only behavior |
| PR finish merge flag | `scripts/pr-finish` requires explicit `--merge` |
| PR finish merge safety gate | `scripts/pr-finish` must not merge pending, failing, draft, closed, missing-check, or ambiguous PR states |
| PR finish checks boundary | `scripts/pr-finish` must not bypass required checks |
| PR finish branch-delete boundary | branch deletion after merge must be explicit |
| Add-doc-pr default mode | `scripts/add-doc-pr` defaults to plan-only behavior |
| Add-doc-pr docs-only boundary | `scripts/add-doc-pr` must enforce docs-only changed-file boundaries by default |
| Add-doc-pr merge boundary | `scripts/add-doc-pr` must not merge PRs |
| Add-doc-pr PR-create flag | `scripts/add-doc-pr` must not create PRs unless explicit `--create-pr` is supplied |
| Report-upstream default mode | `scripts/repo-automation-report-upstream` defaults to preview/plan-only behavior |
| Report-upstream preview gate | `scripts/repo-automation-report-upstream` must preview issue body before submit |
| Report-upstream browser boundary | `scripts/repo-automation-report-upstream` must never require opening a browser |
| Report-upstream redaction boundary | `scripts/repo-automation-report-upstream` must stop on likely secret markers before submission |
| Report-upstream submit flag | `scripts/repo-automation-report-upstream` must not submit unless explicit `--submit` is supplied |
| Repo-doctor default mode | `scripts/repo-doctor` defaults to read-only diagnostics |
| Repo-doctor mutation boundary | `scripts/repo-doctor` must not mutate git state or create GitHub objects |
| Repo-doctor JSON contract | `scripts/repo-doctor --json` must emit valid JSON only on stdout |
| Installer default mode | `scripts/repo-automation-install` defaults to plan-only behavior |
| Installer target mutation boundary | `scripts/repo-automation-install` must not commit, push, or create PRs in target repos |
| Installer local overrides boundary | downstream local overrides must be preserved |
| Installer CI install boundary | CI workflow installation is optional and not default |
| Installer remote fallback contract | unsupported downstream origins must normalize `EXPECTED_REMOTE_URL` to `""` rather than copying local/file/HTTPS URLs |
| Installer contract audit | installer smoke tests must audit downstream config loading, executable scripts, preserved local overrides, and repo-doctor quick/no-run-tests behavior in temporary repos |
| Add-doc-pr baseline fixture | add-doc-pr smoke fixtures must commit the full automation baseline before docs-only boundary tests |
| Workflow audit checklist seed | `docs/WORKFLOW_AUDIT_CHECKLIST.md` is a public coming-soon product seed, not a paid or private artifact |

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


- [LOCKED] Long-running diagnostic scripts should default to compact summaries, write details to temp logs, and expose `--explain` for full human detail.
- [LOCKED] JSON diagnostic output should support levels such as `fail`, `warn`, and `all` so Codex can consume only actionable details by default.
- [LOCKED] Output-mode implementation starts with `scripts/run-tests` and `scripts/repo-doctor` before expanding to other scripts.
- [LOCKED] Timeout-guarded diagnostics should default to compact summaries, use per-check timeout guards when `timeout` exists, and warn once before continuing without guards when it does not.
