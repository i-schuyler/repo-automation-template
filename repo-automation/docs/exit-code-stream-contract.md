# Exit-Code / Stream Contract

This doc is the source of truth for exit-code/stdout/stderr/JSON stream behavior. [Output Modes](output-modes.md) remains the broader output-mode guide.

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
- No human chatter in JSON output.
- No child-helper chatter may leak through umbrella helpers.
