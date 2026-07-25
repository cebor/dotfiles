#!/usr/bin/env bash

# Make zsh the login shell. On macOS that means the Homebrew zsh, not the
# ancient system one; on Linux whatever apt installed.

setup_shell() {
  section "Setting default shell"

  # The Homebrew zsh is preferred on macOS, but it is only a preference: if
  # `brew bundle` did not get that far, /bin/zsh is still a perfectly good login
  # shell and leaving the user in bash over a missing keg helps nobody.
  local target=""
  is_macos && has brew && target="$(brew --prefix)/bin/zsh"
  [ -x "$target" ] || target="$(command -v zsh)"

  if [ -z "$target" ] || [ ! -x "$target" ]; then
    # Under --dry-run the packages phase would have installed zsh, so its absence
    # is an artefact of the forecast. Same guard as in setup/vim.sh.
    if [ -n "$DRY_RUN" ]; then
      info "zsh not installed yet — ./dot packages installs it before this step"
      ok "would set zsh as the login shell once it is there"
      return 0
    fi
    warn "zsh not found — skipping shell change"
    return 0
  fi

  # compare against the passwd entry, not $SHELL — $SHELL still holds the old
  # value for the rest of the session, which would re-run chsh (and re-prompt
  # for sudo) on every invocation after the first.
  if [ "$(login_shell_path)" = "$target" ]; then
    skip "already using $target"
    return 0
  fi

  if ! grep -qxF "$target" /etc/shells; then
    info "Registering $target in /etc/shells..."
    if ! run bash -c "printf '%s\n' '$target' | sudo tee -a /etc/shells >/dev/null"; then
      err "could not add $target to /etc/shells — chsh would refuse it"
      return 1
    fi
  fi

  if run sudo chsh -s "$target" "$USER"; then
    ok_run "default shell set to $target (takes effect on next login)" \
           "would set the default shell to $target"
  else
    err "chsh failed — the login shell is unchanged"
    return 1
  fi
}
