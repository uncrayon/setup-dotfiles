#!/usr/bin/env bash
# =============================================================================
# macOS personal setup
# =============================================================================
# Usage:  chmod +x setup_mac.sh && ./setup_mac.sh
#
# What this does:
#   1. Xcode Command Line Tools and Homebrew (if missing)
#   2. Everything in Brewfile: CLI tools, apps, VS Code extensions
#   3. Python 3.11 and 3.12 (pyenv + uv), Node LTS (nvm), Claude Code
#   4. install.sh: shell, git, editor, Claude Code and Codex configs and skills
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

# ── Packages and apps (Brewfile) ─────────────────────────────────────────────
section "Brewfile — CLI tools, apps, VS Code extensions"
REPO="$(cd "$(dirname "$0")" && pwd)"
brew bundle --file="$REPO/Brewfile" || warn "Some Brewfile entries failed — re-run later or check the output above"

# ── Python tooling ───────────────────────────────────────────────────────────
section "Python — uv + pyenv"

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

# ── Configs, skills, editor settings ────────────────────────────────────────
section "Configs (install.sh)"
"$REPO/install.sh"

# ── Summary ──────────────────────────────────────────────────────────────────
section "Setup complete!"

echo ""
echo "  Installed everything in Brewfile plus configs from home/."
echo ""
echo "  Next steps:"
echo "    1. Restart your terminal (or run: source ~/.zshrc)"
echo "    2. Run ./setup_git_github.sh to configure Git + SSH + GPG"
echo "    3. Open Docker.app once to finish its setup"
echo "    4. Set your default Python:  pyenv global <version>"
echo "    5. Do the logins listed in README.md"
echo ""
