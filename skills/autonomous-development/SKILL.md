---
name: autonomous-development
description: Use when the user wants a substantial development goal completed end-to-end with minimal human involvement, autonomous execution, or a long-running build/fix/verify loop. Owns broad planning, internal decomposition, implementation, review, runtime verification, recovery, and final mission acceptance.
---

# Autonomous Development

Turn a broad development goal into working, verified software while minimizing human attention.

**Primary optimization target:** human attention, not tokens, agent count, test count, or elapsed time.

**Core principle:** Align once on the outcome, then keep working until the outcome is independently reviewed and verified in the real execution environment.

This is an alternative execution path to the normal `brainstorming -> writing-plans -> subagent-driven-development` flow. Do not invoke `writing-plans` for this path. The user-facing plan stays broad; detailed decomposition is internal and may change as evidence arrives.

## Process Ownership

While this skill is active, `autonomous-development` is the controlling process skill. Do **not** invoke `subagent-driven-development` as a second top-level controller and do not let its terminal branch-finishing step run per workstream. Reuse its independent-review and scoped re-review discipline as implementation machinery inside this mission.

If another process skill conflicts with this mission's single-approval, continuous-execution, or workstream-gate rules, this skill owns the autonomous path unless an explicit user instruction says otherwise.

## When This Skill Owns the Request

Use this skill when the user asks for any equivalent of:

- build or implement a substantial feature end-to-end
- take a broad task and finish it autonomously
- keep working until it is actually done
- minimize questions, approvals, or manual checking
- run a long autonomous coding session

If the user asks for a normal collaborative design session instead, use `superpowers:brainstorming`.

## Human Attention Policy

A running mission does not stop for routine engineering decisions.

Resolve ambiguity yourself when the decision is reversible and can be grounded in the repository, tests, docs, established project patterns, or the approved mission brief. Record important decisions as rulings in the mission ledger.

Ask the user only when at least one of these is true:

1. **Product intent is genuinely underdetermined** — two plausible choices create materially different user-visible behavior and repository evidence cannot resolve it.
2. **The action is irreversible or destructive** — destructive data/schema operations, irreversible migrations, deletion of user data, or equivalent risk.
3. **The action creates an external side effect that normally requires consent** — publishing, deploying, merging/pushing to a shared branch, spending money, sending messages, changing external services.
4. **A required secret, credential, device, service, or environment is unavailable** and there is no local substitute that can prove the requirement.
5. **The mission is genuinely stalled** after the recovery ladder below has exhausted materially different approaches and no new evidence is being produced.

Do not ask the user to choose implementation details merely because multiple reasonable implementations exist. Choose one, record the ruling, and continue.

## Phase 1: Mission Alignment

Explore the repository enough to understand the existing system before asking questions. Prefer repository evidence over questions.

Create a **Mission Brief** with only the level of detail the user should care about:

```markdown
# Mission: <name>

## Goal
<the user-visible outcome>

## Constraints
<binding constraints and non-negotiables>

## Broad Workstreams
1. <outcome-oriented workstream>
   - Done when: <observable completion criteria>
2. <outcome-oriented workstream>
   - Done when: <observable completion criteria>
...

## Final Acceptance
<what must be true for the whole mission to be considered done>

## Verification Surfaces
<which surfaces require build/test/API/browser/runtime/database/CLI/etc. evidence>
```

### Broad Means Broad

Workstreams are user-facing outcomes, not five-minute implementation steps.

Good:
- Implement the backend contract and persistence for selection sets
- Integrate selection sets into the viewer UI
- Prove the complete selection-set flow in the running application

Bad:
- Add one DTO
- Write one failing test
- Change one method
- Run one command
- Commit

A workstream may take many internal tasks and many repair cycles. That internal structure is the controller's responsibility, not the user's.

### Approval Gate

Default to exactly **one user approval gate** before implementation: approval of the Mission Brief.

Do not ask for separate approval of each section, each workstream, the internal task plan, reviewer findings, fixes, or verification retries.

