# Spawning a pstack role in Claude Code

Every pstack skill that names a role line (`arena runners`, `swarm workers`, `how explorer`, ...) reads its value from `~/.claude/pstack-models.md`. When the file or the line is missing, the skill's own default applies. This page says how to turn one entry into one running worker.

## Entry grammar

An entry is one of:

| Entry | Runs as |
|---|---|
| `opus`, `sonnet`, `haiku`, `fable` | Agent tool, `model` set to that value. |
| `<model>:<effort>`, e.g. `opus:xhigh` | Agent tool, `model` plus `effort` (`low`, `medium`, `high`, `xhigh`, `max`). The config file is the explicit instruction that allows setting `effort`. |
| `codex:<model>`, e.g. `codex:gpt-6.1-sol` | The Codex CLI in a background Bash command (below). Optional `:<effort>` suffix maps to `model_reasoning_effort`. |
| `inherit-parent`, `auto` | Agent tool with `model` omitted. The worker runs on the parent chat model. |

The family of an entry is `claude` for the first two rows, `codex` for the third. A skill that asks for "a different family from the parent" means: the parent is Claude, so prefer a `codex:` entry when the pool has one.

## Claude entries

Use the Agent tool. Defaults for every spawn:

- `run_in_background: true` unless your very next step needs the result.
- `subagent_type`: whatever the skill names. Read-only roles (explorers, judges, reviewers, investigators) use `subagent_type: "Explore"` when the job is locating code, otherwise `"general-purpose"` with a brief that says "read-only: do not edit, write, or commit files". Claude Code has no read-only flag, so the brief carries it.
- A worker that writes files gets `isolation: "worktree"` so parallel writers never share a checkout. `isolation: "remote"` is the cloud equivalent when it is available. A worker that must start from a specific pushed branch is told to `git switch <branch>` first in its brief.
- File pointers in the brief, not inlined context.

If the Agent tool rejects a value (an unknown model), run that seat on the skill's default for the same family and say so.

## Codex entries

Codex is the cross-family seat. It cannot be an Agent subagent, so run it through Bash with `run_in_background: true`:

```bash
codex exec -m <model> -c model_reasoning_effort=<effort|high> -s <read-only|workspace-write> \
  -C <repo-or-worktree> --skip-git-repo-check -o <out.md> - < <prompt.md> > <out.log> 2>&1
```

- Write the brief to `<prompt.md>` first: the same text a Claude seat would get, plus the skill's output contract. When the brief points at a skill or reference file, inline that file's body (frontmatter stripped), because Codex cannot load Claude skills.
- `-s read-only` for judges, reviewers, and explorers. `-s workspace-write` with `-C <its own worktree>` for a runner that writes code. Create the worktree first (`git worktree add`).
- The final answer lands in `<out.md>`. Read it when the background command finishes. The log goes to a sibling file.
- If `codex` is not on `PATH` or the run fails to start, run that seat on `opus` instead and say so in the report.

## Panels

A panel line (`arena runners`, `architect runners`, `interrogate reviewers`) is a list. One worker per entry, alias entries included, so the list length sets the count. Launch the whole panel in one message: Agent calls and Codex Bash calls side by side.
