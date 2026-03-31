#!/usr/bin/env bash
# =============================================================================
# macOS Dev Setup — Data Science / ML Engineering
# =============================================================================
# Usage:  chmod +x setup_mac.sh && ./setup_mac.sh
#
# What this installs:
#   - Homebrew (if missing)
#   - Ghostty terminal + Nerd Font + config
#   - Git
#   - Python tooling: uv, pyenv, Python 3.11 & 3.12
#   - Node tooling: nvm, latest LTS Node
#   - IDEs: Cursor, VS Code + extensions
#   - AI: Claude Code (native installer), Claude Desktop
#   - Video tools: ffmpeg, yt-dlp, ImageMagick, MediaInfo
#   - Cloud: AWS CLI
#   - Apps: Chrome, Slack, Zoom, Obsidian, DBeaver, Cloudflare WARP
#   - CLI power tools: gh, fzf, ripgrep, fd, bat, eza, tree, tldr, zoxide, starship
#   - Extras: Docker, tmux, btop, jq, yq
# =============================================================================

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $*"; }

section() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $*${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ── Pre-flight checks ────────────────────────────────────────────────────────
section "Pre-flight checks"

if [[ "$(uname)" != "Darwin" ]]; then
  fail "This script is for macOS only."
  exit 1
fi

if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools (this may take a while)..."
  xcode-select --install
  echo "Press Enter once the Xcode CLT installation finishes."
  read -r
else
  success "Xcode Command Line Tools already installed"
fi

# ── Homebrew ─────────────────────────────────────────────────────────────────
section "Homebrew"

if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  success "Homebrew installed"
else
  success "Homebrew already installed ($(brew --version | head -1))"
fi

info "Updating Homebrew..."
brew update

# ── Helper ───────────────────────────────────────────────────────────────────
brew_install() {
  local pkg="$1"
  local type="${2:-formula}"

  if [[ "$type" == "cask" ]]; then
    if brew list --cask "$pkg" &>/dev/null; then
      success "$pkg (cask) already installed"
    else
      info "Installing $pkg (cask)..."
      if brew install --cask --adopt "$pkg" 2>/dev/null; then
        success "$pkg installed"
      else
        warn "$pkg install failed (app may already exist or cask unavailable) — skipping"
      fi
    fi
  else
    if brew list "$pkg" &>/dev/null; then
      success "$pkg already installed"
    else
      info "Installing $pkg..."
      brew install "$pkg"
      success "$pkg installed"
    fi
  fi
}

# ── Terminal ─────────────────────────────────────────────────────────────────
section "Terminal — Ghostty + Nerd Font"
brew_install font-meslo-lg-nerd-font cask
brew_install ghostty cask

# Copy Ghostty config if running from the repo directory
GHOSTTY_SRC="$(cd "$(dirname "$0")" && pwd)/configs/ghostty/config"
if [[ -f "$GHOSTTY_SRC" ]]; then
  mkdir -p "$HOME/.config/ghostty"
  cp "$GHOSTTY_SRC" "$HOME/.config/ghostty/config"
  success "Ghostty config installed"
fi

# ── Git ──────────────────────────────────────────────────────────────────────
section "Git"
brew_install git

# ── IDEs ─────────────────────────────────────────────────────────────────────
section "IDEs — Cursor & VS Code"
brew_install cursor cask
brew_install visual-studio-code cask

# ── Python tooling ───────────────────────────────────────────────────────────
section "Python — uv + pyenv"

brew_install uv
brew_install pyenv

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true

for PY_VERSION in 3.11 3.12; do
  LATEST=$(pyenv install --list | tr -d ' ' | grep "^${PY_VERSION}\." | grep -v '[a-zA-Z]' | tail -1)
  if [[ -n "$LATEST" ]]; then
    if pyenv versions --bare | grep -q "^${LATEST}$"; then
      success "Python $LATEST already installed (pyenv)"
    else
      info "Installing Python $LATEST via pyenv..."
      pyenv install -s "$LATEST"
      success "Python $LATEST installed"
    fi
  else
    warn "Could not find a stable release for Python ${PY_VERSION}.x"
  fi
done

info "Registering Python versions with uv..."
uv python install 3.11 3.12 2>/dev/null && success "uv Python installs done" || warn "uv python install had issues (non-fatal)"

# ── Node tooling ─────────────────────────────────────────────────────────────
section "Node — nvm + LTS"

export NVM_DIR="$HOME/.nvm"

if [[ ! -d "$NVM_DIR" ]]; then
  info "Installing nvm..."
  PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh)"
  success "nvm installed"
else
  success "nvm already installed"
fi

# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

