---
name: autonomous-development
description: Use when the user wants an approved markdown plan or substantial development goal completed end-to-end with minimal human involvement. The main session supervises a Flash mission-controller, independently audits each broad workstream after Gemini gates are green, and gives final mission acceptance.
---

# Autonomous Development

Execute an approved broad development plan from start to finish while minimizing human intervention.

**Primary optimization target:** human attention, not tokens, agent count, test count, or elapsed time.

**Execution model:** the main session is the supervising model (intended usage: Sonnet). All autonomous implementation machinery runs under a `mission-controller` whose frontmatter is `model: flash`. Nested autonomous agents inherit that Flash tier. This workflow does not use Pro as an escalation path.

Antigravity custom-agent frontmatter can select only `inherit|flash|pro`; it cannot pin a concrete Flash model slug or reasoning effort. This fork therefore enforces the **Flash tier**. The exact runtime mapping (for example Gemini 3.7 Flash High) must be verified/configured in Antigravity itself.

## Approved Markdown Plan Is The Primary Entry Point

Normal intended usage:

```text
Execute task.md autonomously from start to finish.
```

If the user explicitly tells you to execute a supplied/repository `.md` plan, that file is already approved authority.

1. Read the complete file.
2. Preserve its goal, scope, broad ordering, constraints, and acceptance language.
3. Do not rewrite it into a new user-facing plan.
4. Do not ask for another approval.
5. Do not expand the broad plan into five-minute steps in the main session.
6. Pass the full approved file content to `mission-controller`.

The controller may derive internal implementation tasks and verification surfaces needed to prove the stated outcome. It may not silently invent new product scope.

If no approved plan exists, you may create one broad Mission Brief and ask for one approval. After that, use the same protocol below.

## Main Session Responsibility

The main session is a **supervisor**, not the implementation controller.

It owns only:

- reading the approved plan
- dispatching one isolated `mission-controller`
- retaining its conversation ID
- independently auditing each broad workstream after Gemini reports it green
- returning concrete findings to the controller or accepting the workstream
- independently auditing the whole mission after Gemini final gates are green
- asking the human only for genuine blockers

Do not write product code in the supervisor session. Do not take over Gemini repair work.

## Start The Mission

Dispatch exactly one controller:

```text
invoke_subagent(
  Subagents: [{
    TypeName: "mission-controller",
    Role: "Execute approved autonomous mission",
    Workspace: "branch",
    Prompt: <full approved markdown plan + instruction to execute it>
  }]
)
```

Record the returned controller conversation ID. Its isolated branch workspace is the single authoritative mission workspace.

All implementation, internal decomposition, static review, tests, runtime checks, browser verification, debugging, and repair happen below that controller.

## Workstream Supervisor Gate

The controller must not silently advance from one broad user-plan workstream to the next.

After Gemini's internal implementation/review/verification gates are green for a workstream, the controller returns:

```text
Status: READY_FOR_SUPERVISOR_REVIEW
Workstream: <number/name>
Branch: <mission branch>
Base: <WORKSTREAM_BASE_SHA>
Head: <WORKSTREAM_HEAD_SHA>
Gemini static gates: PASS
Runtime verification: <PASS / not applicable + evidence summary>
Browser verification: <PASS / not applicable + evidence summary>
Important rulings: <summary>
Open non-blocking risks: <summary or none>
```

The controller then becomes idle and retains context.

### Supervisor audit

Independently inspect:

- the approved markdown plan's goal and current broad workstream
- `Base..Head` diff/commits
- relevant surrounding interfaces when needed
- Gemini's gate summaries/evidence claims
- important rulings and residual risks

Judge the broad outcome, not the internal task checklist.

Look for:

- missing parts of the workstream
- stubs/placeholders/temporary bypasses/fake production data
- code that exists but is not wired into the real flow
- backend/frontend/database/config contracts that do not line up
- work that passes local tasks but does not satisfy the approved plan
- suspiciously weak or missing verification for an observable criterion
- regressions introduced by the workstream

Do not manufacture findings. A clean audit is valid.

Do not routinely repeat Gemini's entire test/browser suite. If evidence is insufficient or a concrete doubt exists, return that as a finding and make the controller obtain stronger evidence or repair the implementation.

### If accepted

Resume the same idle controller:

