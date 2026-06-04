# Exit-Code / Stream Contract

This doc is the source of truth for exit-code/stdout/stderr/JSON stream behavior. [Output Modes](output-modes.md) remains the broader output-mode guide.

## Approved gates

| Gate | Contract |
| --- | --- |
| Default human compact | least information helpful for a human |
| `--quiet` | least information helpful for a machine or low-token agent caller |
| `--json` | detailed structured machine output |
| `--explain` | detailed step-by-step human/operator output |

## Signal contract

| Signal | Contract |
| --- | --- |
| `0` | success |
| non-zero | failure/blocker |
| warning-only | allowed when the main task still passes |
| skip | no blocker; do not convert to failure |
| wait/pending | not a failure; keep polling or return a wait state |

## Stream rules

- stdout is reserved for the primary result.
- stderr carries human diagnostics when stdout is machine-readable.
- JSON stdout must be pure JSON.
- JSON helpers should include a `schema` and `result` field, and failures should carry `code`, `step`, `reason`, and `fix` when those fields are part of the helper contract.
- No human chatter in JSON output.
- No child-helper chatter may leak through umbrella helpers.
- Quiet mode uses a machine/agent low-token envelope, not human-readable prose, unless the helper documents an exception.
