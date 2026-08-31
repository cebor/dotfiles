#!/usr/bin/env bash

# Linux package installation (Debian/Ubuntu) — the counterpart to `brew bundle`.
#
# Sources first, packages second: every third-party apt source is added up front
# (WakeMeOps, the git and helix PPAs, NodeSource), then a single apt-get install
# pulls the whole of packages/apt.txt. Only what apt cannot carry at all is
# installed after that — antidote (git clone) and starship (upstream installer).
#
# The tools all of that needs (curl, gnupg, git, add-apt-repository) come from
# setup/prereqs.sh, which `./dot install` runs first; this step only checks that
# they are there.
#
# Every step is guarded, so re-running is cheap.

# Read packages/apt.txt into the global $APT_PACKAGES — the apt names that apply
# to this machine — dropping the lines whose tag does not match it. Line format:
# `name [@tag] [# comment]`. The array is declared inside the function, not at
# file scope: like every setup/*.sh this one must do nothing at source time.
#
# Fills a global instead of echoing its result, on purpose: with
# `pkgs="$(_apt_read_list)"` the warn below would land in $pkgs as if it were a
# package name, and its $LOG_WARNINGS increment would die with the subshell.
# `while … done < file` runs in the current shell, so array and counter both live.
_apt_read_list() {
  local line name tag
  APT_PACKAGES=()
  while IFS= read -r line; do
    line="${line%%#*}"            # drop the comment, if any
    # unquoted read: collapses the padding, and leaves $name empty on a blank line
    read -r name tag _ <<<"$line"
    [ -n "$name" ] || continue
    case "$tag" in
      "")      ;;
      @wsl)    is_wsl    || continue ;;
      '@!wsl') is_wsl    && continue ;;
      @ubuntu) is_ubuntu || continue ;;
      # not a silent skip: a typo'd tag is indistinguishable from a real one, and
      # installing the package everywhere would be the wrong guess as often as not
      *) warn "apt.txt: unknown tag $tag on $name — skipped"; continue ;;
    esac
    APT_PACKAGES+=("$name")
  done < "$DOTFILES_ROOT/packages/apt.txt"
}

# WakeMeOps — a signed Debian repo (https://docs.wakemeops.com) carrying kubectl,
# helm, yq and bat, which apt would otherwise not provide in a usable version.
# Only the two components we want; the installer's default is all five
# (dev devops secops terminal desktop).
#
# The guard is the components line, not `has kubectl` — the same reason the
# kubernetes repo this replaces was guarded by its sources file: a change to
# $components has to reach machines that already have the repo, and `has` would
# leave them on the old set forever.
_apt_repo_wakemeops() {
  local components="devops terminal"
  local sources="/etc/apt/sources.list.d/wakemeops.sources"
  if grep -qxF "Components: $components" "$sources" 2>/dev/null; then
    skip "wakemeops repo ($components)"
    return 0
  fi

  info "Adding the WakeMeOps repo ($components)..."
  # the installer writes its keyring straight into /etc/apt/keyrings without
  # creating the directory — it ships with Debian 12 / Ubuntu 22.04 and later,
  # but not with anything older
  if run sudo mkdir -p /etc/apt/keyrings &&
     run bash -c "set -o pipefail
       curl -fsSL https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository \
         | sudo bash -s '$components'"; then
    return 0
  fi
  err "could not add the WakeMeOps repo — kubectl, helm, yq and bat will be missing"
  return 1
}

# git — Debian and Ubuntu both ship a git that is a year or more behind. This PPA
# is upstream's own stable build for Ubuntu; there is no Debian equivalent, so
# plain Debian keeps the distro git.
#
# The guard greps the directory rather than naming a file, for the same reason as
# the NodeSource one: add-apt-repository writes `.list` on older Ubuntu and
# deb822 `.sources` from 24.04 on, and a filename guard would silently stop
# matching — re-running add-apt-repository on every ./dot packages.
_apt_repo_git() {
  if ! is_ubuntu; then
    # a skip, not a warning, for the same reason as helix below: nothing this step
    # could do about it on Debian, and its git works — it is only older
    skip "git ppa (Ubuntu only — Debian keeps the distro git)"
    return 0
  fi
  if grep -rqs git-core /etc/apt/sources.list.d/; then
    skip "git ppa"
    return 0
  fi

  info "Adding the git PPA..."
  run sudo add-apt-repository -y ppa:git-core/ppa && return 0
  # a warning rather than an error, and a 0 return: `git` is in apt.txt, so the run
  # does end with a git — just the distro's older one. helix errs instead because
  # there it is the PPA or nothing.
  warn "could not add the git PPA — git will come from the distro (older)"
  return 0
}

