# Output Contract Backlog

Purpose: public implementation plan for output-contract and child-failure-boundary work.
This document is both the helper inventory and the compliance plan for the output-contract arc.

Source inputs:
- `repo-automation/helper-metadata.json`
- `repo-automation/docs/output-modes.md`
- current friction and the near-term plan

This table is intentionally complete across all public helpers; the compliance plan governs the output-contract arc, and helper order remains the first implementation sequence inside that plan.

## Compliance definition

A helper is compliant when its actual behavior matches its declared contract.
Compliance does not mean every helper supports every output mode.
Compliance means truthful metadata, aligned docs/help, focused tests for declared modes, and actionable failure boundaries.

## Five-layer compliance plan

1. Layer 1 — Inventory complete
   The public helper inventory exists and covers all public helpers from `helper-metadata.json`.
2. Layer 2 — Contract declared per helper
   Each helper records declared modes, child-process risk, success shape, failure shape, and test coverage status.
3. Layer 3 — Focused tests prove declared modes
   Tests cover default success/failure, quiet if supported, JSON if supported, mode conflicts, unknown args/flags, and child-failure boundaries when relevant.
4. Layer 4 — CI/checker prevents drift
   A lightweight checker should eventually verify metadata/docs/help/test coverage alignment.
5. Layer 5 — Verified status
   Helpers get marked verified/partial/needs-audit/blocked/not-applicable based on evidence.

## Compliance status vocabulary

- verified: evidence shows the helper matches its declared contract.
- partial: some declared behavior is proven, but coverage or contract alignment is incomplete.
- needs-audit: the helper needs review before a status claim is reliable.
- blocked: compliance work is prevented by an unresolved dependency or boundary.
- not-applicable: the field or layer does not apply to that helper.

## Small planning/testability slice

Next slice:
- add compliance status/rubric to this doc;
- add or prepare columns for declared-contract status, test coverage status, and compliance status;
- define a future lightweight checker, likely `output-contract-check`;
- do not implement the checker in this slice unless it is truly tiny and docs-only validation is insufficient.

## How to use this backlog

- The compliance plan governs the output-contract arc.
- Helper order remains the first implementation sequence inside that plan.
- Start with the highest operator-risk helpers.
- Child-process opacity outranks cosmetic cleanup.
- Quiet-capable helpers need a QDE audit.
- JSON-capable helpers need valid stdout-only JSON and actionable failure fields.
- Helpers that wrap child commands need step, reason, fix, and artifact boundaries.
- Each helper slice should advance a helper through the compliance layers rather than performing isolated output cleanup.
- Update this table after each output-contract slice.

## Backlog

