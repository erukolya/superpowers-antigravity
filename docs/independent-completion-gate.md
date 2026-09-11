# Independent Completion Gate

The completion gate is a `Stop` hook that runs only after a session has modified code and the main agent tries to finish normally.

## What it does

1. Reads the current conversation transcript.
2. Extracts only explicit user requests (`USER_EXPLICIT` / `USER_INPUT`) and modified file paths. Previous model reasoning and success claims are intentionally not passed as requirements.
3. Starts a brand-new headless `agy` process in `plan` mode.
4. The fresh reviewer independently inspects the repository, git state/history, task/spec/plan artifacts, applicable rules, tests/build evidence, and the implementation itself.
5. The reviewer must return structured `PASS` or `FAIL` output.
6. `PASS` lets the original session stop.
7. `FAIL` returns `decision: "continue"`; the reviewer's concrete required actions are injected into the original worker session as a system message. When that worker tries to finish again, another fresh reviewer session is created.

The reviewer's own session is protected by `SUPERPOWERS_COMPLETION_REVIEW_ACTIVE=1`, so loading this plugin there does not recursively launch another reviewer.

Non-code conversations, user cancellation, runtime errors, and max-step termination are not converted into completion-review loops.

## Requirements

- Node.js available to the hook runner.
- `agy` available on `PATH` and already authenticated for headless use.
- The plugin's `hooks.json` enabled/loaded by Antigravity.

## Configuration

Environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `SUPERPOWERS_AGY_BIN` | `agy` | Path/name of the Antigravity CLI executable |
| `SUPERPOWERS_COMPLETION_REVIEW_MODEL` | current configured model | Optional model slug for the fresh reviewer |
| `SUPERPOWERS_COMPLETION_REVIEW_EFFORT` | `high` | Reviewer reasoning effort |
| `SUPERPOWERS_COMPLETION_REVIEW_TIMEOUT` | `15m` | Antigravity headless timeout |
| `SUPERPOWERS_COMPLETION_REVIEW_PROCESS_TIMEOUT_MS` | `960000` | Hard child-process timeout |
| `SUPERPOWERS_COMPLETION_GATE_FAIL_OPEN` | unset | Set to `1` only if reviewer infrastructure failures should allow completion |

By default infrastructure failures are **fail closed**: the worker is told that independent review could not complete and is not allowed to claim completion.

## Reviewer contract

The fresh reviewer is instructed to distrust the worker, inspect actual code and evidence, check requirements and repository rules, and reject stubs, TODOs, fake/skipped tests, shortcuts, partial implementations, and unsupported success claims.

Its structured result is:

```json
{
  "verdict": "PASS | FAIL",
  "summary": "short factual assessment",
  "required_actions": ["concrete fix"],
  "evidence": ["file/line, command, test result, or directly checked fact"]
}
```

A `FAIL` is fed back into the same worker session; a later completion attempt gets a completely new independent reviewer session.
