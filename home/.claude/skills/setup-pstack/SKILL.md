---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Detects the available models and writes ~/.claude/pstack-models.md, which overrides the skill defaults. Use for /setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

Write `~/.claude/pstack-models.md`, the file every pstack skill reads to pick its model per role. How an entry becomes a running worker is in `references/spawning.md`. Read it first.

## Steps

### 1. Detect available models

The Claude seats are always available: `opus`, `sonnet`, `haiku`, `fable` (Agent tool `model` values). The cross-family seat is the Codex CLI: run `command -v codex` and `codex --version`. If it is present, ask which Codex model slug to use (the user's usual one is `gpt-6.1-sol`) unless the existing file already names one. Never write a `codex:` entry when `codex` is not installed. The aliases `inherit-parent` and `auto` are always valid.

### 2. Load current state

The default role-to-model mapping is the file shape in step 5. If `~/.claude/pstack-models.md` already exists, read it and treat its `# budget` line and its role values as the current choices. Otherwise start from the defaults. A line whose role is not in step 5 is from a retired role. Drop it.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Use AskUserQuestion with these four options and these exact labels, and name the current budget when the file records one. With no file, say that `large` matches the skill defaults.

- `unlimited — max reasoning`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** The budget sets the effort suffix of every real entry, panel entries included: `unlimited` → `:max`, `large` → `:xhigh`, `medium` → `:high`, `small` → `:medium`. So under `small`, `opus:xhigh` becomes `opus:medium`. Codex entries take the same suffix, capped at `xhigh`. `inherit-parent` and `auto` do not change. On a re-run keep any role the user changed by model or list.

**(c) Show the roles and confirm.** Show every role with its value, and list each line step 2 dropped. Ask whether to accept as-is or change specific roles. Offer `opus`, `sonnet`, `haiku`, `fable`, the detected `codex:<model>`, `inherit-parent`, and `auto`. Use AskUserQuestion. Panel roles (arena runners, architect runners, interrogate reviewers) take a list, and one worker runs per entry. `arena cross-judge pool` is also a list, but Arena selects one entry whose family differs from the parent's (Codex, since the parent is Claude) when possible. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every model name must be one of the Claude values or a `codex:` entry whose CLI exists. Effort suffixes must be `low`, `medium`, `high`, `xhigh`, or `max`. If a choice fails, stop and ask again.

### 5. Write the file

Overwrite `~/.claude/pstack-models.md` in full so re-runs stay idempotent. Shape, with the `large` defaults:

```
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
swarm workers: sonnet:xhigh
architect runners: opus:xhigh, codex:gpt-6.1-sol:xhigh
interrogate reviewers: opus:xhigh, codex:gpt-6.1-sol:xhigh
```

Without Codex, panel lines use `opus:xhigh, sonnet:xhigh` instead.

### 6. Confirm

Tell the user the file was written. Skills read it at run time, so it applies from the next skill invocation. Re-running this skill updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill under `.claude/skills/`, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /create-verification-skill." On yes, invoke `/create-verification-skill`. On no, move on without pushing.
