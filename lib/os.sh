#!/usr/bin/env bash

# Platform detection and tool probing, sourced by `dot` and the setup steps.
# Sets and exports $OS as one of: macos | linux | unknown.
# Honors $DOTFILES_OS as an explicit override (e.g. `./dot install --linux`).

detect_os() {
  if [ -n "$DOTFILES_OS" ]; then
    OS="$DOTFILES_OS"
    return
  fi
  case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *)      OS="unknown" ;;
  esac
}

is_macos() { [ "$OS" = "macos" ]; }
is_linux() { [ "$OS" = "linux" ]; }

# WSL exposes "microsoft" in the kernel version string
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# Ubuntu, or a derivative — the match is over the whole of /etc/os-release, so
# ID_LIKE counts too. Backs the @ubuntu tag in packages/apt.txt, for a package
# that a derivative might not carry.
is_ubuntu() { grep -qi ubuntu /etc/os-release 2>/dev/null; }

# single idiom for "is this command available?"
has() { command -v "$1" >/dev/null 2>&1; }

# Put Homebrew on PATH for the current process (Apple Silicon, then Intel).
# The same guard lives in home/.zshrc for interactive shells.
brew_shellenv() {
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# The account this run belongs to. Deliberately not $USER: login(1) sets it, but
# `su`, `sudo -i`, cron and a docker container do not, and an empty name turns
# `chsh -s "$shell" "$USER"` into an error the passwd lookup cannot even explain.
# `id -un` asks the kernel and is always right.
current_user() { id -un; }

# The shell recorded for this user, which is what `chsh` changes. Deliberately
# not $SHELL: that keeps the pre-chsh value until the next login, so using it
# would make every re-run ask for a sudo password again.
login_shell_path() {
  local user
  user="$(current_user)"
  if has getent; then
    getent passwd "$user" 2>/dev/null | cut -d: -f7
  elif has dscl; then
    dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{print $2}'
  fi
}

# Map `uname -m` onto the release-asset naming most upstreams use
arch_name() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)             uname -m ;;
  esac
}

detect_os
export OS
