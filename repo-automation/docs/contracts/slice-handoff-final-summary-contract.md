# Slice Handoff Final Summary UI Contract

Status: approved design contract

Scope: `repo-automation/bin/slice-handoff`, operator-facing final summaries, paste-back behavior, and related contract tests.

## Purpose

`slice-handoff` owns workflow-aware operator handoff output.

The final summary must give the reviewer enough context to decide one of:

- review PR
- frame merge approval
- write repair prompt
- diagnose blocker path

## Paste-back rules

On successful submit, the operator should paste back:

- `FINAL SUMMARY`
- `PR REVIEW REQUEST`

On blocker/failure, the operator should paste back:

- `FINAL SUMMARY` only

The blocker final summary must be self-contained.

## Approved success final summary shape

```text
===== FINAL SUMMARY =====
script=slice-handoff
mode=submit
rc=0
run_id=1781390196-1445973-docs-downstream-install-quickstart-l1h4fra1
branch=docs/downstream-install-quickstart
pr=259
commit=62b3dd9
pushed=true
ci=pass
checks=preflight pass; codex pass; pr-body pass; submit pass; ci pass
codex=gpt-5.4-mini / medium
codex_elapsed=4m 41s
codex_session=019ec1c2-3823-7051-a8a2-fd8c7cfa2b33
codex_session_total=9m 03s across 3 tracked runs
url=https://github.com/i-schuyler/repo-automation-template/pull/259
next=review PR before merge
===== END =====
```

## Approved blocker final summary shape

```text
===== FINAL SUMMARY =====
script=slice-handoff
mode=execution
rc=1
run_id=1781390196-1445973-docs-downstream-install-quickstart-l1h4fra1
run_dir=/home/schuyler/.cache/tmp/repo-automation/slice-handoff-runs/1781390196-1445973-docs-downstream-install-quickstart-l1h4fra1
branch=docs/downstream-install-quickstart
checks=preflight pass; codex fail
codex=gpt-5.4-mini / medium
codex_elapsed=1m 12s
codex_session=019ec1c2-3823-7051-a8a2-fd8c7cfa2b33
codex_session_total=9m 03s across 3 tracked runs
failure_source=codex-child
failure_step=codex
child_failure_preserved=true
blocker=fail: preflight failed; reason: stop_reason=validation manifest contract failed: branch must match requested branch: expected 'feature/slice-handoff-repair', got 'docs/downstream-install-quickstart'
failure_fix=align the repair-execution smoke fixture branch with the branch codex-slice-preflight reads, then rerun the focused slice-handoff contract
evidence=/home/schuyler/.cache/tmp/repo-automation/slice-handoff-runs/1781390196-1445973-docs-downstream-install-quickstart-l1h4fra1/codex-run/codex-failure-card.txt
next=repair blocker
===== END =====
```

## Field ownership

`slice-handoff` may print workflow fields:

- branch
- PR
- commit
- CI
- pushed
- URL
- next
- checks
- failure fields

`slice-handoff` may print Codex context when it is part of the workflow handoff:

- codex
- codex_elapsed
- codex_session
- codex_session_total

## Rules

- Use `codex_elapsed`, not bare `elapsed`, inside slice-handoff final summaries.
- Use `codex_session_total`, not bare `session_total`, inside slice-handoff final summaries.
- Do not print raw seconds in human UI.
- Do not print `codex-status` `work_time` anywhere.
- Only print failure fields on failure/blocker paths.
- Only print PR/url/ci/pushed fields when submit mode reached those phases.
- Do not include `review_request=printed`; if the PR review request is pasted after the final summary, the reviewer can see it.
- Success submit paste-back is `FINAL SUMMARY + PR REVIEW REQUEST`.
- Blocker paste-back is `FINAL SUMMARY only`, with blocker and evidence fields.

## Change control

This UI contract must not be changed incidentally during unrelated helper, workflow, or documentation work.

Any future change that:

- adds workflow fields back into `codex-status --pretty`,
- reintroduces `work_time` into pretty output,
- changes the meaning of `session total`,
- removes required blocker evidence from slice-handoff summaries,
- or changes the success/blocker paste-back rule,

must first update the relevant contract doc and receive explicit approval.
