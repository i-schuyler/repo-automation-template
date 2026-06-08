# Slice Handoff

`slice-handoff` is a public-safe validated handoff runner for a bounded AI-assisted implementation slice.

## Dry-run mode

The non-executing mode is `--dry-run`.

`--dry-run` validates the handoff and may generate local artifacts, but it does not create an active run dir, run cleanup, run preflight, run Codex, create branches, commit, push, create PRs, watch CI, merge, delete branches, tag, release, publish, or write session metadata into tracked repo files.

`--submit` is a bare authorization flag for the submit trust boundary. It only has effect when the handoff envelope sets `submit_mode: repo-flow-submit-all`.

`--explain` is supported and prints operator-visible INFO progress plus a repo-style FINAL SUMMARY block. When a review request file is available, `--explain` also prints the rendered review-request text after FINAL SUMMARY in a clearly delimited block for copy/paste back into ChatGPT for PR review. In execution mode, `--explain` may also surface a CODEX FINAL OUTPUT block after Codex completes. When `--quiet` and `--explain` are supplied together, `--explain` takes precedence for visibility.

`slice-handoff` refuses prompts that would edit the running helper itself (`repo-automation/bin/slice-handoff`) before it creates a run dir or starts preflight. Use the direct Codex lane or the same-branch repair lane when changing `slice-handoff`.

Review request source precedence is:

1. explicit `## PR Review Request` payload in the handoff file
2. `pr_review_prompt_id`, resolved to `.prompts/<id>.md` under the repo root
3. built-in fallback review request

Explicit `## PR Review Request` and `pr_review_prompt_id` are mutually exclusive.

## Review request placeholders

Supported placeholders in review-request content are:

- `<PR_URL>`: resolves to the submitted PR URL after successful `repo-flow submit`
- `<TITLE>`: resolves to the handoff title
- `<BRANCH>`: resolves to the handoff branch
- `<RUN_DIR>`: resolves to the active execution run directory

Dry-run artifacts may keep placeholders unresolved because no real PR has been submitted and no active execution run has completed. In execution submit mode, the active run-dir `review-request.txt` is rewritten after submit succeeds so supported placeholders resolve.

After Codex completes, `slice-handoff --submit` also captures `repo-automation/bin/codex-status --recent=1` JSON into run-dir artifacts (`codex-status-recent.json`, `codex-status-recent.stderr`) and renders a `CODEX RUN CONTEXT` block in explain mode. In submit success output, the visible order is `FINAL SUMMARY`, `CODEX RUN CONTEXT`, then `PR REVIEW REQUEST`. If Codex final output is a blocker, explain mode prints `CODEX RUN CONTEXT` before `CODEX FINAL OUTPUT`.

## Submit authorization matrix

| Mode | submit_mode | `--submit` | Behavior |
| --- | --- | --- | --- |
| dry-run | unset | no | validate and preview non-submit execution |
| dry-run | `repo-flow-submit-all` | no | validate PR body; do not preview submit crossing |
| dry-run | `repo-flow-submit-all` | yes | validate PR body and preview submit plan; no execution |
| execution | `repo-flow-submit-all` | no | preflight -> codex-run -> stop before submit |
| execution | `repo-flow-submit-all` | yes | preflight -> codex-run -> pr-body-check -> repo-flow submit -> stop before merge |

Use `--out-dir=<path>` to write normalized local artifacts outside the repo root:

- `codex-prompt.md`
- `dry-run-preview.txt` non-executing public-safe preview of the execution shape; submit-specific `pr-body-check` and `repo-flow submit` planning only appears when bare `--submit` is authorized
- `slice-handoff-summary.txt`
- `review-request.txt`
- `pr-body.md` when bare `--submit` is authorized and `submit_mode: repo-flow-submit-all`

The out-dir must be outside the current repo root. Success prints the artifact paths unless `--quiet` is set; `--explain` instead emits progress, a FINAL SUMMARY block, and the review-request text when available.

`## PR Review Request` is recognized as a boundary and is emitted as `review-request.txt` when present or generated from the selected prompt preset or public-safe defaults. In execution submit mode, slice-handoff now passes a run-dir source file to `repo-flow submit --review-request-file=<path>` after pre-resolving `<RUN_DIR>` and the handoff title/branch context; `repo-flow submit` then renders the final `<PR_URL>`, and slice-handoff copies the lower-layer rendered `review_request_path` back to the active run dir `review-request.txt` for compatibility.

## Envelope and payloads

- envelope: branch, title, `codex_profile`, `commit_message`, submit mode, watch/timeout fields, and prompt preset identifiers
- payloads: Codex prompt, PR body, and PR-review request
- `pr_review_prompt_id` selects `.prompts/<id>.md` when no explicit review request is present
- `slice-handoff` validates payload shape and configured policy, but it does not reinterpret strategy

## Public-safe state machine

`draft-handoff -> validate-envelope -> validate-pr-body -> validate-prompt-contract -> execution-preflight -> codex-run -> codex-blocker OR submit-pr -> pr-body-check -> repo-flow-submit OR submit-blocker OR pr-ready-for-review`

## Execution flow

When `--dry-run` is omitted, `slice-handoff` runs execution flow:

- validate the handoff by calling `slice-validator` before `codex-slice-preflight`
- create and preserve a marked active run directory for the lifetime of the future execution
- clean up stale marked run dirs through `slice-run-dir` without touching unmarked directories
- run preflight with JSON child diagnostics from the checked-out repo root
- run Codex
- if Codex final output begins with `blocker` after trimming spaces, tabs, and CR, stop before PR-body validation or submit and surface the blocker artifact instead
- if `--submit` is not authorized, stop after Codex with `next=repo-flow submit not implemented in this slice`
- if `--submit` is authorized and `submit_mode: repo-flow-submit-all` is set, validate the PR body, submit through `repo-flow submit`, and stop before merge

