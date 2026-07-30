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
compatibility. Both channels resolve to the same skill content below via an `@` import,
per the docs: "You can reference other files using @filename in a Rules file. If filename
is a relative path, it will be interpreted relative to the location of the Rules file."
-->

@../skills/using-superpowers/SKILL.md
