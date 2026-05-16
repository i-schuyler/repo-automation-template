# GitHub CLI Fixtures

This doc is the source of truth for shared `gh` fixture cases. [Helper Contracts](helper-contracts.md) summarizes the public surface.

## Shared coverage

| Fixture case | Coverage |
| --- | --- |
| `gh pr view` success | PR identity, branch, and state snapshots |
| no PR found | missing PR path |
| ambiguous PR selection | multi-PR path |
| pending checks | `wait` / watch behavior |
| passing checks | success path |
| failing checks with named workflow | classifier and diagnosis path |
| failed run log with wrapped excerpt | log-dump and evidence path |
| auth failure | `github-access` failure |
| API/network failure | `github-access` failure |
| merge blocked | guarded merge refusal |
| merge succeeds | guarded merge success |

## Fixture rules

- Fixture output stays small and readable.
- Helper tests should share fixture builders instead of inventing conflicting `gh` stubs.
- First-failure and classifier tests should use shared fixtures.
- `status-card`, `submit`, `repair-prompt`, and `autopilot` tests reuse the same state fixtures.
