# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# Entry grammar and spawn rules: ~/.claude/skills/setup-pstack/references/spawning.md
# `inherit-parent` or `auto`: the role runs on the parent chat model (omit Agent `model`). Alias entries in a panel list still count toward its fan-out.
# budget: large (xhigh)
feature, refactoring: sonnet:xhigh
bug-fix: sonnet:xhigh
perf-issue: sonnet:xhigh
hillclimb: sonnet:xhigh
judgment and prose: opus:xhigh
hardest tasks: opus:xhigh
how explorer: sonnet:xhigh
how explainer: opus:xhigh
why investigators: sonnet:xhigh
why synthesizer: opus:xhigh
reflect tooling: sonnet:xhigh
reflect judgment, divergent, synthesizer: opus:xhigh
arena runners: opus:xhigh, codex:gpt-6.1-sol:xhigh
arena cross-judge pool: opus:xhigh, codex:gpt-6.1-sol:xhigh
swarm workers: sonnet:high
architect runners: opus:xhigh, codex:gpt-6.1-sol:xhigh
interrogate reviewers: opus:xhigh, codex:gpt-6.1-sol:xhigh
