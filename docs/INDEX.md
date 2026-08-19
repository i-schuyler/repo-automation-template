# Docs Index

Start here if you are evaluating, copying, installing, or contributing to `repo-automation-template`.

## First-Read Map

- [Surface Map](SURFACE_MAP.md)
- [README](../README.md)
- [Known Limitations](KNOWN_LIMITATIONS.md)
- [Install Models](INSTALL_MODELS.md)
- [Downstream Feedback](DOWNSTREAM_FEEDBACK.md)

## Top-Level Project Files

- [README](../README.md)
- [Changelog](../CHANGELOG.md)
- [Contributing](../CONTRIBUTING.md)
- [Support](../SUPPORT.md)
- [License](../LICENSE)
- [Version](../VERSION.md)
- [Pull Request Template](../.github/pull_request_template.md)
- [Automation Bug Issue Form](../.github/ISSUE_TEMPLATE/automation-bug.yml)
- [Automation Feature Issue Form](../.github/ISSUE_TEMPLATE/automation-feature.yml)

## Canonical Docs Order

1. [Decisions](DECISIONS.md)
2. [Surface Map](SURFACE_MAP.md)
3. [Known Limitations](KNOWN_LIMITATIONS.md)
4. [Install Models](INSTALL_MODELS.md)
5. [Downstream Feedback](DOWNSTREAM_FEEDBACK.md)
6. [Versioning](VERSIONING.md)
7. [Version Modes](../repo-automation/docs/version-modes.md)
8. [Repo Automation Config](../repo-automation/docs/config.md)
9. [Managed Files](../repo-automation/docs/managed-files.md)
10. [Helper Contracts](../repo-automation/docs/helper-contracts.md)
11. [Script Routing](../repo-automation/docs/script-routing.md)
12. [CI Failure Taxonomy](../repo-automation/docs/ci-failure-taxonomy.md)
13. [Check-Cost Tiers](../repo-automation/docs/check-cost-tiers.md)
14. [Workflow State Machine](../repo-automation/docs/workflow-state-machine.md)
15. [GitHub CLI Fixtures](../repo-automation/docs/github-cli-fixtures.md)
16. [Artifact Safety](../repo-automation/docs/artifact-safety.md)
17. [Config Schema](../repo-automation/docs/config-schema.md)
18. [Exit-Code / Stream Contract](../repo-automation/docs/exit-code-stream-contract.md)
19. [Shared Bash Library](../repo-automation/docs/common-library.md)
20. [Branch Cleanup](../repo-automation/docs/branch-cleanup.md)
21. [Codex Slice Preflight](../repo-automation/docs/codex-slice-preflight.md)
22. [PR Finish](../repo-automation/docs/pr-finish.md)
23. [Add Doc PR](../repo-automation/docs/add-doc-pr.md)
24. [PR Create](../repo-automation/docs/pr-create.md)
25. [PR Body Check](../repo-automation/docs/pr-body-check.md)
26. [Repo Flow](../repo-automation/docs/repo-flow.md)
27. [Repo Zip](../repo-automation/docs/repo-zip.md)
28. [Report Upstream](../repo-automation/docs/repo-automation-report-upstream.md)
29. [Repo Doctor](../repo-automation/docs/repo-doctor.md) for read-only health checks and the repo-root artifact guard
30. [Check Tooling](../repo-automation/docs/check-tooling.md)
31. [Check Portability](../repo-automation/docs/check-portability.md)
32. [GitHub Settings Check](../repo-automation/docs/github-settings-check.md)
33. [Failure Log](../repo-automation/docs/failure-log.md)
34. [Status Packet](../repo-automation/docs/status-packet.md)
35. [Post Codex Packet](../repo-automation/docs/post-codex-packet.md)
36. [Post Codex Review](../repo-automation/docs/post-codex-review.md)
37. [Evidence Bundle](../repo-automation/docs/evidence-bundle.md)
38. [Review Pack](../repo-automation/docs/review-pack.md)
39. [Repair Prompt](../repo-automation/docs/repair-prompt.md)
40. [Touched Files](../repo-automation/docs/touched-files.md)
41. [CI Status](../repo-automation/docs/ci-status.md)
42. [Review Rebind](../repo-automation/docs/review-rebind.md)
43. [CI Watch](../repo-automation/docs/ci-watch.md)
44. [CI Log Dump](../repo-automation/docs/ci-log-dump.md)
45. [CI Failure Artifacts](../repo-automation/docs/ci-failure-artifacts.md)
46. [Contract Debt Report](../repo-automation/docs/contract-debt-report.md)
47. [ShellCheck CI Parity](../repo-automation/docs/shellcheck-ci-parity.md)
48. [Starter Template Readiness](../repo-automation/docs/starter-template-readiness.md)
49. [Repo Automation Install](../repo-automation/docs/repo-automation-install.md)
50. [Codex Status Timing UI Contract](../repo-automation/docs/contracts/codex-status-timing-ui-contract.md)
51. [Slice Handoff Final Summary UI Contract](../repo-automation/docs/contracts/slice-handoff-final-summary-contract.md)
52. [Starter Template Smoke Workflow](../repo-automation/docs/testing.md)
53. [Command Shape](../repo-automation/docs/command-shape.md)
54. [Output Modes](../repo-automation/docs/output-modes.md)
55. [Testing](../repo-automation/docs/testing.md)
56. [Downstream Install Contract](../repo-automation/docs/downstream-install-contract.md)
57. [Issue Escalation](../repo-automation/docs/issue-escalation.md)
58. [Source Provenance](../repo-automation/docs/source-provenance.md)
59. [Implementation Friction Ledger](../repo-automation/docs/implementation-friction-ledger.md)

## Maintainer and Reference Material

- [Maintainer Docs](maintainer/README.md)
- [Slice Handoff](../repo-automation/docs/slice-handoff.md)
- [Roadmap](maintainer/ROADMAP.md)
- [Repo Improvement Plan](maintainer/repo-improvement-plan.md)
- [Drift Ledger](maintainer/DRIFT_LEDGER.md)
- [Workflow Audit Checklist](maintainer/WORKFLOW_AUDIT_CHECKLIST.md)
- [Monetization](maintainer/MONETIZATION.md)
- [Implementation Friction Ledger](../repo-automation/docs/implementation-friction-ledger.md)

## Downstream Examples

- [Example Downstream Config](../examples/downstream/.repo-automation.conf.example)
- [Example Downstream Repo Automation README](../examples/downstream/docs/repo-automation/README.md)

## Start Here

- New users should read the [Surface Map](SURFACE_MAP.md), then the [README](../README.md), then [Known Limitations](KNOWN_LIMITATIONS.md), [Install Models](INSTALL_MODELS.md), and [Downstream Feedback](DOWNSTREAM_FEEDBACK.md).
- Downstream maintainers should read [Downstream Feedback](DOWNSTREAM_FEEDBACK.md) before filing upstream issues.
- Maintainers changing versions should read [Versioning](VERSIONING.md) and [Version Modes](../repo-automation/docs/version-modes.md) before editing `VERSION`, `CHANGELOG.md`, or downstream examples.
- Contributors should read [Contributing](../CONTRIBUTING.md) and use the issue forms.
- For review fallbacks, prefer the PR-first helpers first and use [Review Pack](../repo-automation/docs/review-pack.md) only when you explicitly need an artifact bundle or Codex prompt.
