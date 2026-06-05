# Slice Validator

`slice-validator` is the pre-preflight run-contract and capability gate for `slice-handoff`.

It validates the static handoff/run contract, emits a run-scoped capability manifest, and can be called directly for inspection or debugging of a proposed slice.

`codex-slice-preflight` still owns repo/worktree/execution-environment readiness.

For the public planning arc and the current compliance status, see [Output Contract Backlog](output-contract-backlog.md) and [Slice Handoff](slice-handoff.md).
