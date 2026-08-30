<!--
using-superpowers bootstrap rule (native Antigravity plugin channel).

Intended activation: Always On. Antigravity's Rules docs
(https://antigravity.google/docs/rules-workflows, https://antigravity.google/docs/ide/rules)
describe four per-rule activation modes — Manual, Always On, Model Decision, Glob — as a
setting "at the rule level," but do not document a file-level field (frontmatter or
otherwise) for declaring which mode applies. If this rule does not already show as
"Always On" after the plugin loads, set it manually in Antigravity's Rules panel.

This file exists so the bootstrap ships through the documented plugin `rules/` channel
(plugin.json / mcp_config.json / hooks.json / skills/ / rules/), in addition to the
existing GEMINI.md + gemini-extension.json `contextFileName` channel kept for CLI/legacy
compatibility.
-->

<!-- MIRROR: body below must stay byte-identical to skills/using-superpowers/SKILL.md (from its first heading onward). tests/antigravity/test-rule-sync.sh enforces this. The @-import form was avoided because the platform docs are self-contradictory on relative-path resolution for rule files. -->

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

**Before entering plan mode:** if `superpowers:autonomous-development` applies, invoke it directly; it owns its own alignment and broad mission planning. Otherwise, if you haven't already brainstormed, invoke the brainstorming skill first.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, create a todo per item.

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills (frontend-design, etc.) carry it out.

**Autonomous intent has priority over the normal build router.** If the user asks to build/implement a substantial goal end-to-end with minimal involvement, keep working until done, run a long autonomous session, or otherwise delegates execution rather than requesting collaborative design, invoke `superpowers:autonomous-development` directly. Do not force that request through the normal `brainstorming -> writing-plans` approval chain unless autonomous-development explicitly delegates to it.

Examples:
- "Build X end-to-end and don't stop until it works" → `superpowers:autonomous-development`
- "Take this broad plan and implement it autonomously" → `superpowers:autonomous-development`
- "Minimize my involvement; test and fix it yourself" → `superpowers:autonomous-development`
- "Let's design/build X together" → `superpowers:brainstorming` first, then implementation skills.
- "Fix this bug" → `superpowers:systematic-debugging` first, then domain skills, unless the user explicitly delegates a broader autonomous mission.

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
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## User Instructions

User instructions (GEMINI.md, AGENTS.md, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
