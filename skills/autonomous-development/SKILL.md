---
name: autonomous-development
description: Use when the user wants a substantial development goal completed end-to-end with minimal human involvement, autonomous execution, or a long-running build/fix/verify loop. Owns broad planning, internal decomposition, implementation, independent review, execution verification, recovery, and final mission acceptance.
---

# Autonomous Development

Turn a broad development goal into working, verified software while minimizing human attention.

**Primary optimization target:** human attention, not tokens, agent count, test count, or elapsed time.

**Core principle:** Align once on the outcome, then keep working until the outcome is independently reviewed and independently proved on every execution surface that matters.

This is an alternative execution path to the normal `brainstorming -> writing-plans -> subagent-driven-development` flow. Do not invoke `writing-plans` for this path. The user-facing plan stays broad; detailed decomposition is internal and may change as evidence arrives.

## Process Ownership

While this skill is active, `autonomous-development` is the controlling process skill. Do **not** invoke `subagent-driven-development` as a second top-level controller. Reuse its proven spec-review, code-review, fix, and scoped re-review discipline inside this mission.

If another process skill conflicts with this mission's single-approval, continuous-execution, or gate rules, this skill owns the autonomous path unless an explicit user instruction says otherwise.

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

Resolve ambiguity yourself when the decision is reversible and can be grounded in repository code, tests, docs, established project patterns, or the approved Mission Brief. Record important decisions as rulings in the mission ledger.

Ask the user only when at least one of these is true:

1. **Product intent is genuinely underdetermined** — plausible choices create materially different user-visible behavior and repository evidence cannot resolve it.
2. **The action is irreversible or destructive** — destructive data/schema operations, irreversible migrations, deletion of user data, or equivalent risk.
3. **The action creates an external side effect that normally requires consent** — publishing, deploying, merging/pushing to a shared branch, spending money, sending messages, or changing external services.
4. **A required secret, credential, device, service, or environment is unavailable** and no local substitute can prove the requirement.
5. **The mission is genuinely stalled** after materially different recovery approaches have failed and no new diagnostic evidence is being produced.

Do not ask the user to choose implementation details merely because multiple reasonable implementations exist. Choose one, record the ruling, and continue.

## Phase 1: Mission Alignment

Explore the repository enough to understand the existing system before asking questions. Prefer repository evidence over questions.

Create a **Mission Brief** at the level the user should care about:

```markdown
# Mission: <name>

## Goal
<user-visible outcome>

## Constraints
<binding constraints and non-negotiables>

## Broad Workstreams
1. <outcome-oriented workstream>
   - Done when: <observable completion criteria>
2. <outcome-oriented workstream>
   - Done when: <observable completion criteria>

## Final Acceptance
<what must be true for the whole mission to be done>

## Verification Surfaces
<build/test/API/browser/runtime/database/CLI/etc. surfaces that require evidence>
```

### Broad Means Broad

Workstreams are user-facing outcomes, not five-minute implementation steps.

Good:
- Implement the backend contract and persistence for selection sets
- Integrate selection sets into the viewer UI
- Prove the complete selection-set flow in the running application

Bad:
- Add one DTO
- Write one test
- Change one method
- Run one command
- Commit

A workstream may require many internal tasks and repair cycles. That internal structure is the autonomous system's responsibility, not the user's.

### Approval Gate

Default to exactly **one user approval gate** before implementation: approval of the Mission Brief.

Do not ask for separate approval of each section, workstream, internal task plan, reviewer finding, fix, or verification retry.

If the user already supplied an approved broad plan and explicitly told you to execute autonomously, treat that as approval and begin without asking again.

## Phase 2: One Authoritative Mission Workspace

The mission uses **one isolated mission branch/workspace** as the authoritative implementation state.

If the parent is on main/master, create a dedicated mission feature branch before code changes. If already in an isolated feature workspace approved for this mission, keep it.

Do **not** create an isolated git branch per internal task. Antigravity `Workspace: "branch"` creates a disconnected worktree; sequential autonomous work needs every later task and every gate to see the exact accepted HEAD from prior work. Freshness comes from fresh agent context, not disconnected task branches.