If the user already supplied an approved broad plan and explicitly told you to execute it autonomously, treat that as approval and begin execution without asking again.

## Phase 2: Mission Workspace and Ledger

### One Authoritative Mission Branch

The autonomous mission uses **one isolated mission branch/workspace** as the authoritative implementation state.

If the parent is on main/master, create a dedicated feature branch for the mission before any code change. If the session already runs in an isolated feature workspace approved for this mission, keep it.

Do **not** create a new isolated git branch for every internal implementation task. Antigravity's `Workspace: "branch"` is useful for isolated subagent experiments, but autonomous sequential work needs every later task and every runtime gate to see the exact accepted HEAD from earlier tasks. The mission therefore uses fresh agent **context** with shared sequential workspace state.

Dispatch rules:

| Role | Workspace | Writes product code? |
|---|---|---|
| `mission-implementer` | `inherit` | yes |
| `spec-reviewer` | `inherit` | no |
| `code-reviewer` | `inherit` | no |
| `re-reviewer` | `inherit` | no |
| `workstream-reviewer` | `inherit` | no |
| `runtime-verifier` | `inherit` | no product-code writes; ignored verification artifacts only |
| `mission-reviewer` | `inherit` | no |

**Only one product-code-writing agent may be active at a time.** Never run `mission-implementer` or another fixer concurrently against the shared mission workspace. Parallel read-only research/review is allowed only when it cannot race with a write phase.

Freshness comes from dispatching a fresh subagent conversation for a new internal task, not from giving every task a disconnected git branch.

### Baseline

Before implementation:

1. record `MISSION_BASE_SHA`
2. confirm the working tree is clean enough to distinguish mission changes from pre-existing user work
3. run the repository's relevant baseline build/tests when practical
4. if baseline failures exist, investigate enough to classify them as pre-existing vs mission-blocking and record them in the ledger

Do not ask the user merely because the baseline is imperfect. Continue when failures are demonstrably pre-existing and do not prevent proving the mission. Escalate only if the baseline makes the required mission outcome genuinely unverifiable or unsafe to change.

### Durable State

Create mission state under:

```text
<repo-root>/.superpowers/missions/<mission-slug>/
  mission.md
  progress.md
  workstreams/
  evidence/
  verification/
```

Ensure `.superpowers/` is ignored by git.

`mission.md` contains the approved Mission Brief.

`progress.md` is the durable controller state. Track:

```text
Mission: ACTIVE | VERIFYING | COMPLETE | BLOCKED
Mission base: <sha>
Authoritative branch: <branch>
Authoritative HEAD: <sha>
Current workstream: <N/name>

Workstream N: PENDING | ACTIVE | VERIFYING | COMPLETE | BLOCKED
Base SHA: <sha>
Head SHA: <sha>
Rulings:
- ...
Open findings:
- ...
Verification:
- ...
```

The ledger is authoritative after compaction or session interruption. Resume from it and confirm its recorded branch/HEAD against git; do not make the user reconstruct progress.

## Phase 3: Internal Workstream Decomposition

Before implementing a workstream, decompose it internally into reviewable implementation tasks.

These tasks are **not user-facing** and require **no user approval**. They may be added, removed, split, merged, or reordered as implementation evidence changes.

Right-size an internal task by engineering coherence:

- one meaningful deliverable with a clear boundary
- small enough for a fresh implementer to understand and review reliably
- large enough to avoid ceremony-only dispatches
- has a concrete way to verify its behavior

Do not optimize for a fixed duration or a fixed number of files.

Write the internal task list to the workstream ledger. The user should not have to manage it.

## Phase 4: Internal Implementation Loop

Use the bundled autonomous `mission-implementer` plus the proven Superpowers reviewer roles:

```text
fresh mission-implementer
  -> spec-reviewer
  -> code-reviewer
  -> fix
  -> scoped re-review
  -> task accepted
```

The autonomous controller owns orchestration. Do not invoke `writing-plans` and do not ask for approval between internal tasks.

For each internal task:

1. Confirm the mission branch is the authoritative workspace and record `TASK_BASE_SHA = HEAD`.
2. Dispatch a fresh `mission-implementer` with `Workspace: "inherit"`, the full internal task text, relevant interfaces, approved mission constraints, and the current workstream outcome.
3. Require the implementer to implement, run checks appropriate to its change, commit, self-review, and report `TASK_BASE_SHA..TASK_HEAD_SHA`.
4. Confirm the reported commit is actually the current mission `HEAD`. If not, do not review stale/disconnected code; reconcile the workspace state before proceeding.
5. Dispatch `spec-reviewer` with `Workspace: "inherit"` against the task text and `TASK_BASE_SHA..TASK_HEAD_SHA`. Spec failures are blocking.
6. After spec PASS, dispatch `code-reviewer` with `Workspace: "inherit"`. Critical and Important findings are blocking. Minor findings may be recorded for the workstream/final review.
7. Send blocking findings back to the same mission-implementer conversation and use `re-reviewer` on the exact fix range after it commits the repair.
8. Repeat until the task gates pass or the recovery ladder requires a materially different approach.
9. Update authoritative HEAD and the durable ledger immediately.

A task is accepted only on the exact mission HEAD it reviewed. If product code changes after a review PASS, every affected review/evidence gate becomes stale and must be repeated at the appropriate scope.

Reviewers do not replace runtime verification. Passing code review means the implementation is credible in code; it does not prove the system works in the running environment.

## Phase 5: Workstream Gate

A workstream is not complete because all internal tasks say DONE.

After its internal tasks pass their review loops:

1. Freeze and record `WORKSTREAM_HEAD_SHA`.
2. Dispatch `workstream-reviewer` with `Workspace: "inherit"` and:
   - the approved workstream outcome and completion criteria
   - workstream BASE..WORKSTREAM_HEAD_SHA
   - internal task summaries and outstanding Minor findings
   - verification reports available so far
3. If the reviewer returns FAIL, create internal repair tasks and run the normal implementation/review loop. Then restart the workstream gate on the new HEAD.
4. Dispatch `runtime-verifier` with `Workspace: "inherit"` for the same `WORKSTREAM_HEAD_SHA`.
5. If runtime verification FAILS, feed the concrete failure evidence into a repair task, review the repair, then restart the affected workstream gate on the new HEAD.
6. Mark the workstream COMPLETE only when both the workstream review and required runtime verification are PASS for the **same current HEAD**.

`UNVERIFIABLE` is not PASS. Either obtain the missing evidence automatically or follow the Human Attention Policy if the evidence truly requires user-only access.

## Runtime Verification Policy

Verification is selected by the behavior changed, not by a fixed ritual or test count.

Examples:

| Changed surface | Required evidence |
|---|---|
| Pure library/domain logic | focused tests + relevant integration/full-suite evidence |
| Backend/API | build/tests plus an actual API/service path when practical |
| Database/schema/query | migration/query/integration evidence against a disposable or approved environment |
| CLI/tooling | invoke the actual command and inspect exit/output |
| Frontend/UI | **real browser verification is mandatory** |
| Canvas/WebGL/3D viewer | browser verification must prove the canvas/viewer actually renders and the affected interaction works; DOM presence alone is insufficient |
| Cross-layer feature | end-to-end evidence across the affected layers |
| Docs-only change | render/lint/link checks as relevant; no fake runtime gate |

There is no target number of tests. Run as many checks and repair cycles as are necessary to establish the required evidence after the latest code changes.

## Frontend Browser Gate

For any workstream that changes observable frontend behavior, `runtime-verifier` must exercise the affected flow in a real browser before the workstream can pass.

Required evidence should cover what is relevant to the workstream:

- page/application actually loads
- changed user flow can be performed
- expected visible state appears
- browser console has no new relevant errors
- relevant network requests do not fail unexpectedly
- screenshots or equivalent artifacts capture the tested state
- for canvas/WebGL/3D work: the rendering surface is non-empty/meaningful and the affected interaction is exercised