```text
send_message(
  Recipient: <controller conversation id>,
  Message: "SUPERVISOR_PASS\nWorkstream <N> accepted at <HEAD>. Continue autonomously to the next broad workstream."
)
```

No human approval is requested.

### If findings exist

Send all concrete findings together:

```text
SUPERVISOR_FINDINGS
Workstream: <N>
Reviewed head: <HEAD>

1. <finding + evidence + violated outcome>
2. ...

Repair these findings autonomously. Re-run all affected Gemini static/runtime/browser gates on the new HEAD. Return READY_FOR_SUPERVISOR_REVIEW again only when Gemini is green.
```

The controller repairs through Flash agents, re-verifies, and returns for another supervisor audit. The supervisor does not fix code itself.

## Final Supervisor Gate

After every broad workstream has passed the supervisor gate, the controller runs its own whole-mission Gemini static review and all required final runtime/browser verification.

Only after those are green may it return:

```text
Status: READY_FOR_FINAL_SUPERVISOR_REVIEW
Mission: <name>
Branch: <mission branch>
Base: <MISSION_BASE_SHA>
Head: <MISSION_HEAD_SHA>
Workstreams: <all supervisor-accepted>
Gemini final static review: PASS
Runtime verification: <PASS / not applicable + evidence>
Browser verification: <PASS / not applicable + evidence>
Important rulings: <summary>
Open non-blocking risks: <summary or none>
```

The main supervisor audits the **original approved markdown plan against the entire `Base..Head` result**.

Ask: is the user's original goal actually solved end-to-end, rather than merely having every internal task marked done?

Check cross-workstream integration, original constraints, omitted outcomes, stale assumptions, and production-readiness risks introduced by the mission.

### Final PASS

Send:

```text
SUPERVISOR_FINAL_PASS
Mission accepted at <HEAD>. Mark COMPLETE and return the final preserved branch/head report.
```

The controller marks its ledger COMPLETE and returns its terminal report. The main session then reports completion to the user with exact `Status`, `Branch`, `Base`, and `Head` lines.

### Final findings

Send:

```text
SUPERVISOR_FINAL_FINDINGS
Reviewed mission head: <HEAD>

<complete concrete findings>

Repair autonomously, repeat affected internal reviews and execution gates, then return READY_FOR_FINAL_SUPERVISOR_REVIEW again.
```

## Human Attention Policy

Neither controller nor supervisor asks the human about routine implementation choices, test failures, reviewer findings, repair strategy, or whether to continue.

Escalate only for:

1. materially different user-visible product choices not resolvable from the approved plan/repository
2. irreversible/destructive operations
3. external side effects requiring consent
4. unavailable credentials/device/service/environment with no substitute capable of proving the requirement
5. genuine technical stall after materially different approaches and independent diagnosis stop producing new evidence

For reversible engineering choices, decide, record the ruling, and continue.

## Model Policy

For this autonomous path:

```text
Main supervising session: Sonnet (selected by the user/runtime)
mission-controller:       Flash
nested autonomous roles:  inherit the Flash controller
Pro tier:                  not used as an escalation mechanism
```

A hard problem escalates by:

```text
same Flash implementer with concrete evidence
→ fresh Flash implementer/context
→ Flash failure-investigator
→ re-plan with fresh Flash context
→ materially different implementation approach
```

Do not assume `pro` is a quality upgrade merely because of the tier name.

## Terminal States

The main supervisor may report only:

- `COMPLETE` — Gemini gates are green, every broad workstream passed supervisor audit, final Gemini gates are green, and final supervisor audit passed
- `BLOCKED` — a Human Attention Policy condition genuinely prevents further autonomous progress

Never report completion percentages.

## Non-Negotiable Rules

- Explicit markdown plan + "execute it" is pre-approved; no second approval.
- User-facing plan stays broad; internal decomposition is autonomous.
- Main session supervises; it does not implement.
- One long-lived Flash `mission-controller` owns one isolated branch workspace.
- Gemini must become green before the supervisor audits a workstream.
- Supervisor findings go back to Gemini for autonomous repair and re-verification.
- No broad workstream advances until the supervisor passes it.
- No mission completes until final supervisor audit passes.
- Frontend/UI changes require the independent real-browser gate below the controller.
- Reviewers remain separate from runtime/browser verifiers.
- Relevant code changes invalidate stale PASS evidence.
- No fixed retry count is a reason to stop.
- Do not use the Pro tier in this autonomous workflow.