Dispatch rules:

| Role | Workspace | Responsibility |
|---|---|---|
| `workstream-planner` | `inherit` | read-only internal decomposition for one broad workstream |
| `mission-implementer` | `inherit` | product-code writer for one internal task |
| `spec-reviewer` | `inherit` | task spec compliance only |
| `code-reviewer` | `inherit` | task code quality only |
| `re-reviewer` | `inherit` | scoped fix verification only |
| `workstream-reviewer` | `inherit` | broad static completeness/integration only |
| `runtime-verifier` | `inherit` | non-browser execution evidence only |
| `browser-verifier` | `inherit` | real-browser/UI evidence only |
| `failure-investigator` | `inherit` | root-cause diagnosis only; no product edits |
| `mission-reviewer` | `inherit` | final whole-mission static audit only |

**Only one product-code-writing agent may be active at a time.** Never run multiple `mission-implementer`/fixers concurrently against the shared mission workspace. Read-only agents may overlap only when no product-code write can race with their inspection.

### Baseline

Before implementation:

1. record `MISSION_BASE_SHA`
2. confirm the working tree is clean enough to distinguish mission changes from pre-existing user work
3. run relevant baseline build/tests when practical
4. classify baseline failures as pre-existing vs mission-blocking and record them

Do not ask the user merely because baseline is imperfect. Continue when failures are demonstrably pre-existing and do not prevent proving the mission.

### Durable State

Create:

```text
<repo-root>/.superpowers/missions/<mission-slug>/
  mission.md
  progress.md
  workstreams/
  evidence/
  verification/
```

Create `.superpowers/.gitignore` with `*` so mission state and temporary verification artifacts stay out of product commits.

`mission.md` contains the approved Mission Brief. `progress.md` is the durable controller state:

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
Static review:
- ...
Runtime verification:
- ...
Browser verification:
- ...
```

After compaction/session interruption, trust this ledger plus git history over conversational memory. Confirm its branch/HEAD before resuming; never make the user reconstruct progress.

## Phase 3: Internal Workstream Planning

The controller does **not** micro-plan a broad workstream in its own long-lived context.

For each PENDING workstream:

1. Freeze current mission HEAD as `WORKSTREAM_BASE_SHA`.
2. Dispatch a fresh `workstream-planner` with `Workspace: "inherit"` and give it only:
   - Mission Goal and binding constraints
   - this broad workstream and `Done when` criteria
   - current authoritative HEAD
   - interfaces produced by completed workstreams that this one depends on
   - relevant rulings/known risks
3. Planner inspects the real repository and returns coherent internal engineering tasks, dependencies, interface notes, and verification handoff surfaces.
4. If it recommends a reversible ruling, decide it in the controller, ledger it, and continue. Do not ask the user unless the Human Attention Policy applies.
5. Write the internal task map to the workstream ledger.

Internal tasks are **not user-facing** and require **no user approval**. Add, remove, split, merge, or reorder them as implementation evidence changes.

Right-size by engineering coherence, not duration. Never impose a fixed number of tasks or five-minute steps.

## Phase 4: Internal Implementation Loop

For each internal task:

```text
fresh mission-implementer
  -> spec-reviewer
  -> code-reviewer
  -> fix when needed
  -> scoped re-review
  -> task accepted