Prefer the project's existing Playwright/Cypress/E2E harness. If no browser harness exists, the verifier may create an **ephemeral, ignored** Playwright probe under `.superpowers/missions/<mission>/verification/` and run it without committing test infrastructure merely to satisfy the gate.

The built-in `/browser` workflow may be used when available, but autonomous completion must not depend on the user manually running it if a command-line browser harness can prove the same behavior.

## Recovery Ladder

Do not use an arbitrary small retry cap as a substitute for engineering judgment. Continue while the loop is producing new evidence, narrowing the failure, or changing the implementation meaningfully.

When a failure repeats:

1. **First repair:** resume the mission-implementer with the exact failing evidence.
2. **If the same failure persists without a narrower diagnosis:** end that implementer's ownership and dispatch a fresh `mission-implementer` on the same mission workspace with the task, current HEAD, prior evidence, and a requirement to establish root cause before editing.
3. **If the local approach is exhausted:** re-plan the internal workstream decomposition or choose a materially different implementation strategy; record the ruling.
4. **Re-run static review and the affected runtime gate after every repair.** Never carry a PASS across code that changed underneath it.
5. **Declare STALLED only when materially different approaches have failed and the latest attempts produce no new diagnostic evidence.** Then ask the smallest possible user question, with the evidence and the exact decision/input needed.

A repeated failure is a reason to change the approach, not a reason to lower the gate.

## Phase 6: Mission Gate

After all workstreams are COMPLETE, verify the original mission rather than merely checking that the task list is empty.

1. Freeze and record `MISSION_HEAD_SHA`.
2. Dispatch `mission-reviewer` with `Workspace: "inherit"` and:
   - original approved Mission Brief
   - MISSION_BASE_SHA..MISSION_HEAD_SHA for the entire mission
   - all workstream review results
   - all runtime verification evidence
   - unresolved Minor/known-risk ledger entries
3. Run final end-to-end `runtime-verifier` checks for any acceptance criteria that span multiple workstreams, on the same MISSION_HEAD_SHA.
4. If either gate FAILS, create repair workstreams/tasks and continue autonomously through implementation -> review -> verification again. All affected prior evidence becomes stale.
5. Mission is COMPLETE only when:
   - every required workstream is COMPLETE
   - mission-reviewer = PASS on the current mission HEAD
   - every required runtime/end-to-end verification = PASS on the current mission HEAD
   - no unresolved Critical or Important finding remains
   - the implementation satisfies the original user-visible goal, not merely the internal plan

Do not report percentages. The terminal states are:

- `COMPLETE` — independently reviewed and required runtime evidence is green
- `BLOCKED` — one of the Human Attention Policy stop conditions genuinely prevents further progress

## User Communication During Execution

Keep the user informed without turning progress into approval gates.

Good updates:
- "Backend workstream passed review; runtime verification found an API serialization defect. Fixing it now."
- "Frontend implementation is complete, but browser verification caught a broken selection flow. Repair loop is active."

Bad updates:
- "Task 7 finished. Continue?"
- "Reviewer found two issues. Which should I fix?"
- "Tests failed. What do you want me to do?"

Progress reporting is informational. Continue working unless a Human Attention Policy stop condition applies.

## Non-Negotiable Rules

- Optimize for minimum human intervention.
- One broad approval gate by default, not one approval per implementation decision.
- User-facing plans contain broad outcomes, not five-minute steps.
- Internal decomposition is disposable controller state, not a contract with the user.
- Fresh independent review is required; implementer self-review never substitutes for it.
- Use one authoritative mission branch; do not strand accepted internal tasks on disconnected task branches.
- Only one product-code writer may be active at a time on the mission workspace.
- Every review/runtime PASS is bound to the exact HEAD it verified; relevant code changes invalidate it.
- Review PASS never substitutes for runtime evidence when runtime behavior is part of the goal.
- Frontend/UI behavior requires a real browser gate.
- A failed gate triggers repair and re-verification automatically.
- Do not lower a gate because repair is expensive, slow, or token-heavy.
- Do not stop just because a predefined retry count was reached.
- Never claim COMPLETE while required evidence is missing or stale.
