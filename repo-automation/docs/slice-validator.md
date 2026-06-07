# Slice Validator

`slice-validator` is the pre-preflight run-contract and capability gate for `slice-handoff`.

It validates the static handoff/run contract, emits a run-scoped capability manifest, and can be called directly for inspection or debugging of a proposed slice.

When `pr_review_prompt_id` is set, the preset resolves from the repo root `.prompts/<id>.md`, not from a `.prompts/` directory beside the handoff file. That lets handoff files outside the repo root use the shared preset library.

`codex-slice-preflight` still owns repo/worktree/execution-environment readiness.

For the public planning arc and the current compliance status, see [Output Contract Backlog](output-contract-backlog.md) and [Slice Handoff](slice-handoff.md).