# helix — there is no Debian package and no Ubuntu package either, only this PPA.
_apt_repo_helix() {
  if ! is_ubuntu; then
    # a skip, not a warning: there is nothing this step could do about it on plain
    # Debian, and warning here would leave every single run on such a machine with
    # a warning count it can never clear. `./dot doctor` is where the gap belongs.
    skip "helix (no Debian apt package — install it from the GitHub releases)"
    return 0
  fi
  if grep -rqs maveonair /etc/apt/sources.list.d/; then
    skip "helix ppa"
    return 0
  fi

  info "Adding the helix PPA..."
  run sudo add-apt-repository -y ppa:maveonair/helix-editor && return 0
  err "could not add the helix PPA"
  return 1
}

# Node.js current — Debian's `nodejs` is years behind. The guard is the sources
# file rather than `has node`, so a node that came from nvm or a manual install
# cannot stop the repo from being added — `nodejs` is in apt.txt either way, and
# without the repo it would quietly come from the distro instead.
#
# It greps the directory for the repo host rather than naming a file: the
# installer used to write `nodesource.list` and now writes `nodesource.sources`
# (deb822), so a filename guard silently stops matching the day upstream
# switches format — and then re-runs the whole installer on every ./dot packages.
_apt_repo_node() {
  if grep -rqs deb.nodesource.com /etc/apt/sources.list.d/; then
    skip "nodesource repo"
    return 0
  fi

  info "Adding the NodeSource repo..."
  run bash -c 'set -o pipefail; curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -' &&
    return 0
  # a warning rather than an error, and a 0 return: apt.txt still installs
  # `nodejs`, so the run does end with a node — just not the current one
  warn "could not add the NodeSource repo — nodejs will come from the distro (stale)"
  return 0
}

setup_packages_linux() {
  local failed=0
  # apt names that this machine does not carry. Counted separately from $failed:
  # not a failure (apt.txt lists names that do not exist everywhere on purpose),
  # but the closing ok must not claim everything is installed either.
  local unavailable=0

  # --- 1. prerequisites -------------------------------------------------------
  # setup/prereqs.sh installs these; `./dot packages` on its own never ran it, so
  # the tools the sources below need may simply not be there. The same situation
  # as a macOS run without Homebrew, and reported the same way (see
  # setup/packages.sh) — everything from here on downloads over the network, and
  # without those the errors would be a confusing cascade.
  local missing=""
  has curl || missing="$missing curl"
  has gpg  || missing="$missing gpg"
  is_ubuntu && { has add-apt-repository || missing="$missing software-properties-common"; }
  if [ -n "$missing" ]; then
    # Under --dry-run their absence is an artefact of the forecast: setup_prereqs
    # only said it *would* install them. Same guard as in setup/packages.sh.
    if [ -z "$DRY_RUN" ]; then
      err "prerequisites missing:$missing — run ./dot install"
      return 1
    fi
    info "prerequisites not installed yet — ./dot install installs them before this step"
  fi

  # Every `curl … | interpreter` below starts with `set -o pipefail`, and it is
  # what makes the surrounding `if` mean anything: a pipeline reports the status
  # of its *last* command, so a failed download hands an empty script to sh/bash,
  # which exits 0 — the guard would call that a success and the step would be
  # silently skipped. Same reason every curl carries -f: without it an HTTP error
  # page is a 200-ish body that gets executed.

  # --- 2. apt sources ---------------------------------------------------------
  _apt_repo_wakemeops || failed=$((failed + 1))
  _apt_repo_git       # reports itself; git installs either way
  _apt_repo_helix     || failed=$((failed + 1))
  _apt_repo_node      # reports itself; nodejs installs either way

  run sudo apt-get update || warn "apt-get update failed after adding the apt sources"

  # --- 3. the packages --------------------------------------------------------
  info "apt packages from packages/apt.txt"
  _apt_read_list
  # apt is all-or-nothing: one name it cannot resolve (wrk, for instance, is not
  # packaged on Debian) aborts the whole batch and installs nothing. So fall back
  # to one call per package, which costs a few seconds but only loses the
  # packages that really are unavailable.
  if [ "${#APT_PACKAGES[@]}" -eq 0 ]; then
    warn "packages/apt.txt lists nothing for this machine"
  elif ! run sudo apt-get install -y "${APT_PACKAGES[@]}"; then
    warn "apt-get install failed for the batch — retrying package by package"
    local pkg total=0
    for pkg in "${APT_PACKAGES[@]}"; do
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

  # --- 4. what apt cannot provide ---------------------------------------------

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

  # `bat` normally comes from WakeMeOps and is called `bat`. When that repo is not
  # available the name resolves to Debian's own package instead, whose binary is
  # `batcat` (a name clash with bacula's `bat`) — expose it under its real name
  # via ~/.local/bin, which is already on PATH.
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
