# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# Prompt and smarter cd
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# GPG signing
export GPG_TTY=$(tty)

# User binaries (Claude Code, uv tools)
export PATH="$HOME/.local/bin:$PATH"

# Antigravity and LM Studio CLIs (present once the apps are opened)
[ -d "$HOME/.antigravity/antigravity/bin" ] && export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
[ -d "$HOME/.lmstudio/bin" ] && export PATH="$PATH:$HOME/.lmstudio/bin"

# Tailscale CLI bundled with the app
if ! command -v tailscale >/dev/null && [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

# Google Cloud SDK (if installed)
[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/google-cloud-sdk/completion.zsh.inc"

# Machine-specific settings and secrets (never committed)
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
