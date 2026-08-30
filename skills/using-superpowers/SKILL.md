---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if `superpowers:autonomous-development` applies, invoke it directly. Otherwise, if you haven't already brainstormed, invoke the brainstorming skill first.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, create a todo per item.

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills (frontend-design, etc.) carry it out.

**Autonomous intent has priority over the normal build router.** If the user supplies a markdown plan and asks you to execute it from start to finish, or otherwise delegates a substantial goal with minimal involvement, invoke `superpowers:autonomous-development` directly. An explicitly supplied plan plus an execution instruction is already approved; do not force it through `brainstorming -> writing-plans` again.

Examples:
- "Execute task.md autonomously from start to finish" → `superpowers:autonomous-development`
- "Take this broad plan and implement it autonomously" → `superpowers:autonomous-development`
- "Build X end-to-end and don't stop until it works" → `superpowers:autonomous-development`
- "Minimize my involvement; test and fix it yourself" → `superpowers:autonomous-development`
- "Let's design/build X together" → `superpowers:brainstorming` first, then implementation skills.
- "Fix this bug" → `superpowers:systematic-debugging` first, unless the user explicitly delegates a broader autonomous mission.

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check first. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check first. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using it. Invoke the skill. |

## User Instructions

User instructions (GEMINI.md, AGENTS.md, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
