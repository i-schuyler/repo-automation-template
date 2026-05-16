# Helper Contracts

`repo-automation/helper-metadata.json` is the pinned inventory source for current public helpers.

This doc is the compact human reference for helper routing, check cost, state routing, fixture shape, and stream contracts.
If it overlaps a deeper contract doc, the deeper doc remains authoritative:

- command shape: `repo-automation/docs/command-shape.md`
- output modes: `repo-automation/docs/output-modes.md`
- config schema: `repo-automation/docs/config.md`
- managed files: `repo-automation/docs/managed-files.md`

## Public helper matrix

| Family | Route | Cost | Notes |
| --- | --- | --- | --- |
| docs PR | `add-doc-pr` | low | docs-only boundary, plan-first, no merge/push by default |
| inventory | `managed-file-check`, `managed-file-add` | low | targeted review/update for managed paths |
| readiness | `github-settings-check`, `starter-template-ready`, `automation-freshness` | low/med | read-only inventory/readiness checks |
| audit | `repo-doctor`, `run-tests`, `shellcheck-ci-parity` | high | umbrella or broad-check helpers |
| PR flow | `pr-create`, `pr-finish`, `branch-cleanup`, `codex-slice-preflight`, `repo-flow` | med/high | git and GitHub coordination helpers |
| artifacts | `post-codex-packet`, `repo-zip`, `evidence-bundle`, `ci-log-dump` | med | uploadable or log artifact helpers |
| status | `status-packet`, `failure-log`, `touched-files`, `ci-status`, `ci-watch` | low/med | compact read-only state helpers |
| release/report | `prepare-release`, `repo-automation-report-upstream`, `repo-automation-install` | med/high | release, reporting, and install helpers |

## Planned routing/state rows

| Name | State | Route | Public | Notes |
| --- | --- | --- | --- | --- |
| `status-card` | planned | state card | no | placeholder for later status presentation work |
| `review-pack` | planned | review bundle | no | placeholder for later review packet work |
| `repair-prompt` | planned | repair prompt | no | placeholder for later recovery flow work |
| `submit` | planned | submit action | no | placeholder for later submission flow work |
| `autopilot plan-only` | planned | plan-only | no | placeholder for later autopilot planning flow |

## CI failure taxonomy

| Status | Meaning | Typical next step |
| --- | --- | --- |
| `fail` | blocker | fix the helper or docs first |
| `warn` | non-blocking drift | rerun with better context or accept the warning |
| `skip` | not available in this checkout | provide the missing prerequisite or a different repo |
| `pass` | expected result | no action |

## Check-cost tiers

| Tier | What it means |
| --- | --- |
| `low` | local, cheap, usually phone-safe |
| `medium` | local plus light git/GitHub reads |
| `high` | broad, slow, or umbrella-style validation |

## GitHub CLI fixtures

| Fixture | Used by |
| --- | --- |
| `GH_STUB_PR_VIEW_*` | PR identity and state snapshots |
| `GH_STUB_PR_CHECKS_JSON` / `GH_STUB_PR_CHECKS_SEQUENCE_FILE` | repeated checks polling |
| `GH_STUB_RUN_LIST_JSON` / `GH_STUB_RUN_VIEW_*` | CI log discovery and log capture |
| `GH_STUB_PR_MERGE_*` | merge-path guardrails |
| `GH_STUB_PR_CREATE_*` | PR creation contract checks |

The helper contracts use these fixtures only in smoke tests; production helpers still call the real `gh` CLI when GitHub access is available.

## Artifact safety

| Helper family | Artifact rule |
| --- | --- |
| `post-codex-packet`, `repo-zip`, `evidence-bundle`, `ci-log-dump` | write only to the requested artifact path or temp evidence area |
| `failure-log`, `status-packet`, `touched-files`, `ci-status`, `ci-watch` | read-only, no artifact writes |
| `repo-automation-install` | writes the target repo only, never the source repo |

## Config schema touchpoints

| Helper | Config keys |
| --- | --- |
| `branch-cleanup`, `codex-slice-preflight`, `pr-create`, `pr-finish`, `repo-flow` | branch, remote, and preflight settings |
| `repo-doctor`, `repo-automation-install` | install, profile, branch, and provider settings |
| `starter-template-ready` | starter-template readiness and docs index settings |
| `managed-file-check`, `managed-file-add` | none; they read the repo inventory directly |

## Stream contract

| Mode | stdout | stderr |
| --- | --- | --- |
| default human | success summary or artifact path | failures and warnings |
| `--quiet` | success is silent | first actionable failure only |
| JSON | valid JSON only | fatal wrapper errors only |

`--help` always writes usage to stdout.
