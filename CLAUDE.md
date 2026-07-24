# CLAUDE.md

Guidance for working in this repository.

## Architecture Overview

Cross-platform (macOS + Linux) dotfiles system with a **two-phase structure**:
- **Configuration files** in `git/` and `system/` — copied (not symlinked) to `$HOME` via rsync
- **Setup scripts** at the repo root — orchestrate installation and system configuration

The platform is **auto-detected** at install time (`uname` via `lib/os.sh`), so the same
`./install.sh` works on both OSes. `./install.sh --linux` forces the Linux path.

### Key Components

- `lib/os.sh` - Shared OS detection. Sourced by scripts; exports `$OS` (`macos`|`linux`|`unknown`). Honors `$DOTFILES_OS` as an override (that's how `--linux` works).
- `install.sh` - Full installation. Auto-detects OS, branches every OS-specific step on `$OS`, safe to re-run.
- `macos-bootstrap.sh` - **macOS only**, gated by `install.sh`: Xcode CLI tools + Homebrew.
- `macos.sh` - **macOS only**, gated by `install.sh`: `defaults write` / `scutil` system settings.
- `linux.sh` - **Linux only**: installs `packages/apt.txt` via apt, then upstream installers for tools not in apt.
- `sync.sh` - Copies `git/` + `system/` to `$HOME` via rsync (excludes `.DS_Store`). OS-agnostic.
- `git.sh` - `git config --global` settings; OS-conditional credential helper; prompts for user.name/email if unset.
- `vim.sh` - Creates vim dirs, installs/updates vim-plug. OS-agnostic.

### Package sources
- **macOS**: `Brewfile` (`brew` CLI tools, `cask` GUI apps, `mas` App Store — casks/mas are macOS-only).
- **Linux**: `packages/apt.txt` (apt list). Tools not in apt are installed by `linux.sh`: antidote (git clone `~/.antidote`), starship (official installer), helix (Ubuntu PPA), node (NodeSource current), kubectl (pkgs.k8s.io), helm, yq. `wslu` installed only under WSL.

## Critical Workflows

- **First-time setup / regular updates**: `./install.sh` (safe to re-run), then `exec zsh`.
- **Quick dotfile sync**: `./sync.sh -f`. **Preview**: `./sync.sh -d`.
- **Packages**: macOS `brew bundle`; Linux `./linux.sh`.

### Shell Configuration Structure
`system/.zshrc` sources three modular files, then sets up antidote + starship:
1. `.exports` - Environment variables (GPG_TTY, LANG)
2. `.aliases` - Command shortcuts (OS-guarded ones use `[[ "$OSTYPE" == darwin* ]]`)
3. `.functions` - Shell functions, including cross-platform `pbcopy`/`pbpaste`/`open` shims (defined only when the macOS native is missing)

`.zshrc` locates antidote from the Homebrew keg on macOS and from `~/.antidote` on Linux;
`brew shellenv` and `starship` are guarded so the file loads cleanly on both OSes.

## Project Conventions

### Shell Scripts
- `#!/usr/bin/env bash` shebang; scripts self-locate with `cd "$(dirname "$0")"`.
- **No `set -euo pipefail`** by design — steps may soft-fail with a warning rather than abort.
- OS-specific scripts source `lib/os.sh` and branch on `$OS`; sub-scripts inherit the `--linux` override via the exported `$DOTFILES_OS`.
- Linux installers in `linux.sh` are guarded (`command -v` / dir checks) so the script is idempotent.
- User prompts for destructive ops (except with `-f`/`--force`). `case` for arg parsing.

### Keep sourced shell files fast
`.aliases` / `.functions` are sourced on every interactive shell start — they must **not**
source `lib/os.sh` or spawn heavy subshells. Use `[[ "$OSTYPE" == ... ]]` globs and `command -v`.

### Dotfile Organization
- `git/` - `.gitignore_global`, `.gitattributes_global` — **no static .gitconfig** (applied imperatively by `git.sh`).
- `system/` - shell + app dotfiles (`.zshrc`, `.vimrc`, `.tmux.conf`, `.ssh/`, `.config/`).
- Git config applied via `git.sh` (`git config --global`), user.name/email prompted if unset.

### Editor / Style
- Primary editor: **helix** (`hx`). Vim configured with vim-plug, Solarized, persistent undo.
- EditorConfig: 2-space indent, LF line endings.

## Custom Functions to Preserve
- `svenv()` - walks upward to find and activate `venv`/`.venv`, with `✓/✗` feedback.
- `scpp()` - `scp` to stkn.org, sets perms, copies URL to clipboard via `pbcopy` (shim on Linux).
- `tunnel()` - SSH port forwarding.
- `pwgen()` - `openssl rand -base64` with configurable length.
- `server()` - `python3 -m http.server` with auto-open browser via `open` (shim on Linux).
- `f()` - `find . -name "$1"`.

## Common Tasks

- **Add a package**: edit `Brewfile` (macOS) or `packages/apt.txt` (Linux) → `./install.sh`.
- **Add an alias**: edit `system/.aliases` → `./sync.sh -f` → reload shell.
- **Add a zsh plugin**: edit `system/.zsh_plugins.txt` → `./sync.sh -f` → reload shell.
- **Modify a macOS setting**: edit `macos.sh` → `./macos.sh` → restart affected app.
- **Reload shell**: `exec zsh`.

## Platform Gotchas
- On Debian/Ubuntu, `bat` ships as `batcat` — `linux.sh` symlinks it to `bat` in `~/.local/bin`.
- `system/.ssh/config` uses `IgnoreUnknown UseKeychain` so the macOS-only `UseKeychain`
  option doesn't error on Linux OpenSSH.
- Git credentials: macOS keychain on macOS; libsecret or a 1h credential cache on Linux.
