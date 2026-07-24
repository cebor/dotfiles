#!/usr/bin/env bash

# Shared OS detection, sourced by the install scripts.
# Sets and exports $OS as one of: macos | linux | unknown.
# Honors $DOTFILES_OS as an explicit override (e.g. `./install.sh --linux`).

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

detect_os
export OS
