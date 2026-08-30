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

While this skill is active, `autonomous-development` is the controlling process skill. Do **not** invoke `subagent-driven-development` as a second top-level controller and do not let its terminal branch-finishing step run per workstream. Reuse its bundled agent roles, review discipline, branch/workspace mechanics, and scoped re-review protocol as implementation machinery inside this mission.

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

Use an isolated worktree/branch using `superpowers:using-git-worktrees`. Never start implementation directly on main/master without explicit consent.

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

The ledger is authoritative after compaction or session interruption. Resume from it; do not make the user reconstruct progress.

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

Reuse the proven bundled Superpowers roles and the task-loop mechanics from `superpowers:subagent-driven-development`:

```text
fresh implementer
  -> spec-reviewer
  -> code-reviewer
  -> fix
  -> scoped re-review
  -> task accepted
```

The autonomous controller owns orchestration. Do not invoke `writing-plans` and do not ask for approval between internal tasks.

For each internal task:

1. Capture its BASE SHA.
2. Dispatch a fresh `implementer` with the full task text, relevant interfaces, approved mission constraints, and the current workstream outcome.
3. Require the implementer to implement, run the tests/checks appropriate to its change, commit, self-review, and report evidence.
4. Dispatch `spec-reviewer` against the task text and actual diff. Spec failures are blocking.
5. After spec PASS, dispatch `code-reviewer`. Critical and Important findings are blocking. Minor findings may be recorded for the workstream/final review.
6. Send blocking findings back to the implementer and use `re-reviewer` on the fix diff.
7. Repeat until the task gates pass or the recovery ladder requires a materially different approach.
8. Update the durable ledger immediately.

Reviewers do not replace runtime verification. Passing code review means the implementation is credible in code; it does not prove the system works in the running environment.

## Phase 5: Workstream Gate

A workstream is not complete because all internal tasks say DONE.

After its internal tasks pass their review loops:

1. Dispatch `workstream-reviewer` with:
   - the approved workstream outcome and completion criteria
   - workstream BASE..HEAD
   - internal task summaries and outstanding Minor findings
   - verification reports available so far
2. If the reviewer returns FAIL, create internal repair tasks and run the normal implementation/review loop.
3. Dispatch `runtime-verifier` for the workstream.
4. If runtime verification FAILS, feed the concrete failure evidence into a repair task, review the repair, then re-run the relevant runtime verification.
5. Mark the workstream COMPLETE only when both the workstream review and required runtime verification are PASS.

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

1. **First repair:** resume the implementer with the exact failing evidence.
2. **If the same failure persists without a narrower diagnosis:** use a fresh implementer/reasoning context and require root-cause analysis before editing.
3. **If the local approach is exhausted:** re-plan the internal workstream decomposition or choose a materially different implementation strategy; record the ruling.
4. **Re-run static review and the affected runtime gate after every repair.** Never carry a PASS across code that changed underneath it.
5. **Declare STALLED only when materially different approaches have failed and the latest attempts produce no new diagnostic evidence.** Then ask the smallest possible user question, with the evidence and the exact decision/input needed.

A repeated failure is a reason to change the approach, not a reason to lower the gate.

## Phase 6: Mission Gate

After all workstreams are COMPLETE, verify the original mission rather than merely checking that the task list is empty.

1. Dispatch `mission-reviewer` with:
   - original approved Mission Brief
   - merge-base..HEAD for the entire mission
   - all workstream review results
   - all runtime verification evidence
   - unresolved Minor/known-risk ledger entries
2. Run final end-to-end `runtime-verifier` checks for any acceptance criteria that span multiple workstreams.
3. If either gate FAILS, create repair workstreams/tasks and continue autonomously through implementation -> review -> verification again.
4. Mission is COMPLETE only when:
   - every required workstream is COMPLETE
   - mission-reviewer = PASS
   - every required runtime/end-to-end verification = PASS
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
- Review PASS never substitutes for runtime evidence when runtime behavior is part of the goal.
- Frontend/UI behavior requires a real browser gate.
- A failed gate triggers repair and re-verification automatically.
- Do not lower a gate because repair is expensive, slow, or token-heavy.
- Do not stop just because a predefined retry count was reached.
- Never claim COMPLETE while required evidence is missing or stale.
