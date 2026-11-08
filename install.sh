#!/usr/bin/env bash
# Copy the configs in home/ into $HOME on this Mac. Safe to re-run.
# Any file it would overwrite is first saved under ~/.dotfiles-backup/<timestamp>/.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
H="$REPO/home"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

echo "Installing configs into $HOME (backups in $BACKUP)"
rsync -a --backup --backup-dir="$BACKUP" --exclude .DS_Store "$H/" "$HOME/"

# Codex shares Claude's skills and git guard
mkdir -p "$HOME/.codex/skills" "$HOME/.codex/hooks"
rsync -a --backup --backup-dir="$BACKUP/.codex/skills" "$H/.claude/skills/" "$HOME/.codex/skills/"
cp "$H/.claude/hooks/git_guard.py" "$HOME/.codex/hooks/git_guard.py"

# Files with machine paths were stored as __HOME__
(cd "$H" && grep -rlI "__HOME__" . || true) | while read -r f; do
  sed -i '' "s|__HOME__|$HOME|g" "$HOME/${f#./}"
done

# Personal command skills that OpenCode reads from (public repo)
if [[ ! -d "$HOME/Documents/claude-code-skills" ]]; then
  git clone https://github.com/uncrayon/cc-skills.git "$HOME/Documents/claude-code-skills"
fi

# Cursor extensions
if command -v cursor &>/dev/null; then
  while read -r ext; do
    [[ -n "$ext" ]] && cursor --install-extension "$ext" --force >/dev/null 2>&1 || echo "  cursor: failed $ext"
  done < "$REPO/extensions/cursor.txt"
fi

echo "Done. Open a new terminal to load the shell config."