```

1. Confirm authoritative mission branch and record `TASK_BASE_SHA = HEAD`.
2. Dispatch fresh `mission-implementer` with `Workspace: "inherit"`, full task text, current workstream outcome, binding mission constraints, and relevant interfaces.
3. Implementer writes code/tests, runs appropriate checks, self-reviews, commits, and reports `TASK_BASE_SHA..TASK_HEAD_SHA`.
4. Confirm its commit is current mission HEAD. Never review stale/disconnected code.
5. Dispatch `spec-reviewer` against task text and exact diff. Any spec failure is blocking.
6. After spec PASS, dispatch `code-reviewer`. Critical and Important findings are blocking; Minor findings may be ledgered for broad/final review.
7. Send blocking findings back to the same implementer conversation. After each committed repair, dispatch `re-reviewer` on the exact fix range.
8. Continue until task gates pass or Recovery Ladder changes approach.
9. Update authoritative HEAD and ledger immediately.

**Reviewers never test.** Implementer checks are useful engineering feedback, but neither implementer test claims nor review PASS replace independent execution gates.

A task PASS is bound to exact HEAD reviewed. Relevant product-code changes make affected review evidence stale.

## Phase 5: Workstream Gate

Internal task completion does not complete a workstream.

1. Freeze `WORKSTREAM_HEAD_SHA`.
2. Dispatch `workstream-reviewer` for static outcome completeness/integration on `WORKSTREAM_BASE_SHA..WORKSTREAM_HEAD_SHA`.
3. If static review FAILS, create repair tasks, run implementation/review loops, and restart workstream gate on new HEAD.
4. Determine required execution gates from the workstream `Done when` criteria plus planner/reviewer handoffs:
   - dispatch `runtime-verifier` for non-browser executable surfaces (tests/build/API/database/CLI/service flows)
   - dispatch `browser-verifier` for **every observable frontend/UI surface**
   - cross-layer UI work normally requires both
5. Every verifier receives the same frozen `WORKSTREAM_HEAD_SHA`.
6. If any verifier FAILS, feed concrete failure evidence into a repair task, review the repair, and restart all affected workstream gates on new HEAD.
7. If a verifier is BLOCKED, exhaust local/environment alternatives before Human Attention Policy.
8. Mark workstream COMPLETE only when **static review PASS + every required execution verifier PASS** refer to the same current HEAD.

Static reviewers, runtime verifier, and browser verifier are separate authorities. None may infer another's verdict.

## Execution Verification Policy

Verification is selected from changed behavior, not a fixed ritual or fixed test count.

| Changed surface | Required independent evidence |
|---|---|
| Pure library/domain logic | `runtime-verifier`: focused tests + relevant broader suite |
| Backend/API | `runtime-verifier`: build/tests + actual service/API path when practical |
| Database/schema/query | `runtime-verifier`: migration/query/integration execution |
| CLI/tooling | `runtime-verifier`: real command + output/exit/state |
| Frontend/UI | **`browser-verifier`: real browser is mandatory** |
| Canvas/WebGL/3D viewer | **`browser-verifier`: meaningful rendering + affected interaction; DOM-only is insufficient** |
| Cross-layer UI feature | `runtime-verifier` for non-UI layers + `browser-verifier` end-to-end |
| Docs-only | relevant render/lint/link checks; no fake runtime gate |

There is no target test count. Run as many checks and repair cycles as necessary to establish fresh evidence for current HEAD.

### Frontend Browser Gate

For observable frontend changes, `browser-verifier` must exercise the affected flow in a real browser before the workstream can pass.

Relevant evidence includes:

- page/application actually loads
- affected user flow is performed
- expected visible state appears
- no new relevant console/page errors
- relevant network requests do not unexpectedly fail
- screenshots/artifacts capture tested state
- Canvas/WebGL/3D: rendering surface is meaningfully rendered and affected interaction/state is exercised

Prefer existing Playwright/Cypress/E2E harness. If none exists, `browser-verifier` may create an **ephemeral ignored** browser probe under `.superpowers/missions/<mission>/verification/`. Do not commit verification scaffolding merely to satisfy the gate.

The built-in `/browser` workflow may be used when available, but autonomous completion must not require the user to manually invoke it when a command-line browser harness can prove the same behavior.

## Recovery Ladder

Do not use a small arbitrary retry cap as a substitute for engineering judgment. Continue while attempts produce new evidence, narrow the failure, or materially change the approach.

When failure repeats:

1. **Normal repair:** resume owning `mission-implementer` with exact reviewer/verifier evidence. Diagnose and fix, then rerun affected gates.
2. **Fresh repair context:** if same failure persists without materially narrower diagnosis, stop repeating same agent context. Dispatch fresh `mission-implementer` on same mission workspace with task, current HEAD, failed evidence, and prior attempts.
3. **Independent diagnosis:** if another repair attempt still lacks better causal explanation, dispatch `failure-investigator`. It may reproduce/run focused diagnostics but never edits product code. Give root-cause report to fresh `mission-implementer` for repair.
4. **Re-plan:** if diagnosed local approach is exhausted, re-dispatch `workstream-planner` against current HEAD for materially different internal decomposition/strategy. Record controller ruling.
5. **Re-verify everything affected:** after every repair, rerun affected static and execution gates. Never carry PASS across changed code.
6. Declare `STALLED` only when materially different strategies have failed and latest investigation produces no new diagnostic evidence. Then ask smallest possible user question with exact evidence and required input.

Repeated failure is a reason to escalate **diagnosis quality**, not lower the gate.

## Phase 6: Mission Gate

After all workstreams are COMPLETE, verify the **original mission**, not whether a checklist is empty.

1. Freeze `MISSION_HEAD_SHA`.
2. Dispatch `mission-reviewer` on `MISSION_BASE_SHA..MISSION_HEAD_SHA` with original Mission Brief, constraints, workstream review reports, and unresolved non-blocking risks. It performs static whole-mission completeness/integration only.
3. If mission review FAILS, create repair workstream/tasks, run normal loops, and restart mission gate on new HEAD.
4. When mission review PASSES, dispatch the execution verifiers required by **Final Acceptance**, all on same `MISSION_HEAD_SHA`:
   - `runtime-verifier` for non-browser end-to-end criteria
   - `browser-verifier` for any frontend/UI end-to-end criterion
5. If any final verifier FAILS, create repair workstream/tasks and repeat affected static + execution gates after changes.
6. If final verifier is BLOCKED, exhaust local alternatives before escalating.
7. Mission is COMPLETE only when:
   - every required workstream is COMPLETE
   - `mission-reviewer` = PASS on current mission HEAD
   - every required final execution verifier = PASS on current mission HEAD
   - no unresolved Critical or Important finding remains
   - original user-visible goal is actually satisfied

Terminal states only:

- `COMPLETE` — independently reviewed and independently execution-verified on every required surface
- `BLOCKED` — Human Attention Policy stop condition genuinely prevents further progress

Do not report completion percentages.

## User Communication During Execution

Progress updates are informational, never approval gates.

Good:
- "Backend workstream passed static review; API verification found a serialization defect. Repair loop is active."
- "Frontend code review is clean, but browser verifier caught a broken selection flow. Fixing and re-running the gate."

Bad:
- "Task 7 finished. Continue?"
- "Reviewer found two issues. Which should I fix?"
- "Tests failed. What do you want me to do?"

Continue unless Human Attention Policy stop condition applies.

## Non-Negotiable Rules

- Optimize for minimum human intervention.
- One broad approval gate by default.
- User-facing plans contain broad outcomes, not five-minute steps.
- Internal decomposition is disposable controller state, not a contract with the user.
- Delegate detailed workstream planning to fresh planner rather than bloating controller context.
- One authoritative mission branch; no disconnected accepted task branches.
- Only one product-code writer active at a time.
- Fresh independent static review is required; implementer self-review never substitutes for it.
- Reviewers do not run tests/browser/runtime checks.
- `runtime-verifier` executes non-browser evidence but does not review/fix product code.
- `browser-verifier` is mandatory for observable frontend/UI behavior and does not review/fix product code.
- `failure-investigator` diagnoses but does not fix.
- Static PASS and all required execution PASSes are independent and all required.
- Every PASS is bound to exact HEAD it verified; relevant changes invalidate it.
- Failed gates trigger repair and re-verification automatically.
- Never lower a gate because repair is expensive, slow, or token-heavy.
- Never stop solely because predefined retry count was reached.
- Never claim COMPLETE while required evidence is missing or stale.
