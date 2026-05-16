# CI Failure Taxonomy

This doc is the source of truth for CI classifier labels. [Helper Contracts](helper-contracts.md) summarizes the public surface.

| Label | Meaning | Smallest useful follow-up |
| --- | --- | --- |
| `pass` | checks completed successfully | none |
| `wait: checks-pending` | check is still pending | keep waiting or re-run watch |
| `skip: no-checks` | no checks exist for this checkout | do not treat as failure |
| `fail: docs-check` | docs drift or broken docs link | fix the doc or index entry |
| `fail: run-tests` | local test failure | inspect the failing test slice |
| `fail: shellcheck` | shell lint failure | inspect the reported shell line |
| `fail: version-consistency` | version/config drift | update the versioned files together |
| `fail: managed-files` | manifest/installer coverage drift | fix the managed-file inventory |
| `fail: output-contract` | stream or JSON contract drift | compare stdout/stderr behavior |
| `fail: github-access` | GitHub auth/API/TLS/network failure | fix access, not code |
| `fail: no-pr` | no PR was found | create-or-reuse the branch PR |
| `fail: ambiguous-pr` | more than one PR matched | narrow the branch/PR selector |
| `fail: unknown-ci` | CI shape is not recognized | capture evidence and classify manually |

Rules:

- Pending checks are `wait`, not `fail`.
- Missing checks are `skip`, not `fail`.
- GitHub auth/API/TLS/network failures are tooling/access failures, not code failures.
- Classifiers should include the smallest useful excerpt or the next command.
- These labels feed `status-card`, `watch`, `diagnosis`, `repair-prompt`, `submit`, and `autopilot plan` output.
