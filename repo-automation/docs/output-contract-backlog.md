# Output Contract Backlog

Purpose: public planning inventory for output-contract and child-failure-boundary work.
This is a backlog, not a guarantee that every helper already complies.

Source inputs:
- `repo-automation/helper-metadata.json`
- `repo-automation/docs/output-modes.md`
- current friction and the near-term plan

## How to use this backlog

- Start with the highest operator-risk helpers.
- Child-process opacity outranks cosmetic cleanup.
- Quiet-capable helpers need a QDE audit.
- JSON-capable helpers need valid stdout-only JSON and actionable failure fields.
- Helpers that wrap child commands need step, reason, fix, and artifact boundaries.
- Update this table after each output-contract slice.

## Backlog

| Helper | Role / risk | Output support | Current known gap | Next action | Priority lane |
| --- | --- | --- | --- | --- | --- |
| slice-handoff | high-risk umbrella; child-boundary failures can cross PR-submit trust boundaries | default/quiet/explain/json per contract slices | blocker/child-failure boundary hardened in PR #223, but broader output-mode migration is still incomplete | finish remaining output-contract gaps without broad renderer migration | near-term |
| codex-slice-preflight | preflight gate; failure clarity affects every execution lane | JSON/explain; quiet not declared in metadata | JSON/explain clarity still needs stronger failure fields and artifact paths | improve default/JSON/explain failure clarity | near-term |
| codex-run | core child output producer; final-output boundary is high risk | quiet; no JSON in metadata | child/final-output boundary and quiet QDE audit remain | harden child/final-output boundaries and audit quiet output | near-term |
| ci-log-dump | CI artifact helper | quiet/json in metadata | later output-contract target | tighten failure detail and artifact path clarity | later |
| run-tests | broad umbrella runner; operator guidance matters on failure | quiet/json in metadata | later output-contract target | improve step/reason/fix/artifact clarity | later |
| managed-file-check | inventory guardrail; failure diagnostics should be crisp | quiet/json in metadata | later output-contract target | keep changed-path failures actionable | later |
| pr-body-check | submit gate; body validation failures must be obvious | quiet/json in metadata | boundary diagnostics still matter on failures | preserve concise actionable failure output | near-term |
| repo-flow | submit/merge workflow; output contract affects release-risk paths | quiet/json in metadata | submit-output boundary clarity still needs explicit coverage | keep submit failures and output-contract failures step-specific | near-term |
| codex-status | status helper; operator readability matters | quiet/json in metadata | still needs consistent actionable failure fields | align failure envelopes with output-modes.md | later |
| check-portability | broad audit; helps catch portability-hostile output and paths | quiet/json in metadata | audit failures should stay concise and path-focused | keep portability failures artifact-aware | later |
| check-tooling | readiness helper; low-latency operator signal | quiet/json in metadata | failure clarity can still be improved | keep default/quiet failures actionable | later |
| branch-cleanup | preflight/worktree helper; failure impact is workflow-blocking | quiet/json in metadata | boundary failures should name the branch/worktree step | keep child and cleanup failures explicit | later |

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
