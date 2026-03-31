# macOS Dev Setup — Data Science / ML Engineering

Automated setup scripts for a fresh macOS machine. Designed for a data science and ML engineering workflow.

## What's included

### `setup_mac.sh` — Core tools

| Category | Tools |
|----------|-------|
| Terminal | Ghostty + MesloLGM Nerd Font + config |
| IDEs | Cursor, VS Code + extensions |
| Python | uv, pyenv, Python 3.11 & 3.12 |
| Node | nvm, latest LTS |
| AI | Claude Code (native CLI), Claude Desktop |
| Video | ffmpeg, yt-dlp, ImageMagick, MediaInfo |
| Cloud | AWS CLI |
| Apps | Chrome, Slack, Zoom, Obsidian, DBeaver, Cloudflare WARP |
| CLI Tools | gh, fzf, ripgrep, fd, bat, eza, tree, tldr, zoxide, starship |
| Extras | Docker, tmux, btop, jq, yq |

#### VS Code extensions installed automatically

- `anthropic.claude-code` — Claude Code
- `kilocode.kilo-code` — Kilo Code
- `ms-python.python` / `ms-python.vscode-pylance` / `ms-python.debugpy` / `ms-python.vscode-python-envs` — Python
- `ms-azuretools.vscode-containers` / `ms-vscode-remote.remote-containers` — Docker & Remote Containers
- `ms-kubernetes-tools.vscode-kubernetes-tools` — Kubernetes
- `ms-vscode.makefile-tools` — Makefile
- `redhat.vscode-yaml` — YAML

### `setup_git_github.sh` — Git + GitHub

- Git global config (identity, default branch, rebase on pull)
- SSH key generation and GitHub auth
- GPG key generation (RSA 4096, 1-year expiry)
- Automatic commit signing
- pinentry-mac for passphrase prompts
- Shell config (GPG_TTY)

## Requirements

- macOS 13 (Ventura) or later
- Admin access (for Homebrew and Xcode CLT)

## Usage

### 1. Clone this repo

```bash
git clone git@github.com:uncrayon/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Or on a fresh machine without git/SSH yet, download manually:

```bash
curl -LO https://github.com/uncrayon/dotfiles/archive/refs/heads/main.zip
unzip main.zip
cd dotfiles-main
```

### 2. Run the main setup

```bash
chmod +x setup_mac.sh
./setup_mac.sh
```

This installs Homebrew (if needed), all CLI tools, GUI apps, VS Code extensions, Python versions, Node, and Claude Code. It's idempotent — safe to re-run if something fails halfway through.

### 3. Restart your terminal

```bash
source ~/.zshrc
```

Or just close and reopen your terminal.

### 4. Run the Git + GitHub setup

```bash
chmod +x setup_git_github.sh
./setup_git_github.sh
```

The script will pause twice and ask you to add keys to GitHub:

1. **SSH key** — copy the printed public key to [github.com/settings/ssh/new](https://github.com/settings/ssh/new) with key type "Authentication Key"
2. **GPG key** — copy the full key block to [github.com/settings/gpg/new](https://github.com/settings/gpg/new)

### 5. Post-install steps

- **Docker**: open Docker.app once to complete its setup and grant permissions
- **Python**: set your default version with `pyenv global 3.12.x`
- **AWS**: run `aws configure` (or `aws configure sso` for SSO)

## Ghostty config

The Ghostty config is stored at `configs/ghostty/config` and automatically copied to `~/.config/ghostty/config` during setup. To customize, edit the file in this repo and re-run the script, or edit `~/.config/ghostty/config` directly.

Browse themes: `ghostty +list-themes`

## Verification

After both scripts finish, confirm everything works:

```bash
# Homebrew
brew --version

# Git + GitHub SSH
ssh -T git@github.com

# GPG signing
echo "test" | gpg --clearsign

# Python
pyenv versions
uv python list

# Node
node --version
npm --version

# Claude Code
claude --version

# AWS
aws --version

# Video tools
ffmpeg -version
```

## Troubleshooting

**GPG signing hangs**: the gpg-agent probably lost its TTY. Fix with:

```bash
gpgconf --kill gpg-agent
export GPG_TTY=$(tty)
```

**`brew` not found after install**: add Homebrew to your PATH manually:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**`nvm` not found**: reload your shell config:

```bash
source ~/.zshrc
```

**Ghostty shows broken icons**: make sure you're using a Nerd Font. Run `ghostty +list-fonts` to verify it's detected.

## Notes

- Both scripts are idempotent. Re-running them skips anything already installed.
- The GPG key expires in 1 year. Renew it with `gpg --edit-key <KEY_ID>` then `expire`.
- Shell modifications only append to `~/.zshrc` if the line isn't already present.
