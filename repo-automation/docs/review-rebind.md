# Review Rebind

`repo-automation/bin/review-rebind` is the read-only PR-review state binding helper for ChatGPT-first review workflows.

## Primary interface

```text
repo-automation/bin/review-rebind --pr=<number> --json
```

Value flags use strict `--flag=value` syntax. `--pr <number>` is rejected.

JSON mode writes machine JSON only to stdout. The helper does not write GitHub state, git state, repository files, or review artifacts. Temporary capture files live under `${TMPDIR:-$HOME/.cache}` and are removed on exit.

## Result

A successful result follows `repo-automation-helper-output/v1` and binds the current mechanical review state:

- repository identity and PR number;
- PR open/draft/merged/mergeable state;
- exact PR head SHA/ref, base SHA/ref, and current default-branch SHA/ref;
- SHA-256 PR-body fingerprint;
- review count/state summary and stable activity fingerprint;
- review-thread total, unresolved count, stable fingerprint, and explicit `complete`, `incomplete`, or `unknown` completeness;
- active durable `<!-- pr-review-checkpoint:v1 -->` checkpoint when one exists;
- normalized changed filenames across all fetched pages;
- exact-current-head CI output from the repo-relative `ci-status --pr=<number> --json` helper;
- objective `binding_mismatches` and explicit `unknowns`.

The default machine result intentionally omits PR titles and large diffs/logs.

## Durable checkpoint parsing

Checkpoint discovery is mechanical only. The helper searches PR issue comments for the exact marker:

```text
<!-- pr-review-checkpoint:v1 -->
```

It reads only supported header fields: `Sequence`, `Review generation`, `Reviewed head`, `Base/current main`, `Lifecycle`/`Lifecycle state`, `Current item`, and `Verdict`.

If multiple marked checkpoints contain valid positive sequence numbers, the highest sequence wins. Ties are resolved deterministically by comment update time and comment ID. A marked checkpoint set with no valid sequence fails explicitly as `malformed-checkpoint`. No marker is valid state and returns `checkpoint.available=false`; review state is not invented.

`verdict` is preserved only as a mechanical field when present. The helper does not interpret it.

## Review-thread completeness

Review threads use GitHub GraphQL pagination. If the thread surface is unavailable, `review_threads.completeness` is `unknown` and the field appears in `unknowns`. If thread pages are available but nested comment detail is truncated, completeness is `incomplete` rather than silently `complete`.

## CI ownership

`review-rebind` does not implement CI interpretation. It invokes the runtime repo-relative `repo-automation/bin/ci-status --pr=<number> --json` and embeds that JSON result. A red CI result remains evidence rather than becoming a semantic PR-review verdict.

## Binding mismatches

`binding_mismatches` is limited to objective comparisons such as:

- durable checkpoint reviewed head vs current PR head;
- durable checkpoint base/current-main value vs current default-branch SHA;
- PR base SHA vs current default-branch SHA when the PR targets that branch;
- `ci-status` head SHA vs current PR head.

These facts do not decide selective review invalidation or review outcome.

## Semantic boundary

`review-rebind` does **not** decide CLEAN / NEEDS REPAIR, semantic adequacy, PR-body truthfulness, red-team outcome, repair sufficiency, merge readiness, deployment, or publication. ChatGPT remains the semantic reviewer.

This Slice 1 surface also does not qualify the installer or downstream installation. Installer field qualification and downstream dogfood remain later work under issue #262.
