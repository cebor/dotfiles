#!/usr/bin/env bash

# Linux package installation (Debian/Ubuntu) — the counterpart to `brew bundle`.
# First the apt list from packages/apt.txt, then the tools apt does not carry
# in a usable version. Every step is guarded, so re-running is cheap.

setup_packages_linux() {
  local failed=0
  # apt names that this machine does not carry. Counted separately from $failed:
  # not a failure (apt.txt lists names that do not exist everywhere on purpose),
  # but the closing ok must not claim everything is installed either.
  local unavailable=0

  # kubectl comes from a per-minor-version apt repo, so this has to be pinned to
  # something. Bumping it rewrites the repo on the next `./dot packages`, on
  # machines that already have kubectl too — apt would otherwise never move past
  # the pinned minor. Check which minors exist with:
  #   curl -ILo /dev/null -w '%{http_code}\n' \
  #     https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release
  local kubernetes_minor="v1.36"

  info "apt packages from packages/apt.txt"
  run sudo apt-get update || warn "apt-get update failed — package versions may be stale"
  # strip comment lines and trailing inline comments, then hand the rest to apt
  local pkgs
  pkgs="$(grep -vE '^\s*#|^\s*$' "$DOTFILES_ROOT/packages/apt.txt" | sed 's/#.*//' | tr '\n' ' ')"
  # apt is all-or-nothing: one name it cannot resolve (wrk, for instance, is not
  # packaged on Debian) aborts the whole batch and installs nothing. So fall back
  # to one call per package, which costs a few seconds but only loses the
  # packages that really are unavailable.
  # shellcheck disable=SC2086 # deliberate word splitting: one arg per package
  if ! run sudo apt-get install -y $pkgs; then
    warn "apt-get install failed for the batch — retrying package by package"
    local pkg total=0
    for pkg in $pkgs; do
      total=$((total + 1))
      # a warning, not an error: apt.txt deliberately lists names that do not
      # exist everywhere, so an error here would make every single run on such a
      # machine exit non-zero for a situation the list itself expects.
      run sudo apt-get install -y "$pkg" ||
        { warn "apt: $pkg unavailable"; unavailable=$((unavailable + 1)); }
    done
    # A name this machine does not carry (wrk on Debian) is expected; *none* of
    # them getting through is not — that is apt or sudo being unreachable, and
    # the closing ok would otherwise put a ✓ on a run that installed nothing.
    # Guarded on > 0 so an empty apt.txt cannot trigger it, and `run` returns 0
    # under --dry-run, so a forecast never lands here either.
    if [ "$unavailable" -gt 0 ] && [ "$unavailable" -eq "$total" ]; then
      err "apt installed nothing — apt or sudo is unreachable, not a packaging gap"
      failed=$((failed + 1))
    fi
  fi

  # WSL only: wslu provides wslview (used by the `open` shim), wslpath, etc.
  if is_wsl && ! has wslview; then
    info "Installing wslu (WSL detected)..."
    run sudo apt-get install -y wslu || warn "wslu install failed — the \`open\` shim will not work"
  fi

  # The mirror image of wslu: outside WSL the pbcopy/pbpaste shims in
  # home/.functions need wl-copy or xclip. Under WSL they go through
  # win32yank.exe/clip.exe instead, so installing the X11/Wayland tooling there
  # would only drag in dependencies nothing ever calls. A warning, not an error:
  # headless images do not always carry them.
  if ! is_wsl; then
    if has xclip && has wl-copy; then
      skip "clipboard tools (xclip, wl-clipboard)"
    else
      info "Installing clipboard tools (xclip, wl-clipboard)..."
      run sudo apt-get install -y xclip wl-clipboard ||
        warn "clipboard tools unavailable — pbcopy/pbpaste will not work"
    fi
  fi

  # Everything below downloads its own installer. Without curl there is no point
  # in trying, and the errors would be a confusing cascade.
  if ! has curl && [ -z "$DRY_RUN" ]; then
    err "curl is missing — skipping the upstream installers (node, starship, kubectl, helm, yq)"
    return 1
  fi
  # Every `curl … | interpreter` below starts with `set -o pipefail`, and it is
  # what makes the surrounding `if` mean anything: a pipeline reports the status
  # of its *last* command, so a failed download hands an empty script to sh/bash,
  # which exits 0 — the guard would call that a success and the step would be
  # silently skipped. Same reason every curl carries -f: without it an HTTP error
  # page is a 200-ish body that gets executed.

  # Node.js current — Debian's `nodejs` is stale
  if has node; then
    skip "node $(node --version)"
  else
    info "Installing Node.js (current)..."
    if run bash -c 'set -o pipefail; curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -'; then
      run sudo apt-get install -y nodejs || { err "nodejs install failed"; failed=$((failed + 1)); }
    else
      err "could not add the NodeSource repo"
      failed=$((failed + 1))
    fi
  fi

  # antidote — zsh plugin manager, not in apt
  if [ -d "$HOME/.antidote" ]; then
    skip "antidote"
  else
    info "Installing antidote..."
    if ! run git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"; then
      err "antidote clone failed — zsh plugins will not load"
      failed=$((failed + 1))
    fi
  fi

  # starship prompt (official installer, writes to /usr/local/bin)
  if has starship; then
    skip "starship"
  else
    info "Installing starship..."
    if ! run bash -c 'set -o pipefail; curl -fsSL https://starship.rs/install.sh | sh -s -- -y'; then
      err "starship install failed"
      failed=$((failed + 1))
    fi
  fi

  # helix editor
  if has hx; then
    skip "helix"
  elif is_ubuntu; then
    info "Installing helix (PPA)..."
    if run sudo add-apt-repository -y ppa:maveonair/helix-editor; then
      run sudo apt-get update || warn "apt-get update failed after adding the helix PPA"
      run sudo apt-get install -y helix || { err "helix install failed"; failed=$((failed + 1)); }
    else
      err "could not add the helix PPA"
      failed=$((failed + 1))
    fi
  else
    # a skip, not a warning: there is nothing this step could do about it on plain
    # Debian, and warning here would leave every single run on such a machine with
    # a warning count it can never clear. `./dot doctor` is where the gap belongs.
    skip "helix (no Debian apt package — install it from the GitHub releases)"
  fi

  # kubectl (pkgs.k8s.io apt repo). The guard is the repo pin, not `has kubectl`:
  # the repo only ever carries one minor, so on a machine that already installed
  # kubectl from an older pin apt would sit on that minor forever and a bump of
  # $kubernetes_minor above would silently do nothing.
  local k8s_list="/etc/apt/sources.list.d/kubernetes.list"
  if has kubectl && grep -qF "/stable:/$kubernetes_minor/" "$k8s_list" 2>/dev/null; then
    skip "kubectl ($kubernetes_minor)"
  else
    if has kubectl; then
      info "Repinning the kubernetes repo to $kubernetes_minor..."
    else
      info "Installing kubectl ($kubernetes_minor)..."
    fi
    # The sources.list must not be written unless the keyring really holds a key:
    # a signed-by repo whose key signs nothing makes every apt-get update on the
    # machine fail with NO_PUBKEY, not just this script, until someone deletes
    # the file by hand. Temp file plus an explicit -s check, so nothing lands in
    # /etc until it is known good — same shape as the yq block below.
    if run sudo mkdir -p /etc/apt/keyrings &&
       run bash -c "set -o pipefail
         tmp=\$(mktemp) &&
         curl -fsSL 'https://pkgs.k8s.io/core:/stable:/$kubernetes_minor/deb/Release.key' \
           | gpg --dearmor > \"\$tmp\" &&
         [ -s \"\$tmp\" ] &&
         sudo install -m 644 \"\$tmp\" /etc/apt/keyrings/kubernetes-apt-keyring.gpg
         rc=\$?; rm -f \"\$tmp\"; exit \$rc" &&
       run bash -c "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$kubernetes_minor/deb/ /' \
         | sudo tee $k8s_list >/dev/null"; then
      run sudo apt-get update || warn "apt-get update failed after adding the kubernetes repo"
      run sudo apt-get install -y kubectl || { err "kubectl install failed"; failed=$((failed + 1)); }
    else
      err "could not add the kubernetes apt repo"
      failed=$((failed + 1))
    fi
  fi

  # helm (official installer script)
  if has helm; then
    skip "helm"
  else
    info "Installing helm..."
    if ! run bash -c 'set -o pipefail; curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'; then
      err "helm install failed"
      failed=$((failed + 1))
    fi
  fi

  # yq (mikefarah) — apt's `yq` is a different tool entirely
  if has yq; then
    skip "yq"
  else
    info "Installing yq ($(arch_name))..."
    # via a temp file, not straight to the target: `curl -o` truncates the
    # destination before it knows the request failed and leaves the 0-byte file
    # behind (--remove-on-error only exists from curl 7.83, Ubuntu 22.04 has
    # 7.81). `install` also folds in the chmod.
    local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(arch_name)"
    if run bash -c "tmp=\$(mktemp) &&
        curl -fsSL -o \"\$tmp\" '$yq_url' &&
        sudo install -m 755 \"\$tmp\" /usr/local/bin/yq
      rc=\$?; rm -f \"\$tmp\"; exit \$rc"; then
      ok_run "yq installed" "would install yq"
    else
      err "yq install failed"
      failed=$((failed + 1))
    fi
  fi

  # bat ships as `batcat` on Debian/Ubuntu (name clash with bacula's `bat`);
  # expose it under its real name via ~/.local/bin, which is already on PATH
  if has batcat && ! has bat; then
    if run mkdir -p "$HOME/.local/bin" && run ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; then
      ok_run "linked batcat -> ~/.local/bin/bat" "would link batcat -> ~/.local/bin/bat"
    else
      warn "could not link batcat to ~/.local/bin/bat"
    fi
  fi

  if [ "$failed" -gt 0 ]; then
    warn "$failed package step(s) failed — see the errors above"
    return 1
  fi
  # a bare "up to date" would be a ✓ over packages that are not installed
  local note=""
  [ "$unavailable" -gt 0 ] && note=" ($unavailable unavailable — see the warnings above)"
  ok_run "Linux packages up to date$note" "would install the Linux packages"
}
