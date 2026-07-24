# Dotfiles

Personal cross-platform (macOS + Linux) configuration and dotfiles management system.

The platform is auto-detected via `uname`. On macOS packages come from Homebrew
(`Brewfile`); on Linux (Debian/Ubuntu, tested on WSL2) from apt (`packages/apt.txt`)
plus a few upstream installers in `linux.sh`.

## Quick Start

### First-Time Setup

```bash
git clone <repository-url> ~/.dotfiles
cd ~/.dotfiles
./install.sh          # Auto-detects the OS, runs bootstrap if needed, installs everything
# ./install.sh --linux  # Force the Linux path (overrides auto-detection)
exec zsh              # Reload shell
```

### Regular Updates

```bash
./install.sh      # Safe to re-run - updates packages and syncs dotfiles
# Or for quick dotfile-only syncs:
./sync.sh -f      # Sync dotfiles without package updates
```

## What's Included

### Shell Configuration
- **Zsh** with [antidote](https://getantidote.github.io/) plugin manager
- **Starship** prompt
- Oh My Zsh plugins (git, brew, extract)
- Enhanced utilities (zsh-autosuggestions, zsh-syntax-highlighting, z)

### Applications
- Development: helix, vim, git, python, node, docker
- Networking: httpie, nmap, mtr, wrk
- Kubernetes: kubectl, helm, yq
- GUI apps (macOS only): iTerm2, VS Code, Firefox, Obsidian, and more

See [`Brewfile`](Brewfile) (macOS) and [`packages/apt.txt`](packages/apt.txt) (Linux)
for the complete lists. Tools not in apt (antidote, starship, helix, node, kubectl,
helm, yq) are installed by [`linux.sh`](linux.sh).

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
| `macos-bootstrap.sh` | One-time macOS system setup (Xcode CLI tools, Homebrew) | macOS first installation only (or run automatically by install.sh) |
| `install.sh` | Full installation - auto-detects OS, runs bootstrap if needed, installs/updates packages, sets zsh as default shell (`--linux` forces the Linux path) | First-time setup AND regular updates (safe to re-run) |
| `linux.sh` | Linux (apt) package install + upstream installers for tools not in apt | Called by install.sh on Linux |
| `macos.sh` | macOS system defaults (Finder, Dock, trackpad) | Called by install.sh on macOS |
| `sync.sh` | Sync dotfiles only (supports `-f`, `-d` flags) | Quick dotfile-only syncs or testing changes |
| `git.sh` | Apply git config settings, prompts for user.name/email if not set | Called by install.sh |

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
├── lib/          # Shared helpers (os.sh - OS detection)
├── packages/     # apt.txt - Linux package list
├── *.sh          # Setup and maintenance scripts
├── Brewfile      # Homebrew package definitions (macOS)
└── CLAUDE.md     # AI agent instructions
```

Files in `git/` and `system/` are synced to `$HOME` via rsync.

## Customization

1. **Add a package**: Edit `Brewfile` (macOS) or `packages/apt.txt` (Linux) → run `./install.sh`
2. **Add an alias**: Edit `system/.aliases` → run `./sync.sh -f` → reload shell
3. **Add a zsh plugin**: Edit `system/.zsh_plugins.txt` → run `./sync.sh -f` → reload shell
4. **Modify macOS settings**: Edit `macos.sh` → run `./macos.sh` → restart affected app

## Configuration Highlights

### Git
- Default editor: **helix** (`hx`)
- Default branch: `main`
- Credentials: macOS keychain on macOS; libsecret or a 1h credential cache on Linux

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
./install.sh  # Syncs dotfiles, updates packages, reconfigures git/vim/macOS
```

## Requirements

- macOS (recent versions), or Linux (Debian/Ubuntu, tested on WSL2)
- macOS: Xcode Command Line Tools (installed by `macos-bootstrap.sh`)
- Linux: `sudo` access for apt
- Internet connection for initial setup

## License

MIT - See [LICENSE](LICENSE) file for details.
