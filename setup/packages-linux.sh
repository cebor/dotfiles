#!/usr/bin/env bash

# Linux package installation (Ubuntu) — the counterpart to `brew bundle`.
#
# Sources first, packages second: every third-party apt source is added up front
# (WakeMeOps, the git PPA, NodeSource), then a single apt-get install pulls the
# whole of packages/apt.txt — helix included, as `hx`, from Ubuntu 26.04 on. Only
# what apt cannot carry at all is installed after that — helix on older releases
# (classic snap), antidote (git clone) and starship (upstream installer).
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

# Is there an *enabled* apt source matching the ERE $1? A file counts when an
# uncommented line matches and deb822 `Enabled: no` does not switch it off —
# do-release-upgrade leaves third-party sources behind in exactly those two
# shapes, and a guard that took them for live would never re-add them. With
# $2, the same file must also name that release codename. $APT_SOURCES_DIR
# exists for the tests.
_apt_source_enabled() {
  local pattern="$1" codename="$2" f
  for f in "${APT_SOURCES_DIR:-/etc/apt/sources.list.d}"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.list|*.sources) ;; *) continue ;; esac
    grep -qiE '^[[:space:]]*Enabled:[[:space:]]*no' "$f" && continue
    grep -qE "^[^#]*$pattern" "$f" || continue
    if [ -n "$codename" ] && ! grep -qE "^[^#]*[[:space:]]$codename([[:space:]]|$)" "$f"; then
      continue
    fi
    return 0
  done
  return 1
}

# WakeMeOps — a signed apt repo (https://docs.wakemeops.com) carrying kubectl,
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
  # a release upgrade switches the file off with `Enabled: no` rather than
  # removing it — that is no repo
  if grep -qxF "Components: $components" "$sources" 2>/dev/null &&
     ! grep -qiE '^[[:space:]]*Enabled:[[:space:]]*no' "$sources"; then
    skip "wakemeops repo ($components)"
    return 0
  fi

  info "Adding the WakeMeOps repo ($components)..."
  # the installer writes its keyring straight into /etc/apt/keyrings without
  # creating the directory — it ships with Ubuntu 22.04 and later, but not with
  # anything older
  if run sudo mkdir -p /etc/apt/keyrings &&
     run bash -c "set -o pipefail
       curl -fsSL https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository \
         | sudo bash -s '$components'"; then
    return 0
  fi
  err "could not add the WakeMeOps repo — kubectl, helm, yq and bat will be missing"
  return 1
}

# git — the distro ships a git that is a year or more behind. This PPA is
# upstream's own stable build.
#
# The guard searches the directory rather than naming a file, for the same reason
# as the NodeSource one: add-apt-repository writes `.list` on older Ubuntu and
# deb822 `.sources` from 24.04 on, and a filename guard would silently stop
# matching — re-running add-apt-repository on every ./dot packages. And it wants
# an enabled entry for the *current* codename: after a release upgrade the old
# one is disabled, or still names the previous release.
_apt_repo_git() {
  if _apt_source_enabled 'git-core/ppa' "$(os_codename)"; then
    skip "git ppa"
    return 0
  fi

  info "Adding the git PPA..."
  run sudo add-apt-repository -y ppa:git-core/ppa && return 0
  # a warning rather than an error, and a 0 return: `git` is in apt.txt, so the run
  # does end with a git — just the distro's older one. The helix step in section 4
  # errs instead, because once apt had no hx there it is the snap or nothing.
  warn "could not add the git PPA — git will come from the distro (older)"
  return 0
}

