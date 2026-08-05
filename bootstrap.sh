#!/usr/bin/env bash

# Standalone bootstrap for a machine that has nothing yet: installs git, clones
# this repo over HTTPS, and stops there. `./dot install` stays a second, separate
# decision.
#
# Not to be confused with setup/bootstrap.sh, which is the macOS system phase
# *of* `./dot install`. This one runs before the repo exists, which is also why
# it may not source lib/*.sh: none of it is on the machine yet, so the output
# helpers below are deliberate duplicates.
#
#   curl -fsSL https://gitlab.stkn.org/felix/dotfiles/-/raw/main/bootstrap.sh | bash
#
# Piped into bash, stdin is the script itself — nothing here may read from it.

REPO="${DOTFILES_REPO:-https://gitlab.stkn.org/felix/dotfiles.git}"
DIR="${DOTFILES_DIR:-$HOME/code/dotfiles}"

if [ -t 1 ]; then
  C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
  C_BLUE=$'\033[34m' C_GREEN=$'\033[32m' C_RED=$'\033[31m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_BLUE="" C_GREEN="" C_RED=""
fi

section() { printf '\n%s==>%s %s%s%s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
info()    { printf '    %s\n' "$*"; }
ok()      { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip()    { printf '  %s·%s %s%s%s\n' "$C_DIM" "$C_RESET" "$C_DIM" "$*" "$C_RESET"; }
die()     { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*"; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

next_steps() {
  printf '\n'
  info "Next:"
  # \~ because bash tilde-expands a bare ~ in the replacement, i.e. right back
  # into the absolute path this is meant to shorten
  info "  cd ${DIR/#"$HOME"/\~} && ./dot install"
  info "  exec zsh"
}

# git, by whatever means the platform has. macOS gets it from the Xcode Command
# Line Tools; the test has to be `xcode-select -p` and not `has git`, because
# /usr/bin/git exists without them and only opens the installer dialog.
install_git() {
  case "$(uname -s)" in
    Darwin)
      if xcode-select -p >/dev/null 2>&1; then
        skip "Xcode Command Line Tools already installed"
        return 0
      fi
      info "Installing Xcode Command Line Tools..."
      # the status matters: told to "finish the installer" after a --install that
      # never opened one (already running, no network, MDM policy) the user would
      # be waiting on a window that is not coming
      if xcode-select --install; then
        die "Finish the Xcode installer, then run this command again"
      else
        die "could not start the Xcode installer — run xcode-select --install by hand, then run this command again"
      fi
      ;;
    Linux)
      if has git; then
        skip "git already installed"
        return 0
      fi
      has apt-get || die "no apt-get — this bootstrap only covers Debian/Ubuntu (incl. WSL2)"
      # empty on root, where sudo need not even exist — the expansion below is
      # unquoted for exactly that: it has to disappear, not become an empty arg
      local as_root=""
      if [ "$(id -u)" != 0 ]; then
        has sudo || die "git is missing and this is neither root nor a machine with sudo"
        as_root="sudo"
      fi
      info "Installing git..."
      $as_root apt-get update || die "apt-get update failed"
      # ca-certificates for the HTTPS clone below: curl got this script with the
      # system's own certs, but a minimal image can still be missing the bundle
      # git validates against
      $as_root apt-get install -y git ca-certificates || die "could not install git"
      ok "git installed"
      ;;
    *)
      die "unsupported platform: $(uname -s) — macOS and Debian/Ubuntu only"
      ;;
  esac
}

main() {
  section "Bootstrapping dotfiles"

  if [ -d "$DIR/.git" ]; then
    skip "$DIR is already a clone"
    next_steps
    return 0
  fi
  # anything else in the way is the user's, and losing it to a clone is not this
  # script's call to make
  if [ -e "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; then
    die "$DIR exists and is not empty — move it aside, or set DOTFILES_DIR"
  fi

  install_git || return 1

  info "Cloning $REPO..."
  git clone "$REPO" "$DIR" || die "clone failed — is $REPO reachable from here?"
  ok "cloned to $DIR"

  next_steps
}

main "$@"
