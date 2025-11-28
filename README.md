# Dotfiles

Personal macOS configuration and dotfiles management system.

## Quick Start

### First-Time Setup

```bash
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh      # Automatically runs bootstrap if needed, then installs everything
exec zsh          # Reload shell
```

### Regular Updates

```bash
./update.sh       # Sync dotfiles and update packages
```

## What's Included

### Shell Configuration
- **Zsh** with [antidote](https://getantidote.github.io/) plugin manager
- **Starship** prompt
- Oh My Zsh plugins (git, brew, extract)
- Enhanced utilities (zsh-autosuggestions, zsh-syntax-highlighting, z)

### Applications (via Homebrew)
- Development: helix, vim, git, python, node, docker
- Networking: httpie, nmap, mtr, wrk
- Kubernetes: kubectl, helm, yq
- GUI apps: iTerm2, VS Code, Firefox, Obsidian, and more

See [`Brewfile`](Brewfile) for the complete list.

### Custom Functions & Aliases

**Smart Python venv activation:**
```bash
svenv  # Finds and activates venv/.venv/poetry/pipenv in parent directories
```

**File sharing:**
```bash
scpp file.txt  # Upload to stkn.org and copy URL to clipboard
```

**Utilities:**
```bash
server 8080       # Start HTTP server on port 8080
tunnel host 3306 3307  # SSH port forwarding
pwgen 20          # Generate 20-character password
```

See [`.aliases`](system/.aliases) and [`.functions`](system/.functions) for all shortcuts.

## Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `bootstrap.sh` | One-time system setup (Homebrew, shell, git config) | First installation only (or run automatically by install.sh) |
| `install.sh` | Full installation - auto-runs bootstrap if needed | First-time setup (one command does it all) |
| `update.sh` | Sync dotfiles, update packages, reconfigure git/vim | Regular maintenance |
| `sync.sh` | Sync dotfiles only (supports `-f`, `-d` flags) | Testing dotfile changes |
| `git.sh` | Apply git config settings (preserves user.name/email) | Called by install.sh and update.sh |

### Script Flags

```bash
./sync.sh -d      # Dry-run: preview changes without syncing
./sync.sh -f      # Force: skip confirmation prompt
```

## Project Structure

```
dotfiles/
├── git/          # Git-specific config (.gitignore_global, .gitattributes_global)
├── system/       # Shell and app dotfiles (.zshrc, .vimrc, .tmux.conf, etc.)
├── *.sh          # Setup and maintenance scripts
├── Brewfile      # Homebrew package definitions
└── .github/      # AI agent instructions
```

Files in `git/` and `system/` are synced to `$HOME` via rsync.

## Customization

1. **Add a package**: Edit `Brewfile` → run `brew bundle` or `./update.sh`
2. **Add an alias**: Edit `system/.aliases` → run `./sync.sh -f` → reload shell
3. **Add a zsh plugin**: Edit `system/.zsh_plugins.txt` → reload shell
4. **Modify macOS settings**: Edit `macos.sh` → run `./macos.sh` → restart affected app

## Configuration Highlights

### Git
- Default editor: **helix** (`hx`)
- Default branch: `main`
- Credentials stored in macOS keychain

### Vim
- Plugin manager: vim-plug
- Theme: Solarized Dark
- Persistent undo, automatic position restore

### macOS
- Finder: show path bar, status bar, all extensions
- Dock: minimize to application, auto-hide
- Trackpad: tap to click enabled

See [`macos.sh`](macos.sh) for all system preferences.

## Maintenance

### Preview Changes
```bash
./sync.sh -d  # See what would change without applying
```

### Update Everything
```bash
./update.sh  # Syncs dotfiles, updates packages, reconfigures git/vim
```

## Requirements

- macOS (tested on recent versions)
- Xcode Command Line Tools (installed by `bootstrap.sh`)
- Internet connection for initial setup

## License

MIT - See [LICENSE](LICENSE) file for details.