# Node.js — the distro's `nodejs` is years behind. The guard is the sources file
# rather than `has node`, so a node that came from nvm or a manual install cannot
# stop the repo from being added — `nodejs` is in apt.txt either way, and without
# the repo it would quietly come from the distro instead.
#
# An explicit major rather than `setup_current.x`: that writes whichever major is
# current on the day it runs, and the guard would then keep every machine on it
# forever. With the major in the guard, a bump here reaches every machine.
#
# It searches the directory for the repo rather than naming a file: the installer
# used to write `nodesource.list` and now writes `nodesource.sources` (deb822), so
# a filename guard silently stops matching the day upstream switches format — and
# then re-runs the whole installer on every ./dot packages.
_apt_repo_node() {
  local major=26
  if _apt_source_enabled "deb\.nodesource\.com/node_${major}\.x"; then
    skip "nodesource repo (node ${major}.x)"
    return 0
  fi

  info "Adding the NodeSource repo (node ${major}.x)..."
  # no `sudo -E`: sudo-rs ignores it with a warning, and the script needs nothing
  # from the caller's environment
  run bash -c "set -o pipefail; curl -fsSL https://deb.nodesource.com/setup_${major}.x | sudo bash -" &&
    return 0
  # a warning rather than an error, and a 0 return: apt.txt still installs
  # `nodejs`, so the run does end with a node — just an older one
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
  has add-apt-repository || missing="$missing software-properties-common"
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
  _apt_repo_node      # reports itself; nodejs installs either way

  run sudo apt-get update || warn "apt-get update failed after adding the apt sources"

  # --- 3. the packages --------------------------------------------------------
  info "apt packages from packages/apt.txt"
  _apt_read_list
  # apt is all-or-nothing: one name it cannot resolve aborts the whole batch and
  # installs nothing. So fall back to one call per package, which costs a few
  # seconds but only loses the packages that really are unavailable.
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
    # A name this machine does not carry is expected; *none* of them getting
    # through is not — that is apt or sudo being unreachable, and
    # the closing ok would otherwise put a ✓ on a run that installed nothing.
    # Guarded on > 0 so an empty apt.txt cannot trigger it, and `run` returns 0
    # under --dry-run, so a forecast never lands here either.
    if [ "$unavailable" -gt 0 ] && [ "$unavailable" -eq "$total" ]; then
      err "apt installed nothing — apt or sudo is unreachable, not a packaging gap"
      failed=$((failed + 1))
    fi
  fi

  # --- 4. what apt cannot provide ---------------------------------------------

  # helix — apt carries it as `hx` from Ubuntu 26.04 on, and step 3 installed it
  # from packages/apt.txt. Older releases have no apt package, and the PPA it
  # used to come from (ppa:maveonair/helix-editor) stopped at oracular (24.10), so
  # there the classic snap is the fallback — classic because helix needs the whole
  # filesystem; it ships the `hx` alias itself, so nothing here has to link it.
  #
  # The guard is `has hx`, not `snap list helix`: a helix from anywhere else — apt
  # first of all — should stop the snap from being installed alongside it, the
  # same way `has starship` works below.
  if has hx; then
    skip "helix"
  elif { ! has snap || [ ! -S /run/snapd.socket ]; } && [ -z "$DRY_RUN" ]; then
    # its own message rather than the generic one: without systemd — which under
    # WSL means `systemd=true` in /etc/wsl.conf — snapd is not there to be reached,
    # and "snap install failed" would not say what to do about it.
    #
    # Not under --dry-run, for the same reason as the prerequisite check in step 1:
    # `snapd` is in apt.txt, so on a forecast run its absence only means step 3 has
    # not really run yet — the honest forecast is the "would install" below. The
    # socket is checked too: the snapd package always ships /usr/bin/snap.
    err "snapd is not running — helix will be missing (under WSL: systemd=true in /etc/wsl.conf)"
    failed=$((failed + 1))
  elif run sudo snap install helix --classic; then
    ok_run "helix installed" "would install helix"
  else
    # an error, not a warning: unlike git and nodejs there is no source left
    # once apt had no hx
    err "helix snap install failed"
    failed=$((failed + 1))
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

  # `bat` normally comes from WakeMeOps and is called `bat`. When that repo is not
  # available the name resolves to the distro's own package instead, whose binary
  # is `batcat` (a name clash with bacula's `bat`) — expose it under its real name
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
