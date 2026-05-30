# Helper Contracts

`repo-automation/helper-metadata.json` is the pinned inventory source for current public helpers.

This doc is the top-level public helper contract matrix.
It summarizes the public surface and points to the deeper source-of-truth docs:

- script routing: `repo-automation/docs/script-routing.md`
- CI failure taxonomy: `repo-automation/docs/ci-failure-taxonomy.md`
- check-cost tiers: `repo-automation/docs/check-cost-tiers.md`
- workflow state machine: `repo-automation/docs/workflow-state-machine.md`
- GitHub CLI fixtures: `repo-automation/docs/github-cli-fixtures.md`
- artifact safety: `repo-automation/docs/artifact-safety.md`
- config schema: `repo-automation/docs/config-schema.md`
- exit-code / stream contract: `repo-automation/docs/exit-code-stream-contract.md`
- command shape: `repo-automation/docs/command-shape.md`
- output modes: `repo-automation/docs/output-modes.md`
- slice handoff: `repo-automation/docs/slice-handoff.md`
- managed files: `repo-automation/docs/managed-files.md`

Use the linked doc for route-specific or contract-specific rules.

## Public helper matrix

| Family | Route | Cost tier | Notes |
| --- | --- | --- | --- |
| docs PR | `add-doc-pr` | mutating | docs-only boundary, plan-first, no merge/push by default |
| inventory | `managed-file-check`, `managed-file-add` | targeted-local / mutating | managed-path review/update helpers |
| readiness | `github-settings-check`, `starter-template-ready`, `automation-freshness`, `check-tooling` | instant / network-read | read-only inventory/readiness checks |
| audit | `repo-doctor`, `run-tests`, `shellcheck-ci-parity`, `check-portability`, `pr-body-check` | broad-local / targeted-local / instant | umbrella or broad-check helpers; `shellcheck-ci-parity` derives its helper paths from `repo-automation/helper-metadata.json`; `check-portability` derives its targets from helper metadata, workflows, and tracked executable files; `pr-body-check` enforces the PR body contract |
| audit/report | `contract-debt-report` | broad-local | advisory maintainability and contract debt report; warns on metadata, manifest, coverage, and refactor debt without failing CI |
| PR flow | `pr-create`, `pr-finish`, `branch-cleanup`, `codex-slice-preflight`, `repo-flow` | mutating / targeted-local | git and GitHub coordination helpers; includes read-only `repo-flow status-card`, guarded `repo-flow submit`, and explicit `repo-flow merge` |
| artifacts | `post-codex-review`, `post-codex-packet`, `repo-zip`, `evidence-bundle`, `ci-log-dump`, `ci-failure-artifacts` | instant / mutating / CI-owned | compact review summaries, uploadable packets, or log artifact helpers; `ci-failure-artifacts` assembles a flat CI failure bundle for phone/AI handoff |
| review/repair | `review-pack`, `repair-prompt` | mutating | fallback review packet / repair prompt helpers; `review-pack --target=review` is lean by default, `--full` builds the heavier evidence bundle/repo-zip artifact, and `review-pack --target=codex` and `repair-prompt --target=codex` create local artifacts only |
| status | `status-packet`, `failure-log`, `touched-files`, `ci-status`, `ci-watch` | instant / network-read / CI-owned | compact read-only state helpers; `status-packet --explain` is the FINAL SUMMARY handoff form |
| release/report | `prepare-release`, `repo-automation-report-upstream`, `repo-automation-install` | mutating / network-read | release, reporting, and install helpers |

## Planned routing/state rows

| Name | State | Route | Public | Notes |
| --- | --- | --- | --- | --- |
| `submit` | implemented | `repo-flow submit` | no | guarded explicit-path commit / PR helper |
| `merge` | implemented | `repo-flow merge` | no | explicit review-gated merge/delete/sync helper |
| `slice-handoff dry-run` | implemented | `slice-handoff --dry-run` | no | non-executing slice-handoff validator |

`repo-flow status-card` is the public read-only status screen that lives under the `repo-flow` helper.
PR-first review remains the normal path; `review-pack` is a fallback artifact helper when you explicitly need a lean packet, full evidence bundle, or prompt artifact.

## CI failure taxonomy

| Status | Meaning | Typical next step |
| --- | --- | --- |
| `pass` | expected result | no action |
| `wait` | pending state | wait for checks or CI to settle |
| `skip` | no-checks / unavailable | do not treat as failure |
| `fail` | blocker | fix the helper or docs first |

## Check-cost tiers

| Tier | What it means |
| --- | --- |
| `instant` | smallest read-only check, usually phone-safe |
| `targeted-local` | local and scoped to a narrow path or state |
| `network-read` | GitHub/API read only, no repo mutation |
| `broad-local` | broader local validation |
| `CI-owned` | waits on or inspects CI-owned work |
| `mutating` | writes files, git state, or artifacts |

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
| `--json` | valid JSON only | fatal wrapper errors only |
| `--explain` | detailed operator output with a required FINAL SUMMARY tail block when supported | details and warnings |

`--help` always writes usage to stdout.

`--packet` is an action modifier; helpers that support it report the packet path through compact output, `--json`, or the `--explain` final summary.
