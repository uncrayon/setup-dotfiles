#!/usr/bin/env bash
# =============================================================================
# Git + SSH + GPG Setup for GitHub
# =============================================================================
# Auth:  SSH
# Sign:  GPG
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

section() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $*${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ── 0. User info ────────────────────────────────────────────────────────────
section "User info"

read -rp "Full name (for Git commits): " GIT_NAME
read -rp "Email (for Git commits): " GIT_EMAIL
read -rp "GitHub username: " GIT_USER

if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" || -z "$GIT_USER" ]]; then
  echo -e "${RED}[FAIL]${NC}  All fields are required."
  exit 1
fi

echo ""
info "Name:     $GIT_NAME"
info "Email:    $GIT_EMAIL"
info "GitHub:   $GIT_USER"
echo ""
read -rp "Is this correct? (y/n) " CONFIRM
if [[ "$CONFIRM" != [yY] ]]; then
  info "Aborted. Re-run the script to try again."
  exit 0
fi

# ── 1. Git global config ─────────────────────────────────────────────────────
section "1. Git global configuration"

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global push.autoSetupRemote true

success "Git identity set to: $GIT_NAME <$GIT_EMAIL>"

# ── 2. SSH key for GitHub auth ───────────────────────────────────────────────
section "2. SSH key (GitHub authentication)"

SSH_KEY="$HOME/.ssh/id_ed25519"

if [[ -f "$SSH_KEY" ]]; then
  warn "SSH key already exists at $SSH_KEY — skipping generation"
else
  info "Generating Ed25519 SSH key..."
  mkdir -p "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
  success "SSH key generated"
fi

# Start ssh-agent and add key
eval "$(ssh-agent -s)" > /dev/null 2>&1

# Create/update SSH config for macOS keychain integration
SSH_CONFIG="$HOME/.ssh/config"
if ! grep -q "github.com" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<EOF

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile $SSH_KEY
EOF
  success "SSH config updated for GitHub"
else
  success "SSH config already has GitHub entry"
fi

ssh-add --apple-use-keychain "$SSH_KEY" 2>/dev/null || ssh-add "$SSH_KEY"
success "SSH key added to agent"

echo ""
echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Copy the SSH public key below and add it to GitHub:        ║${NC}"
echo -e "${YELLOW}║  → https://github.com/settings/ssh/new                     ║${NC}"
echo -e "${YELLOW}║  Title: \"Mac\" (or whatever you like)                        ║${NC}"
echo -e "${YELLOW}║  Key type: Authentication Key                               ║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
cat "${SSH_KEY}.pub"
echo ""

read -rp "Press Enter once you've added the SSH key to GitHub..."

# Test SSH connection
info "Testing SSH connection to GitHub..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  success "SSH authentication with GitHub works!"
else
  warn "Could not verify SSH auth — you may need to add the key to GitHub still"
fi

# ── 3. GPG key for commit signing ────────────────────────────────────────────
section "3. GPG key (commit signing)"

# Install gnupg if missing
if ! command -v gpg &>/dev/null; then
  info "Installing GnuPG..."
  brew install gnupg
  success "GnuPG installed"
else
  success "GnuPG already installed"
fi

# Also install pinentry-mac for passphrase prompts
if ! brew list pinentry-mac &>/dev/null; then
  info "Installing pinentry-mac..."
  brew install pinentry-mac
fi

# Configure gpg-agent to use pinentry-mac
mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"

GPG_AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
PINENTRY_PATH="$(brew --prefix)/bin/pinentry-mac"
if ! grep -q "pinentry-mac" "$GPG_AGENT_CONF" 2>/dev/null; then
  echo "pinentry-program $PINENTRY_PATH" > "$GPG_AGENT_CONF"
  echo "default-cache-ttl 28800" >> "$GPG_AGENT_CONF"
  echo "max-cache-ttl 28800" >> "$GPG_AGENT_CONF"
  gpgconf --kill gpg-agent 2>/dev/null || true
  success "gpg-agent configured with pinentry-mac (8h cache)"
fi

# Check for existing GPG key for this email
EXISTING_KEY=$(gpg --list-secret-keys --keyid-format long "$GIT_EMAIL" 2>/dev/null | grep -m1 "sec" | awk -F'/' '{print $2}' | awk '{print $1}' || true)

if [[ -n "$EXISTING_KEY" ]]; then
  warn "Existing GPG key found for $GIT_EMAIL: $EXISTING_KEY — skipping generation"
  GPG_KEY_ID="$EXISTING_KEY"
else
  info "Generating GPG key (RSA 4096)..."

  # Batch generate key (no interactive prompts)
  gpg --batch --gen-key <<EOF
    Key-Type: RSA
    Key-Length: 4096
    Subkey-Type: RSA
    Subkey-Length: 4096
    Name-Real: $GIT_NAME
    Name-Email: $GIT_EMAIL
    Expire-Date: 1y
    %commit
EOF
  success "GPG key generated (expires in 1 year)"

  GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format long "$GIT_EMAIL" 2>/dev/null | grep -m1 "sec" | awk -F'/' '{print $2}' | awk '{print $1}')
fi

# Configure git to use this GPG key
git config --global user.signingkey "$GPG_KEY_ID"
git config --global commit.gpgsign true
git config --global tag.gpgSign true
git config --global gpg.program "$(which gpg)"

success "Git configured to sign all commits with GPG key: $GPG_KEY_ID"

# Export public key
echo ""
echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Copy the GPG public key below and add it to GitHub:        ║${NC}"
echo -e "${YELLOW}║  → https://github.com/settings/gpg/new                     ║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
gpg --armor --export "$GPG_KEY_ID"
echo ""

read -rp "Press Enter once you've added the GPG key to GitHub..."

# ── 4. Ensure GPG_TTY is set in shell ────────────────────────────────────────
section "4. Shell config"

ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

if ! grep -qF 'GPG_TTY' "$ZSHRC"; then
  echo -e '\n# GPG signing\nexport GPG_TTY=$(tty)' >> "$ZSHRC"
  success "Added GPG_TTY to .zshrc"
else
  success "GPG_TTY already in .zshrc"
fi

# ── 5. Verify everything ─────────────────────────────────────────────────────
section "Verification"

echo ""
echo "  Git identity:"
echo "    Name:       $(git config --global user.name)"
echo "    Email:      $(git config --global user.email)"
echo "    Signing:    $(git config --global commit.gpgsign)"
echo "    GPG key:    $(git config --global user.signingkey)"
echo ""
echo "  SSH key:      ${SSH_KEY}.pub"
echo "  GPG key ID:   $GPG_KEY_ID"
echo ""

# Quick signing test
info "Testing commit signing (dry run)..."
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q
git commit --allow-empty -m "test: verify GPG signing" -q 2>/dev/null && \
  success "Commit signing works!" || \
  warn "Signing test failed — you may need to restart your terminal and try again"
rm -rf "$TMPDIR"

echo ""
echo -e "${GREEN}  All done! Your commits will now show as 'Verified' on GitHub.${NC}"
echo ""
