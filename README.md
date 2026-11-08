# macOS personal setup

Brings a Mac to the same state as my main one: apps, CLI tools, shell, git, editors, and my Claude Code and Codex setup (skills, agents, commands, hooks). After running it, the only thing left is signing in.

The repo holds **no credentials** and nothing from work. `check.sh` enforces this.

## New Mac

```bash
git clone https://github.com/uncrayon/setup-dotfiles.git ~/Documents/setup-dotfiles
cd ~/Documents/setup-dotfiles
./setup_mac.sh          # Homebrew, Brewfile, Python, Node, Claude Code, then install.sh
source ~/.zshrc
./setup_git_github.sh   # SSH + GPG keys, commit signing (asks you to add both keys to GitHub)
```

On a brand-new Mac, the first `git` call offers to install the Xcode Command Line Tools; accept, then run the clone again.

`install.sh` is safe to re-run (for example after `git pull`). Files it replaces are saved to `~/.dotfiles-backup/<timestamp>/`.

## Logins left to do

| What | How |
|------|-----|
| GitHub CLI | `gh auth login` |
| Claude Code | `claude`, then `/login` |
| Claude, ChatGPT, Codex apps | open each and sign in |
| Codex CLI | `codex login` |
| AWS | `aws configure` or `aws login` |
| Hugging Face | `hf auth login` |
| Cursor, VS Code | sign in for settings sync and AI features |
| Slack, Discord, Zoom, Notion, Obsidian sync | open and sign in |
| Tailscale, NordVPN | open and sign in |
| Docker Desktop | open once to finish setup |
| Chrome / Helium | sign in to sync |
| Claude Code Slack plugin | `/mcp` inside Claude Code |

Secrets for the shell go in `~/.zshrc.local` (loaded automatically, never committed).

## What's in the repo

| Path | Contents |
|------|----------|
| `Brewfile` | CLI tools, apps, VS Code extensions, `uv` tools |
| `extensions/cursor.txt` | Cursor extensions |
| `home/` | Mirrors `$HOME`: `.zshrc`, `.zprofile`, `.gitconfig`, Ghostty, gh, OpenCode, Kilo, VS Code and Cursor settings |
| `home/.claude/` | Claude Code settings, skills, agents, commands, git-guard hook, pstack models |
| `home/.codex/` | Codex config, hooks, rules (skills and git guard are copied from `home/.claude/`) |
| `setup_mac.sh` | Full bootstrap for a new Mac |
| `install.sh` | Copies `home/` into `$HOME` |
| `setup_git_github.sh` | Git identity, SSH and GPG keys |
| `sync.sh` | Re-captures config from the main Mac |
| `check.sh` | Fails if the repo contains secrets or work references |

Paths are stored as `__HOME__` and replaced with your home folder on install.

## Updating from the main Mac

```bash
./sync.sh          # copies skills, agents, commands, app configs, package lists; runs check.sh
git diff           # review
```

`sync.sh` never touches the hand-curated files (`.zshrc`, `.zprofile`, `.gitconfig`, Claude `settings.json`, the git guard, Codex config). It prints how the live versions differ so you can merge changes by hand without bringing tokens or work settings along. New packages land in `Brewfile.current`; move what you want into `Brewfile`.

Work-specific skills are listed in `EXCLUDED_SKILLS` in `sync.sh`. Run `./check.sh` before every commit.

## Troubleshooting

- **GPG signing hangs:** `gpgconf --kill gpg-agent && export GPG_TTY=$(tty)`
- **`brew` not found:** `eval "$(/opt/homebrew/bin/brew shellenv)"`
- **Ghostty shows broken icons:** check the Nerd Font with `ghostty +list-fonts`
- **GPG key expired** (1-year expiry): `gpg --edit-key <KEY_ID>`, then `expire`
