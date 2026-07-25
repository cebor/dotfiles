#!/usr/bin/env bash

# Global git configuration, applied imperatively so nothing clobbers a
# machine-local ~/.gitconfig. The identity is only asked for once.

setup_git() {
  section "Configuring git"

  # every `git config` below is a mutation, so failures have to surface; the
  # closing ok only fires when none of them warned.
  local warnings_before="$LOG_WARNINGS"

  try git config --global core.excludesfile "~/.gitignore_global"

  # helix is the preferred editor, but `./dot packages` cannot install it on
  # plain Debian (no apt package, see setup/packages-linux.sh) — pointing
  # core.editor at a binary that is not there breaks every `git commit`. Re-run
  # this step once helix is in place and it switches over.
  local editor="vim"
  has hx && editor="hx"
  try git config --global core.editor "$editor"
  try git config --global core.autocrlf "input"
  try git config --global push.default "simple"
  try git config --global push.followTags "true"
  try git config --global init.defaultBranch "main"

  # The old layout pointed this at ~/.gitattributes_global, which no longer
  # exists — drop the dangling setting on machines that ran the previous script,
  # but only when it still holds that old value.
  if [ "$(git config --global --get core.attributesfile)" = "~/.gitattributes_global" ]; then
    try git config --global --unset core.attributesfile
  fi

  # credential storage differs per platform. libsecret is not an apt package on
  # Debian/Ubuntu, so Linux normally lands on the cache helper — see packages/apt.txt.
  if is_macos; then
    try git config --global credential.helper "osxkeychain"
  elif has git-credential-libsecret; then
    try git config --global credential.helper libsecret
  else
    try git config --global credential.helper "cache --timeout=3600"
  fi

  # Snapshotted here, not compared below: the identity block has an early return
  # that would skip the closing check, and it warns on its own — those warnings
  # must not count as a failed `git config`.
  local config_failed=0
  [ "$LOG_WARNINGS" -ne "$warnings_before" ] && config_failed=1

  # `ask` stays silent under --yes / --dry-run / without a terminal, so an empty
  # answer there means "could not ask", not "the user wants it empty" — and a
  # question nobody was allowed to ask must not fail the run. Only an actual
  # prompt that came back empty is a failure.
  local interactive=1
  { [ -n "$ASSUME_YES" ] || [ -n "$DRY_RUN" ] || [ ! -t 0 ]; } && interactive=""

  local username email
  if [ -z "$(git config --global user.name)" ]; then
    username="$(ask "Git user.name")"
    [ -n "$username" ] && try git config --global user.name "$username"
  fi
  if [ -z "$(git config --global user.email)" ]; then
    email="$(ask "Git user.email")"
    [ -n "$email" ] && try git config --global user.email "$email"
  fi

  username="$(git config --global user.name)"
  email="$(git config --global user.email)"
  if [ -z "$username" ] || [ -z "$email" ]; then
    warn "git identity incomplete — set it with:"
    warn "  git config --global user.name 'Your Name'"
    warn "  git config --global user.email 'you@example.com'"
    # Unattended, the unset identity alone is not a failure (doctor still flags
    # it) — but a `git config` that failed above still counts.
    [ -n "$interactive" ] && return 1
    return "$config_failed"
  fi

  if [ "$LOG_WARNINGS" -ne "$warnings_before" ]; then
    warn "git configuration incomplete — see the warnings above"
    return 1
  fi
  ok_run "git configured for $username <$email>" \
         "would configure git for $username <$email>"
}
