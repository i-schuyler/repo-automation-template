# Script Routing

This doc is the source of truth for the routing matrix. [Helper Contracts](helper-contracts.md) summarizes the public surface.

| Need | Preferred helper | Phone-safe? | Writes files? | Writes git? | Network? | Broad checks? | Next helper |
| --- | --- | --- | --- | --- | --- | --- | --- |
| docs-only PR | `add-doc-pr` | yes | yes | yes | no | no | `pr-create` |
| mixed code/docs/test PR | `pr-create` | no | yes | yes | yes | maybe | `run-tests` |
| pre-Codex branch setup | `codex-slice-preflight` | yes | no | no | no | no | `branch-cleanup` |
| post-Codex review packet | `post-codex-packet` | no | yes | no | no | no | `status-packet` |
| current status packet | `status-packet` | yes | no | no | no | no | `ci-status` |
| CI status check | `ci-status` | yes | no | no | yes | no | `ci-watch` |
| CI watch | `ci-watch` | no | no | no | yes | no | `failure-log` |
| CI failure evidence | `ci-log-dump` | no | yes | no | yes | no | `failure-log` |
| merge and cleanup | `pr-finish` | no | yes | yes | yes | maybe | `branch-cleanup` |
| release prep | `prepare-release` | no | yes | yes | no | yes | `repo-doctor` |
| downstream install/update | `repo-automation-install` | no | yes | no | no | no | `starter-template-ready` |
| repo snapshot | `repo-zip` | yes | yes | no | no | no | `evidence-bundle` |
| final audit/archive | `evidence-bundle` | no | yes | no | yes | no | `status-packet` |
| status-card | `status-card` | yes | no | no | no | no | `status-packet` |
| review-pack for ChatGPT | `review-pack` | yes | yes | no | no | no | `status-card` |
| review-pack for Codex | `review-pack` | yes | yes | no | no | no | `repair-prompt` |
| repair-prompt | `repair-prompt` | yes | yes | no | no | no | `add-doc-pr` |
| guarded submit | `submit` | no | yes | yes | yes | maybe | `pr-finish` |
| autopilot plan-only | `autopilot plan-only` | yes | no | no | no | no | `status-packet` |

`review-pack --target=codex` and `repair-prompt --target=codex` are artifact-only planned routes; they do not invoke Codex.