info "Installing Node LTS..."
nvm install --lts
nvm use --lts
nvm alias default lts/*
success "Node $(node --version) active"

# ── Claude Code ──────────────────────────────────────────────────────────────
section "Claude Code (CLI)"

if command -v claude &>/dev/null; then
  success "Claude Code already installed ($(claude --version 2>/dev/null || echo 'unknown'))"
else
  info "Installing Claude Code via native installer..."
  curl -fsSL https://claude.ai/install.sh | bash
  success "Claude Code installed"
fi

# ── Video tools ──────────────────────────────────────────────────────────────
section "Video & Image tools"
brew_install ffmpeg
brew_install yt-dlp
brew_install imagemagick
brew_install media-info

# ── Cloud ────────────────────────────────────────────────────────────────────
section "Cloud — AWS CLI"
brew_install awscli

# ── Apps ─────────────────────────────────────────────────────────────────────
section "Apps"
brew_install claude cask
brew_install google-chrome cask
brew_install slack cask
brew_install zoom cask
brew_install obsidian cask
brew_install dbeaver-community cask
brew_install cloudflare-warp cask

# ── CLI Power Tools ─────────────────────────────────────────────────────────
section "CLI Power Tools"
brew_install gh
brew_install fzf
brew_install ripgrep
brew_install fd
brew_install bat
brew_install eza
brew_install tree
brew_install tldr
brew_install zoxide
brew_install starship

# ── Extras ───────────────────────────────────────────────────────────────────
section "Extras"
brew_install docker-desktop cask
brew_install tmux
brew_install btop
brew_install jq
brew_install yq

# ── VS Code Extensions ───────────────────────────────────────────────────────
section "VS Code Extensions"

VSCODE_EXTENSIONS=(
  "anthropic.claude-code"
  "kilocode.kilo-code"
  "ms-azuretools.vscode-containers"
  "ms-kubernetes-tools.vscode-kubernetes-tools"
  "ms-python.debugpy"
  "ms-python.python"
  "ms-python.vscode-pylance"
  "ms-python.vscode-python-envs"
  "ms-vscode-remote.remote-containers"
  "ms-vscode.makefile-tools"
  "redhat.vscode-yaml"
)

if command -v code &>/dev/null; then
  for ext in "${VSCODE_EXTENSIONS[@]}"; do
    info "Installing VS Code extension: $ext"
    code --install-extension "$ext" --force 2>/dev/null || warn "Failed to install $ext"
  done
  success "VS Code extensions installed"
else
  warn "VS Code CLI not found — skipping extensions (open VS Code and run 'Install code command in PATH')"
fi

# ── Shell configuration ─────────────────────────────────────────────────────
section "Shell config (~/.zshrc)"

ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

append_if_missing() {
  local line="$1"
  local comment="${2:-}"
  if ! grep -qF "$line" "$ZSHRC"; then
    [[ -n "$comment" ]] && echo -e "\n# $comment" >> "$ZSHRC"
    echo "$line" >> "$ZSHRC"
    success "Added to .zshrc: $line"
  else
    success "Already in .zshrc: $line"
  fi
}

if [[ -f /opt/homebrew/bin/brew ]]; then
  append_if_missing 'eval "$(/opt/homebrew/bin/brew shellenv)"' "Homebrew"
elif [[ -f /usr/local/bin/brew ]]; then
  append_if_missing 'eval "$(/usr/local/bin/brew shellenv)"' "Homebrew"
fi

append_if_missing 'export PYENV_ROOT="$HOME/.pyenv"' "pyenv"
append_if_missing 'export PATH="$PYENV_ROOT/bin:$PATH"'
append_if_missing 'eval "$(pyenv init -)"'

append_if_missing 'export NVM_DIR="$HOME/.nvm"' "nvm"
append_if_missing '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
append_if_missing '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'

append_if_missing 'eval "$(starship init zsh)"' "Starship prompt"
append_if_missing 'eval "$(zoxide init zsh)"' "Zoxide (smarter cd)"

# ── Summary ──────────────────────────────────────────────────────────────────
section "Setup complete!"

echo ""
echo "  Installed:"
echo "    Terminal    → Ghostty + MesloLGM Nerd Font + config"
echo "    IDEs        → Cursor, VS Code + extensions"
echo "    Python      → uv, pyenv, Python 3.11 & 3.12"
echo "    Node        → nvm + LTS ($(node --version 2>/dev/null || echo 'restart shell'))"
echo "    AI          → Claude Code (CLI), Claude Desktop"
echo "    Video       → ffmpeg, yt-dlp, ImageMagick, MediaInfo"
echo "    Cloud       → AWS CLI"
echo "    Apps        → Chrome, Slack, Zoom, Obsidian, DBeaver, Cloudflare WARP"
echo "    CLI Tools   → gh, fzf, ripgrep, fd, bat, eza, tree, tldr, zoxide, starship"
echo "    Extras      → Docker, tmux, btop, jq, yq"
echo ""
echo "  Next steps:"
echo "    1. Restart your terminal (or run: source ~/.zshrc)"
echo "    2. Run ./setup_git_github.sh to configure Git + SSH + GPG"
echo "    3. Open Docker.app once to finish its setup"
echo "    4. Set your default Python:  pyenv global <version>"
echo "    5. Configure AWS:  aws configure"
echo ""