Execution flow writes child logs and artifacts under the active run dir:

- `slice-run-dir-create.json`
- `slice-run-dir-create.stdout`
- `slice-run-dir-create.stderr`
- `slice-run-dir-cleanup.json`
- `slice-run-dir-cleanup.stdout`
- `slice-run-dir-cleanup.stderr`
- `preflight.json`
- `preflight.stdout`
- `preflight.stderr`
- `codex-status-recent.json`
- `codex-status-recent.stderr`
- `codex-run-context.txt`
- `pr-body-check.stdout` and `pr-body-check.stderr` when submit is authorized
- `repo-flow-submit.stdout` and `repo-flow-submit.stderr` when submit is authorized
- `slice-handoff-execution-summary.txt`
- `codex-prompt.md`
- `review-request.txt`
- `pr-body.md` when submit is authorized and submit mode is enabled

The preflight child runs in the active checked-out repo, while test fixtures keep isolation by using temp repos during contract checks.

Failure returns a compact blocker with the failing step, command class, command, exit code, artifact paths, reason/excerpt, `fix=paste this blocker into ChatGPT`, and a step-specific next action.

For blocker-semantics coverage, keep the trust-boundary tests close to the execution gate and prefer tiny fixture helpers for shaping Codex final output. Quiet-mode artifact clarity matters most for `slice-handoff-execution-summary.txt`, `slice-handoff-summary.txt`, `codex-run.stdout`, `codex-run.stderr`, `codex-run/codex-run-summary.txt`, `codex-run/codex-final.txt`, `preflight.json`, `preflight.stdout`, `preflight.stderr`, `pr-body-check.stdout`, `pr-body-check.stderr`, `repo-flow-submit.stdout`, `repo-flow-submit.stderr`, `review-request.txt`, and `codex-prompt.md`.

## Slice validator capability gate

`repo-automation/bin/slice-validator` validates the run contract and emits a run-scoped capability manifest before repo preflight.

It is designed primarily for `slice-handoff`, but it can be called directly for inspection or debugging of a proposed slice.

It does not validate repo/worktree/execution-environment readiness; that remains `codex-slice-preflight`.

It may grant some capabilities and deny others. Missing optional inputs deny dependent capabilities rather than failing unrelated capabilities. For example, no PR body or submit authorization means `repo_flow_submit=false`, while a valid handoff and Codex prompt can still allow `codex_run=true`. Blocker repair or resume paths may validate a subset such as `codex_run`, `codex_status`, and `repo_flow_submit` without rerunning preflight when the selected mode explicitly supports that flow.

The capability manifest is run-scoped, not a single safety byte. A compact example:

```json
{
  "schema": "repo-automation-slice-validator/v1",
  "result": "pass",
  "validation_id": "val_123",
  "repo_root": "/path/to/repo",
  "branch": "docs/output-contract-compliance-tracking",
  "handoff_path": ".slice-handoff.json",
  "handoff_hash": "sha256:...",
  "prompt_path": "codex-prompt.md",
  "prompt_hash": "sha256:...",
  "pr_body_path": "pr-body.md",
  "pr_body_hash": "sha256:...",
  "requested_mode": "execution",
  "validated_capabilities": {
    "codex_run": true,
    "codex_status": true,
    "repo_flow_submit": false
  },
  "forbidden_steps": ["merge", "publish"],
  "next": "codex-slice-preflight",
  "created_at": "2026-06-05T00:00:00Z"
}
```

Default success stays compact and names the manifest path. Default failure stays compact and actionable with step, reason, and fix. Quiet success is silent, quiet failure uses QDE, and JSON success/failure emit valid JSON only on stdout.

Over time, run-shape checks should move out of `slice-handoff` and `codex-slice-preflight` into `slice-validator`: handoff envelope fields, mode/flag compatibility, submit authorization, PR body static readiness, Codex prompt lifecycle and boundary checks, self-modifying target checks, review-request source compatibility, and downstream helper contract assumptions. Repo/worktree/environment checks stay in `codex-slice-preflight`.

Downstream helpers keep local invariant validation for standalone, debug, and repair use. `slice-handoff` records the validator manifest path in the dry-run and execution summaries, but downstream helper calls still do not require a `--validation-manifest=<path>` flag in this slice. Direct standalone helper use should remain intact.

Phased plan:

1. Spec recorded.
2. Implemented: `slice-validator` emits a manifest and has focused contract tests.
3. Implemented: `slice-handoff` calls `slice-validator` before `codex-slice-preflight`.
4. Pass the manifest to downstream helpers in orchestrated mode.
5. Selectively require the manifest for high-risk orchestrated downstream operations while preserving standalone repair/debug paths.

## Timeout and profile contract

- no single global timeout
- `codex_timeout_seconds=0` means no hard Codex timeout
- submit/watch timeout is separate and may default to `900`
- detached or interactive-only Codex invocations are unsupported unless wrapped by an adapter that provides an exit code and final output file
- future resumability should preserve deterministic slice-handoff boundaries

Profile examples:

- `default`
- `lean`
- `medium`
- `high`
- `repair`
- `review`

## Safety rules

- no private prompt text or private workflow language in public docs
- generated logs/artifacts outside the repo root by default
- no tracked session metadata by default
- merge remains explicit and outside `slice-handoff`

For the future operator/automation status helper spec, see [Codex Status Helper Spec](codex-status.md).
