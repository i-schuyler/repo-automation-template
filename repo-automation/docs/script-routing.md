# Script Routing

This doc is the source of truth for the routing matrix. [Helper Contracts](helper-contracts.md) summarizes the public surface.

PR-first review remains the normal path; use `post-codex-review` for the concise operator handoff, `post-codex-packet` when you need the zip packet, and `repo-zip`, `evidence-bundle`, and `repo-flow status-card` before the fallback review artifact helpers.
`review-pack --target=review` is lean by default; use `--full` only when you need the heavier evidence bundle/repo snapshot.

| Need | Preferred helper | Phone-safe? | Writes files? | Writes git? | Network? | Broad checks? | Next helper |
| --- | --- | --- | --- | --- | --- | --- | --- |
| docs-only PR | `add-doc-pr` | yes | yes | yes | no | no | `pr-create` |
| mixed code/docs/test PR | `pr-create` | no | yes | yes | yes | maybe | `run-tests` |
| PR body contract | `pr-body-check` | yes | no | no | no | no | `pr-create`, CI PR validation |
| pre-Codex branch setup | `codex-slice-preflight` | yes | no | no | no | no | `branch-cleanup` |
| first-run tooling audit | `check-tooling` | yes | no | no | no | no | `repo-doctor` |
| portability drift audit | `check-portability` | yes | no | no | no | yes | `repo-doctor` |
| post-Codex review packet | `post-codex-packet` | no | yes | no | no | no | `status-packet` |
| current status packet | `status-packet` | yes | no | no | no | no | `ci-status` |
| CI status check | `ci-status` | yes | no | no | yes | no | `ci-watch` |
| CI watch | `ci-watch` | no | no | no | yes | no | `failure-log` |
| CI failure evidence | `ci-log-dump` | no | yes | no | yes | no | `failure-log` |
| CI failure artifact assembly | `ci-failure-artifacts` | yes | yes | no | no | no | `repo-doctor` |
| advisory debt report | `contract-debt-report` | yes | yes | no | no | yes | `repo-doctor` |
| review gate and merge | `repo-flow merge`, `pr-finish` | no | yes | yes | yes | maybe | `branch-cleanup` |
| release prep | `prepare-release` | no | yes | yes | no | yes | `repo-doctor` |
| downstream install/update | `repo-automation-install` | no | yes | no | no | no | `starter-template-ready` |
| repo snapshot | `repo-zip` | yes | yes | no | no | no | `evidence-bundle` |
| final audit/archive | `evidence-bundle` | no | yes | no | yes | no | `status-packet` |
| status-card | `repo-flow status-card` | yes | no | no | read-only network | no | contextual: `branch-cleanup`, `repo-flow`, `ci-watch`, `pr-finish`, or `failure-log` |
| fallback review-pack | `review-pack --target=review` | yes | yes | no | no | no | `repo-flow status-card` |
| fallback review-pack for Codex | `review-pack --target=codex` | yes | yes | no | no | no | `repair-prompt` |
| repair-prompt | `repair-prompt` | yes | yes | no | no | no | `add-doc-pr` |
| guarded submit | `repo-flow submit` | no | yes | yes | yes | maybe | `repo-flow merge`; uses `pr-create` for canonical PR body validation and appends update logs to existing PR bodies by default |
| slice-handoff dry-run | `slice-handoff --dry-run` | yes | no | no | no | no | `status-packet` |

`review-pack --target=codex` and `repair-prompt --target=codex` are artifact-only routes; they do not invoke Codex.
