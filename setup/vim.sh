#!/usr/bin/env bash

# vim working directories (backups/swaps/undo are configured in home/.vimrc)
# plus vim-plug and the plugins it manages.

setup_vim() {
  section "Setting up vim"

  if ! has vim; then
    # Under --dry-run the packages phase only said it *would* install vim, so its
    # absence here is an artefact of the forecast. Same guard as in
    # setup/packages.sh and setup/shell.sh.
    if [ -n "$DRY_RUN" ]; then
      info "vim not installed yet — ./dot packages installs it before this step"
      ok "would set up the vim directories and plugins once vim is there"
      return 0
    fi
    warn "vim not installed — skipping"
    return 0
  fi

  run mkdir -p "$HOME/.vim/backups" "$HOME/.vim/swaps" "$HOME/.vim/undo" ||
    warn "could not create the vim working directories"

  # -s, not -f: `curl -o` truncates its destination before it knows the request
  # failed (--remove-on-error is curl 7.83, Ubuntu 22.04 ships 7.81), so a 0-byte
  # plug.vim has to count as missing. Same shape as the yq install in
  # setup/packages-linux.sh; the download stays inside `run bash -c '…'` so
  # --dry-run does not hit the network.
  if [ -s "$HOME/.vim/autoload/plug.vim" ]; then
    skip "vim-plug already installed"
  else
    info "Installing vim-plug..."
    if ! run bash -c 'tmp=$(mktemp) &&
        curl -fsSL -o "$tmp" https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim &&
        [ -s "$tmp" ] &&
        mkdir -p "$HOME/.vim/autoload" &&
        install -m 644 "$tmp" "$HOME/.vim/autoload/plug.vim"
      rc=$?; rm -f "$tmp"; exit $rc'; then
      err "vim-plug download failed — skipping plugin install"
      return 1
    fi
  fi

  # plug#begin lives in ~/.vimrc, which `./dot sync` links — without it the -u
  # below has nothing to read. Under --dry-run sync has not run either, so its
  # absence there is a forecast artefact.
  if [ ! -f "$HOME/.vimrc" ] && [ -z "$DRY_RUN" ]; then
    # shellcheck disable=SC2088  # message text: ~ is how the user writes the path
    warn "~/.vimrc is not linked — run ./dot sync first; skipping the plugin install"
    return 0
  fi

  # PlugUpdate installs the missing plugins too, so a preceding PlugInstall would
  # only clone them a second time.
  # -es:        no UI, so this cannot block when stdout is a pipe.
  # -u:         ex mode does not read ~/.vimrc, so without it plug#begin never
  #             runs and :PlugUpdate does not exist.
  # --sync:     the plain command updates in the background, +qall would quit
  #             out from under it.
  # </dev/null: ex mode reads commands from stdin — a prompt outliving +qall
  #             would eat the rest of the run's input.
  if run vim -es -u "$HOME/.vimrc" +'PlugUpdate --sync' +qall </dev/null; then
    ok_run "vim plugins up to date" "would install and update the vim plugins"
  else
    warn "vim exited with an error — plugins may be incomplete"
  fi
}
