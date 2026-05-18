# Docs Index

Start here if you are evaluating, copying, installing, or contributing to `repo-automation-template`.

## Top-Level Project Files

- [README](../README.md)
- [Changelog](../CHANGELOG.md)
- [Contributing](../CONTRIBUTING.md)
- [Support](../SUPPORT.md)
- [License](../LICENSE)
- [Version](../VERSION)
- [Pull Request Template](../.github/pull_request_template.md)
- [Automation Bug Issue Form](../.github/ISSUE_TEMPLATE/automation-bug.yml)
- [Automation Feature Issue Form](../.github/ISSUE_TEMPLATE/automation-feature.yml)

## Canonical Docs Order

1. [Decisions](DECISIONS.md)
2. [Known Limitations](KNOWN_LIMITATIONS.md)
3. [Install Models](INSTALL_MODELS.md)
4. [Downstream Feedback](DOWNSTREAM_FEEDBACK.md)
5. [Versioning](VERSIONING.md)
6. [Version Modes](../repo-automation/docs/version-modes.md)
7. [Repo Automation Config](../repo-automation/docs/config.md)
8. [Managed Files](../repo-automation/docs/managed-files.md)
9. [Helper Contracts](../repo-automation/docs/helper-contracts.md)
10. [Script Routing](../repo-automation/docs/script-routing.md)
11. [CI Failure Taxonomy](../repo-automation/docs/ci-failure-taxonomy.md)
12. [Check-Cost Tiers](../repo-automation/docs/check-cost-tiers.md)
13. [Workflow State Machine](../repo-automation/docs/workflow-state-machine.md)
14. [GitHub CLI Fixtures](../repo-automation/docs/github-cli-fixtures.md)
15. [Artifact Safety](../repo-automation/docs/artifact-safety.md)
16. [Config Schema](../repo-automation/docs/config-schema.md)
17. [Exit-Code / Stream Contract](../repo-automation/docs/exit-code-stream-contract.md)
18. [Shared Bash Library](../repo-automation/docs/common-library.md)
19. [Branch Cleanup](../repo-automation/docs/branch-cleanup.md)
20. [Codex Slice Preflight](../repo-automation/docs/codex-slice-preflight.md)
21. [PR Finish](../repo-automation/docs/pr-finish.md)
22. [Add Doc PR](../repo-automation/docs/add-doc-pr.md)
23. [PR Create](../repo-automation/docs/pr-create.md)
24. [Repo Flow](../repo-automation/docs/repo-flow.md)
25. [Report Upstream](../repo-automation/docs/repo-automation-report-upstream.md)
26. [Repo Doctor](../repo-automation/docs/repo-doctor.md) for read-only health checks and the repo-root artifact guard
27. [GitHub Settings Check](../repo-automation/docs/github-settings-check.md)
28. [Failure Log](../repo-automation/docs/failure-log.md)
29. [Status Packet](../repo-automation/docs/status-packet.md)
30. [Post Codex Packet](../repo-automation/docs/post-codex-packet.md)
31. [Post Codex Review](../repo-automation/docs/post-codex-review.md)
31. [Evidence Bundle](../repo-automation/docs/evidence-bundle.md)
32. [Review Pack](../repo-automation/docs/review-pack.md)
33. [Repair Prompt](../repo-automation/docs/repair-prompt.md)
34. [Touched Files](../repo-automation/docs/touched-files.md)
35. [CI Status](../repo-automation/docs/ci-status.md)
36. [CI Watch](../repo-automation/docs/ci-watch.md)
37. [CI Log Dump](../repo-automation/docs/ci-log-dump.md)
38. [ShellCheck CI Parity](../repo-automation/docs/shellcheck-ci-parity.md)
39. [Starter Template Readiness](../repo-automation/docs/starter-template-readiness.md)
40. [Repo Automation Install](../repo-automation/docs/repo-automation-install.md)
41. [Starter Template Smoke Workflow](../repo-automation/docs/testing.md)
42. [Command Shape](../repo-automation/docs/command-shape.md)
43. [Output Modes](../repo-automation/docs/output-modes.md)
44. [Testing](../repo-automation/docs/testing.md)
45. [Roadmap](ROADMAP.md)
46. [Drift Ledger](DRIFT_LEDGER.md)
47. [Monetization](MONETIZATION.md)
48. [Workflow Audit Checklist](WORKFLOW_AUDIT_CHECKLIST.md)
49. [Downstream Install Contract](../repo-automation/docs/downstream-install-contract.md)
50. [Issue Escalation](../repo-automation/docs/issue-escalation.md)
51. [Source Provenance](../repo-automation/docs/source-provenance.md)

## Downstream Examples

- [Example Downstream Config](../examples/downstream/.repo-automation.conf.example)
- [Example Downstream Repo Automation README](../examples/downstream/docs/repo-automation/README.md)

## Start Here

- New users should read the [README](../README.md), then [Known Limitations](KNOWN_LIMITATIONS.md), then [Install Models](INSTALL_MODELS.md).
- Downstream maintainers should read [Downstream Feedback](DOWNSTREAM_FEEDBACK.md) before filing upstream issues.
- Maintainers changing versions should read [Versioning](VERSIONING.md) and [Version Modes](../repo-automation/docs/version-modes.md) before editing `VERSION`, `CHANGELOG.md`, or downstream examples.
- Contributors should read [Contributing](../CONTRIBUTING.md) and use the issue forms.
- For review fallbacks, prefer the PR-first helpers first and use [Review Pack](../repo-automation/docs/review-pack.md) only when you explicitly need an artifact bundle or Codex prompt.
