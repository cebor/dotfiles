#!/usr/bin/env bash

# One-time macOS system prerequisites: Xcode Command Line Tools + Homebrew.
# Sourced by `dot`; defines setup_bootstrap and runs nothing on its own.

setup_bootstrap() {
  is_macos || { skip "bootstrap is macOS-only"; return 0; }

  section "Bootstrapping macOS"

  if xcode-select -p &>/dev/null; then
    skip "Xcode Command Line Tools already installed"
  elif [ -n "$DRY_RUN" ]; then
    # nothing was started, so there is nothing to wait for — failing here would
    # abort the whole dry run (cmd_install turns it into `die`) and never show
    # what sync/packages/configure would do
    run xcode-select --install
    info "would wait for the Xcode installer, then continue"
  else
    info "Installing Xcode Command Line Tools..."
    # the status matters: told to "finish the installer" after a `--install` that
    # never opened one (already running, no network, MDM policy) the user would be
    # waiting on a window that is not coming
    if run xcode-select --install; then
      err "Finish the Xcode installer, then re-run ./dot install"
    else
      err "could not start the Xcode installer — run xcode-select --install by hand, then re-run ./dot install"
    fi
    return 1
  fi

  if has brew; then
    skip "Homebrew already installed"
  else
    info "Installing Homebrew..."
    # NONINTERACTIVE under --yes because the installer waits for RETURN.
    local nonint=""
    [ -n "$ASSUME_YES" ] && nonint="NONINTERACTIVE=1 "
    # Via a temp file, not `/bin/bash -c "$(curl …)"`: a failed fetch makes the
    # command substitution empty and `bash -c ""` exits 0. pipefail cannot catch
    # that — this is a substitution, not a pipeline — so fetch and run are
    # separated and an empty body is caught by -s. Same shape as the yq/kubectl
    # installs in packages-linux.sh. The download stays inside `run bash -c '…'`:
    # as an argument it would be fetched even under --dry-run.
    if run bash -c "tmp=\$(mktemp) &&
        curl -fsSL -o \"\$tmp\" https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh &&
        [ -s \"\$tmp\" ] &&
        ${nonint}/bin/bash \"\$tmp\"
      rc=\$?; rm -f \"\$tmp\"; exit \$rc"; then
      ok_run "Homebrew installed" "would install Homebrew"
    else
      err "Homebrew installation failed"
      return 1
    fi
  fi

  brew_shellenv
  # brew_shellenv is a no-op when brew sits under neither probed prefix, and an
  # `if` without a matching branch returns 0 — as the last statement it would put
  # this step's ✓ on an installation nothing can find. Not under --dry-run, where
  # nothing was installed (same guard as in setup/packages.sh).
  if ! has brew && [ -z "$DRY_RUN" ]; then
    err "Homebrew installed but not on PATH — see the installer's \"Next steps\" output"
    return 1
  fi
  return 0
}