| Helper | Role / risk | Output support | Current known gap | Next action | Priority lane |
| --- | --- | --- | --- | --- | --- |
| codex-slice-preflight | preflight gate | quiet=no json=yes | default/JSON/explain failure clarity still needs tighter fields and artifact paths | improve output clarity | near-term |
| codex-run | core child output producer | quiet=yes json=no | child/final-output boundaries and quiet QDE audit remain | harden child/final-output boundaries | near-term |
| ci-log-dump | CI artifact helper | quiet=yes json=yes | later output-contract target | tighten failure detail and artifact paths | near-term |
| run-tests | broad umbrella runner | quiet=yes json=yes | later output-contract target | improve step/reason/fix/artifact clarity | near-term |
| managed-file-check | inventory guardrail | quiet=yes json=no | later output-contract target | keep changed-path failures actionable | near-term |
| slice-handoff | high-risk umbrella; PR-submit trust boundary | quiet=yes json=no | blocker/child-failure boundary hardened in PR #223, broader output-mode migration still incomplete | finish remaining output-contract gaps | done-foundation |
| pr-body-check | submit gate | quiet=yes json=yes | boundary diagnostics still matter on failures | preserve concise actionable failure output | next |
| repo-flow | submit/merge workflow | quiet=no json=yes | submit-output boundary clarity still needs explicit coverage | keep submit and output-contract failures step-specific | next |
| codex-status | status helper | quiet=no json=yes | still needs consistent actionable failure fields | align failure envelopes with output-modes.md | later |
| check-portability | broad audit | quiet=yes json=yes | audit failures should stay concise and path-focused | keep portability failures artifact-aware | later |
| check-tooling | readiness helper | quiet=yes json=yes | failure clarity can still be improved | keep default/quiet failures actionable | later |
| branch-cleanup | preflight/worktree helper | quiet=no json=yes | boundary failures should name the branch/worktree step | keep child and cleanup failures explicit | later |
| add-doc-pr | docs PR helper | quiet=no json=yes | mutating docs flow still needs compact failure fields | keep docs-pr failures actionable | monitor |
| automation-freshness | inventory checker | quiet=no json=yes | manifest freshness failures should stay concise | keep path drift diagnostics short | monitor |
| ci-failure-artifacts | CI artifact helper | quiet=yes json=yes | artifact paths need consistent failure summaries | keep CI artifact failures explicit | monitor |
| ci-status | CI status helper | quiet=yes json=yes | status transitions need concise failure reasons | keep watched-state failures explicit | monitor |
| ci-watch | CI watcher | quiet=yes json=yes | watch/timeout failures need operator-facing next action | keep watch failures actionable | monitor |
| contract-debt-report | audit helper | quiet=yes json=yes | debt findings should stay parseable and narrow | keep findings and artifact paths clear | monitor |
| evidence-bundle | artifact helper | quiet=yes json=yes | bundle failures need clear artifact paths | keep bundle output path explicit | monitor |
| failure-log | status helper | quiet=no json=yes | failure-log summaries need compact operator wording | keep failure summaries concise | monitor |
| github-settings-check | readiness helper | quiet=yes json=yes | settings failures should stay narrow and actionable | keep targeted GitHub checks explicit | monitor |
| managed-file-add | inventory mutator | quiet=yes json=no | mutating path coverage should keep clear stop reasons | keep manifest/install updates explicit | monitor |
| repair-prompt | workflow helper | quiet=no json=no | prompt repair output stays intentionally minimal | keep prompt repair failures readable | monitor |
| post-codex-packet | artifact helper | quiet=yes json=yes | packet failures need clear artifact paths | keep packet output path explicit | monitor |
| post-codex-review | artifact helper | quiet=yes json=yes | review packet failures need clear artifact paths | keep review output path explicit | monitor |
| prepare-release | release helper | quiet=no json=yes | release gating needs compact actionable stops | keep release failures narrow | monitor |
| pr-create | PR helper | quiet=no json=yes | PR creation failures should stay step-specific | keep PR creation failures actionable | monitor |
| pr-finish | PR helper | quiet=no json=yes | merge/finalize failures need clear next action | keep finish failures narrow | monitor |
| repo-automation-install | installer | quiet=no json=yes | install failures should stay path-accurate | keep install path checks explicit | monitor |
| repo-automation-report-upstream | report helper | quiet=no json=yes | report failures should remain concise and actionable | keep upstream-report output narrow | monitor |
| repo-doctor | audit helper | quiet=yes json=yes | broad audit results still need compact failure detail | keep audit failures path-aware | monitor |
| repo-zip | artifact helper | quiet=yes json=yes | zip failures need stable artifact paths | keep archive paths explicit | monitor |
| slice-run-dir | artifact helper | quiet=yes json=yes | run-dir creation/cleanup failures need explicit step and path handling | keep run-dir lifecycle failures explicit | monitor |
| review-pack | artifact helper | quiet=no json=no | pack failures should stay narrow even without JSON/quiet | keep pack output readable | monitor |
| shellcheck-ci-parity | audit helper | quiet=no json=no | path-set reporting is enough; failure detail can stay concise | keep helper-path parity explicit | monitor |
| starter-template-ready | readiness helper | quiet=no json=yes | readiness failures should stay compact and user-facing | keep readiness checks narrow | monitor |
| status-packet | status/artifact helper | quiet=yes json=yes | packet/status failures need clear artifact paths | keep packet result explicit | monitor |
| touched-files | diff helper | quiet=yes json=yes | diff output should remain narrow and path-focused | keep changed-path output stable | monitor |

## Compliance tracking fields

- Declared contract: what the helper says it supports in docs/help/metadata.
- Test coverage: which declared behaviors have focused tests.
- Compliance status: verified / partial / needs-audit / blocked / not-applicable.

## Near-term order

1. codex-slice-preflight output clarity
2. codex-run child/final-output boundaries
3. ci-log-dump
4. run-tests
5. managed-file-check
6. remaining quiet-capable helpers by operator risk

## Do not do yet

- Do not add quiet support to every helper by default.
- Do not rewrite all helpers in one slice.
- Do not change helper metadata just to make the table look uniform.
- Do not run broad checks for docs-only table updates unless existing policy requires it.
