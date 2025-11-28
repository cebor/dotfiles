# Copilot Instructions for Dotfiles

## Architecture Overview

This is a macOS dotfiles configuration system using a **two-phase structure**:
- **Configuration files** in `git/` and `system/` directories (synced via rsync to `$HOME`)
- **Setup scripts** at root level (orchestrate installation and system configuration)

### Key Components

- `bootstrap.sh` - One-time setup: Xcode CLI tools, Homebrew, shell change, git user (run once)
- `install.sh` - Full installation: auto-runs bootstrap if needed, then syncs dotfiles and installs packages
- `update.sh` - Regular updates: sync dotfiles, update packages, reconfigure vim and git (safe to re-run)
- `sync.sh` - Syncs dotfiles from `git/` and `system/` to home directory using rsync (excludes `.DS_Store` and `.gitconfig`)
- `git.sh` - Applies git config settings from template (preserves user.name/email)
- `brew.sh` - Installs/updates Homebrew and applies `Brewfile`
- `macos.sh` - Configures macOS defaults via `defaults write` commands
- `vim.sh` - Sets up vim directories and installs/updates vim-plug


## Critical Workflows

### First-Time Setup
Just run `./install.sh` - it auto-detects if bootstrap is needed and runs it, then completes full installation. Finish with `exec zsh` to reload shell.

### Regular Updates
Run `./update.sh` to sync dotfiles, update packages, and reconfigure git/vim (safe to re-run anytime)

### Testing Changes
- Dry-run preview: `./sync.sh -d` or `./sync.sh --dry-run`
- Dotfile changes: `./sync.sh -f` (force sync without confirmation)
- Brew packages: `brew bundle` (reads `Brewfile`)
- macOS settings: `./macos.sh` (requires logout/restart to fully apply)

### Shell Configuration Structure
`.zshrc` sources three modular files:
1. `.exports` - Environment variables (GPG_TTY, LANG)
2. `.aliases` - Command shortcuts (py, k9, ecr/dcr gpg helpers, wttr weather)
3. `.functions` - Shell functions (f, server, scpp, tunnel, svenv)

Uses **antidote** plugin manager loading from `.zsh_plugins.txt` (omz plugins + zsh-users utilities)

## Project Conventions

### Shell Scripts
- All scripts use `#!/usr/bin/env bash` shebang
- Scripts cd to their own directory: `cd "$(dirname "$0")"`
- User prompts for destructive operations (except with `-f`/`--force`)
- No error handling by design - scripts fail fast

### Dotfile Organization
- `git/` - Git-specific config (`.gitignore_global`, `.gitattributes_global`) - **no .gitconfig file**
- `system/` - Shell and application dotfiles (zsh, vim, tmux, ssh)
- Git config applied via `git.sh` using `git config --global` commands
- Git user.name/email set during `bootstrap.sh` using `[ -z "$(git config --global user.name)" ]` check, preserved by `git.sh`

### Homebrew Pattern
`Brewfile` uses three sections:
1. `brew` - CLI tools (coreutils, zsh, python, kubernetes-cli)
2. `cask` - GUI applications (iterm2, vscode, docker)
3. `mas` - Mac App Store apps (requires app IDs)

### Editor Preferences
- Primary editor: **helix** (`hx` in git config)
- Vim configured with vim-plug, Solarized theme, persistent undo
- EditorConfig: 2-space indentation, LF line endings

## Integration Points

### External Dependencies
- Homebrew install script from GitHub (`raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`)
- vim-plug from junegunn/vim-plug repository
- antidote plugin manager (installed via Homebrew)
- Starship prompt (installed via Homebrew)

### System Modifications
- Changes default shell to brewed zsh via `chsh`
- Sets macOS hostname via `scutil` (requires sudo)
- Modifies system defaults (Finder, Dock, trackpad settings)
- Uses macOS keychain for git credentials

### Custom Functions to Preserve
- `svenv()` - Smart venv activation: walks tree upward, supports venv/.venv/poetry/pipenv, shows visual feedback
- `scpp()` - Uploads file to stkn.org and copies URL to clipboard
- `tunnel()` - SSH port forwarding wrapper
- `pwgen()` - Generates passwords using openssl

## Common Tasks

**Adding a new package**: Edit `Brewfile` → run `brew bundle` or `./update.sh`

**Adding an alias**: Edit `system/.aliases` → run `./sync.sh -f` → reload shell

**Modifying macOS setting**: Edit `macos.sh` → run `./macos.sh` → restart affected app

**Adding zsh plugin**: Edit `system/.zsh_plugins.txt` → reload shell (antidote auto-loads)

**Preview changes**: Run `./sync.sh -d` to see what would be synced without making changes
