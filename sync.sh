#!/usr/bin/env bash
# Re-capture personal config from THIS Mac into the repo (home/ mirrors $HOME).
# Never copies credentials. Skips anything tied to work (see EXCLUDED_SKILLS).
# Hand-curated files (shell rc, gitconfig, Claude/Codex settings, git guard) are
# NOT overwritten: the script shows a diff against the live file for you to merge by hand.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
H="$REPO/home"

EXCLUDED_SKILLS=(ship verify-kiwi-live-mode rebuild-tests synced)

copy() { # copy <path relative to $HOME>
  local src="$HOME/$1" dst="$H/$1"
  [[ -e "$src" ]] || { echo "skip (missing): $1"; return; }
  mkdir -p "$(dirname "$dst")"
  rsync -a --delete --exclude .DS_Store "$src" "$(dirname "$dst")/"
  sed -i '' "s|$HOME|__HOME__|g" "$dst" 2>/dev/null || true
}

# Claude Code skills, agents, commands
excludes=(--exclude .DS_Store)
for s in "${EXCLUDED_SKILLS[@]}"; do excludes+=(--exclude "/$s"); done
mkdir -p "$H/.claude/skills"
rsync -a --delete "${excludes[@]}" "$HOME/.claude/skills/" "$H/.claude/skills/"
copy .claude/agents
copy .claude/commands
copy .claude/pstack-models.md
sed -i '' 's/Dropbox-AI-platzi-executive-assistant/Dropbox-AI-my-assistant/; s/AI platzi executive assistant/AI my assistant/' \
  "$H/.claude/skills/ai-fluency/insight.py"

# App configs
copy .config/ghostty/config
copy .config/gh/config.yml            # hosts.yml holds the token: never copied
copy .config/kilo/kilo.jsonc
copy .config/opencode/opencode.json
copy .config/opencode/opencode.jsonc
copy "Library/Application Support/Code/User/settings.json"
copy "Library/Application Support/Code/User/keybindings.json"
copy "Library/Application Support/Cursor/User/settings.json"

# Package lists
brew bundle dump --force --no-vscode --file="$REPO/Brewfile.current" >/dev/null
code --list-extensions > "$REPO/extensions/vscode.txt" 2>/dev/null || true
cursor --list-extensions > "$REPO/extensions/cursor.txt" 2>/dev/null || true
echo "Brewfile.current written: merge anything new into Brewfile by hand, then delete it."

# Curated files: show drift, never overwrite
for f in .zshrc .zprofile .gitconfig .claude/settings.json .claude/hooks/git_guard.py \
         .codex/config.toml .codex/hooks.json .codex/rules/default.rules; do
  if [[ -e "$HOME/$f" ]] && ! diff -q <(sed "s|$HOME|__HOME__|g" "$HOME/$f") "$H/$f" >/dev/null 2>&1; then
    echo "── drift in $f (live vs repo; merge by hand, keep secrets out):"
    diff <(sed "s|$HOME|__HOME__|g" "$HOME/$f") "$H/$f" | head -20 || true
  fi
done

"$REPO/check.sh"
