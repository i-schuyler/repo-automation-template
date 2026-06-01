# Slice Handoff

`slice-handoff` is a public-safe validated handoff runner for a bounded AI-assisted implementation slice.

## Dry-run mode

The non-executing mode is `--dry-run`.

`--dry-run` validates the handoff and may generate local artifacts, but it does not create an active run dir, run cleanup, run preflight, run Codex, create branches, commit, push, create PRs, watch CI, merge, delete branches, tag, release, publish, or write session metadata into tracked repo files.

`--submit` is a bare authorization flag for the submit trust boundary. It only has effect when the handoff envelope sets `submit_mode: repo-flow-submit-all`.

`--explain` is supported and prints operator-visible INFO progress plus a repo-style FINAL SUMMARY block. When `--quiet` and `--explain` are supplied together, `--explain` takes precedence for visibility.

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

The out-dir must be outside the current repo root. Success prints the artifact paths unless `--quiet` is set; `--explain` instead emits progress and a FINAL SUMMARY block.

`## PR Review Request` is recognized as a boundary and is emitted as `review-request.txt` when present or generated from the selected prompt preset or public-safe defaults. In execution submit mode, the active run dir `review-request.txt` is rewritten after repo-flow submit succeeds so `<PR_URL>` becomes the submitted PR URL.

## Envelope and payloads

- envelope: branch, title, `codex_profile`, `commit_message`, submit mode, watch/timeout fields, and prompt preset identifiers
- payloads: Codex prompt, PR body, and PR-review request
- `pr_review_prompt_id` selects `.prompts/<id>.md` when no explicit review request is present
- `slice-handoff` validates payload shape and configured policy, but it does not reinterpret strategy

## Public-safe state machine

`draft-handoff -> validate-envelope -> validate-pr-body -> validate-prompt-contract -> execution-preflight -> codex-run -> codex-blocker OR submit-pr -> pr-body-check -> repo-flow-submit OR submit-blocker OR pr-ready-for-review`

## Execution flow

When `--dry-run` is omitted, `slice-handoff` runs execution flow:

- validate the handoff
- create and preserve a marked active run directory for the lifetime of the future execution
- clean up stale marked run dirs through `slice-run-dir` without touching unmarked directories
- run preflight with JSON child diagnostics from the checked-out repo root
- run Codex
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
- `pr-body-check.stdout` and `pr-body-check.stderr` when submit is authorized
- `repo-flow-submit.stdout` and `repo-flow-submit.stderr` when submit is authorized
- `slice-handoff-execution-summary.txt`
- `codex-prompt.md`
- `review-request.txt`
- `pr-body.md` when submit is authorized and submit mode is enabled

The preflight child runs in the active checked-out repo, while test fixtures keep isolation by using temp repos during contract checks.

Failure returns a compact blocker with the failing step, command, exit code, artifact paths, excerpt, and `fix=paste this blocker into ChatGPT`.

## Timeout and profile contract

- no single global timeout
- `codex_timeout_seconds=0` means no hard Codex timeout
- submit/watch timeout is separate and may default to `900`
- detached or interactive-only Codex invocations are unsupported unless wrapped by an adapter that provides an exit code and final output file

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
