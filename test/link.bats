#!/usr/bin/env bats
#
# lib/link.sh — the symlink engine.
#
# This is where the subtle rules from CLAUDE.md live: files are linked but
# directories are mirrored, the branch order in _link_state, "if the backup fails
# leave the file alone", and the manifest as the only record that will ever find
# a renamed link again. None of that is enforced by anything but these tests.

load helper

setup() {
  setup_sandbox
  load_dotfiles
  seed_src
}

teardown() { teardown_sandbox; }

# --- link_files ------------------------------------------------------------

@test "link_files lists real files only, relative and sorted" {
  touch "$SANDBOX/src/.DS_Store"
  touch "$SANDBOX/src/.vimrc.swp"
  ln -s /etc/hosts "$SANDBOX/src/.a-symlink"

  bats_run link_files
  [ "$status" -eq 0 ]
  # the ignored patterns mirror the repo .gitignore, so a stray macOS turd
  # dropped into home/ never ends up linked into $HOME
  [ "$output" = ".aliases
.config/helix/config.toml
.ssh/config
.zshrc" ]
}

@test "link_files is empty when home/ does not exist" {
  LINK_SRC="$SANDBOX/nope"
  bats_run link_files
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _link_state -----------------------------------------------------------

@test "_link_state classifies missing, linked, stale-link and conflict" {
  [ "$(_link_state .zshrc)" = "missing" ]

  ln -sfn "$LINK_SRC/.zshrc" "$HOME/.zshrc"
  [ "$(_link_state .zshrc)" = "linked" ]

  ln -sfn /somewhere/else "$HOME/.zshrc"
  [ "$(_link_state .zshrc)" = "stale-link" ]

  rm "$HOME/.zshrc"
  mkfile "$HOME/.zshrc" "mine"
  [ "$(_link_state .zshrc)" = "conflict" ]
}

@test "_link_state calls a file under a directory-link 'self', not 'conflict'" {
  # the leftover from a "link whole directories" setup: ~/.config itself is a
  # link into home/, so the last component is the repo's own file. Classifying
  # it as a conflict would back up the repo file and link it to itself — which
  # is exactly what the branch order (after -L, before -e) prevents.
  ln -sfn "$LINK_SRC/.config" "$HOME/.config"

  [ "$(_link_state .config/helix/config.toml)" = "self" ]
}

# --- link_tree: the happy path ---------------------------------------------

@test "link_tree links files and mirrors directories" {
  bats_run link_tree
  [ "$status" -eq 0 ]

  [ -L "$HOME/.zshrc" ]
  [ "$(readlink "$HOME/.zshrc")" = "$LINK_SRC/.zshrc" ]

  # directories stay real, so unrelated tools can keep writing into them
  [ -d "$HOME/.config" ] && [ ! -L "$HOME/.config" ]
  [ -d "$HOME/.config/helix" ] && [ ! -L "$HOME/.config/helix" ]
  [ -L "$HOME/.config/helix/config.toml" ]
}

@test "link_tree chmods ~/.ssh to 700" {
  bats_run link_tree
  [ "$(ls -ld "$HOME/.ssh" | cut -c1-10)" = "drwx------" ]
}

@test "link_tree is idempotent" {
  link_tree >/dev/null
  local before
  before="$(snapshot_fs "$HOME")"

  bats_run link_tree
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 new, 0 replaced, 4 already current"* ]]
  [ "$before" = "$(snapshot_fs "$HOME")" ]
}

@test "link_tree writes the manifest" {
  link_tree >/dev/null
  [ -f "$LINK_MANIFEST" ]
  bats_run cat "$LINK_MANIFEST"
  [ "$output" = ".aliases
.config/helix/config.toml
.ssh/config
.zshrc" ]
}

# --- link_tree: conflicts and backups --------------------------------------

@test "link_tree backs a conflicting file up before linking over it" {
  mkfile "$HOME/.zshrc" "my local version"

  bats_run link_tree
  [ "$status" -eq 0 ]
  [[ "$output" == *"had local changes"* ]]

  [ -L "$HOME/.zshrc" ]
  local backup
  backup="$(find "$HOME/.dotfiles-backup" -name .zshrc -type f)"
  [ -n "$backup" ]
  grep -q "my local version" "$backup"
}

@test "link_tree notes an identical copy rather than warning about it" {
  mkfile "$HOME/.zshrc" "zshrc"

  bats_run link_tree
  [[ "$output" == *"identical copy backed up"* ]]
  [[ "$output" != *"had local changes"* ]]
}

@test "link_tree leaves the file untouched when the backup fails" {
  skip_if_root
  mkfile "$HOME/.zshrc" "the only copy"
  # _backup cannot create its timestamp directory under an unwritable root
  mkdir -p "$LINK_BACKUP_ROOT"
  chmod 500 "$LINK_BACKUP_ROOT"

  bats_run link_tree
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not back up"* ]]

  # ln -f must never be the thing that deletes the only copy
  [ ! -L "$HOME/.zshrc" ]
  [ -f "$HOME/.zshrc" ]
  grep -q "the only copy" "$HOME/.zshrc"
}

@test "link_tree replaces a link that points elsewhere" {
  ln -sfn /somewhere/else "$HOME/.zshrc"

  bats_run link_tree
  [[ "$output" == *"was pointing elsewhere"* ]]
  [ "$(readlink "$HOME/.zshrc")" = "$LINK_SRC/.zshrc" ]
}

@test "link_tree refuses to touch a file that is the repo's own" {
  ln -sfn "$LINK_SRC/.config" "$HOME/.config"

  bats_run link_tree
  [ "$status" -eq 1 ]
  [[ "$output" == *"is the repo file itself"* ]]
  # the repo's file is still a plain file, not a link to itself
  [ ! -L "$LINK_SRC/.config/helix/config.toml" ]
  grep -q "helix" "$LINK_SRC/.config/helix/config.toml"
}

# --- the manifest ----------------------------------------------------------

@test "a renamed source is pruned on the next sync" {
  link_tree >/dev/null
  mv "$SANDBOX/src/.zshrc" "$SANDBOX/src/.zshrc-new"

  # invisible to link_files — the manifest is the only thing that still knows
  bats_run link_stale
  [ "$output" = ".zshrc" ]

  bats_run link_tree
  [[ "$output" == *"removed .zshrc (no longer in home/)"* ]]
  [ ! -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]
  [ -L "$HOME/.zshrc-new" ]
  ! grep -qx ".zshrc" "$LINK_MANIFEST"
}

@test "a link into another checkout is reported but never removed" {
  link_tree >/dev/null
  # what a moved repo leaves behind — and what a hand-made link at the same path
  # looks like. The two are indistinguishable, so this must not be deleted.
  mkfile "$SANDBOX/other/.oldrc" "elsewhere"
  ln -s "$SANDBOX/other/.oldrc" "$HOME/.oldrc"
  printf '%s\n' ".oldrc" >> "$LINK_MANIFEST"

  bats_run link_orphans
  [ "$output" = ".oldrc" ]
  bats_run link_stale
  [ -z "$output" ]

  bats_run link_tree
  [[ "$output" == *"points at another checkout"* ]]
  [ -L "$HOME/.oldrc" ]
  # carried forward: dropping it would lose the only record of the link
  grep -qx ".oldrc" "$LINK_MANIFEST"
}

@test "a stale link that could not be removed stays in the manifest" {
  skip_if_root
  link_tree >/dev/null
  rm "$SANDBOX/src/.config/helix/config.toml"
  # rm fails when the parent directory is not writable
  chmod 500 "$HOME/.config/helix"

  bats_run link_tree
  [[ "$output" == *"could not remove stale link"* ]]

  chmod 700 "$HOME/.config/helix"
  # the next run gets another chance at it, which needs the record to survive
  grep -qx ".config/helix/config.toml" "$LINK_MANIFEST"
}

# --- the dry-run invariant -------------------------------------------------

@test "a dry run writes nothing at all" {
  # a dirty starting point, so the conflict, backup and chmod paths are all
  # actually reached rather than short-circuited
  mkfile "$HOME/.zshrc" "my local version"
  ln -sfn /somewhere/else "$HOME/.aliases"
  mkdir -p "$HOME/.ssh"
  chmod 755 "$HOME/.ssh"

  local home_before state_before tmp_before
  home_before="$(snapshot_fs "$HOME")"
  state_before="$(snapshot_fs "$XDG_STATE_HOME")"
  tmp_before="$(snapshot_fs "$TMPDIR")"

  DRY_RUN=1
  bats_run link_tree
  [ "$status" -eq 0 ]

  [ "$home_before" = "$(snapshot_fs "$HOME")" ]
  [ "$state_before" = "$(snapshot_fs "$XDG_STATE_HOME")" ]
  # not even under $TMPDIR — the manifest goes to /dev/null on a dry run
  [ "$tmp_before" = "$(snapshot_fs "$TMPDIR")" ]
}

@test "a dry run reports in the conditional" {
  mkfile "$HOME/.zshrc" "my local version"
  DRY_RUN=1

  bats_run link_tree
  [[ "$output" == *"would link"* ]]
  [[ "$output" == *"would be saved to"* ]]
  # the past tense of the same message must not appear
  [[ "$output" != *"— saved to"* ]]
  [[ "$output" != *"local version backed up"* ]]
}

@test "a dry run says 'would remove' for a stale link" {
  link_tree >/dev/null
  rm "$SANDBOX/src/.zshrc"
  DRY_RUN=1

  bats_run link_tree
  [[ "$output" == *"would remove .zshrc"* ]]
  [ -L "$HOME/.zshrc" ]
}

# --- link_status -----------------------------------------------------------

@test "link_status reports every kind of drift" {
  link_tree >/dev/null
  rm "$HOME/.aliases"                                  # missing
  ln -sfn /somewhere/else "$HOME/.zshrc"               # stale-link
  rm "$HOME/.ssh/config"; mkfile "$HOME/.ssh/config" x # conflict

  bats_run link_status
  [ "$status" -eq 1 ]
  [[ "$output" == *".aliases — not linked"* ]]
  [[ "$output" == *".zshrc — link points elsewhere"* ]]
  [[ "$output" == *".ssh/config — a real file is in the way"* ]]
}

@test "link_status reports a leftover link the manifest is the only record of" {
  link_tree >/dev/null
  rm "$SANDBOX/src/.zshrc"

  # without the manifest read, doctor would report all clear here
  bats_run link_status
  [ "$status" -eq 1 ]
  [[ "$output" == *".zshrc — no longer in home/, stale link left over"* ]]
}

@test "link_status is clean after a sync" {
  link_tree >/dev/null
  bats_run link_status
  [ "$status" -eq 0 ]
  [[ "$output" != *"—"* ]]
}

# --- link_unlink -----------------------------------------------------------

@test "link_unlink removes our links and leaves real files alone" {
  link_tree >/dev/null
  mkfile "$HOME/keep-me" "not ours"
  ASSUME_YES=1

  bats_run link_unlink
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.zshrc" ]
  [ ! -L "$HOME/.config/helix/config.toml" ]
  [ -f "$HOME/keep-me" ]
  # the directories we mirrored are not ours to delete either
  [ -d "$HOME/.config/helix" ]
  # nothing survived, so the manifest has no purpose left
  [ ! -f "$LINK_MANIFEST" ]
}

@test "link_unlink does not restore a backup under --yes" {
  link_tree >/dev/null
  mkdir -p "$LINK_BACKUP_ROOT/20240101-000000"
  printf 'old\n' > "$LINK_BACKUP_ROOT/20240101-000000/.zshrc"
  ASSUME_YES=1

  bats_run link_unlink
  # --yes means "do not prompt", and for "copy this over \$HOME?" the shared
  # yes-default is the one answer that would be wrong
  [[ "$output" == *"Restore it with:"* ]]
  [ ! -e "$HOME/.zshrc" ]
}

@test "link_unlink leaves a link pointing at another checkout" {
  link_tree >/dev/null
  ln -sfn /somewhere/else "$HOME/.zshrc"
  ASSUME_YES=1

  bats_run link_unlink
  [[ "$output" == *"points at another checkout"* ]]
  [ -L "$HOME/.zshrc" ]
}

@test "link_unlink keeps a link it could not remove in the manifest" {
  # CLAUDE.md: *both* link_tree and link_unlink carry entries they failed to
  # remove into the new manifest. link_tree's half is covered above; this is the
  # other one, and it matters more here — link_unlink drops the manifest
  # otherwise, and the record is the only thing that will ever find the link again.
  skip_if_root
  link_tree >/dev/null
  # rm fails when the parent directory is not writable
  chmod 500 "$HOME/.config/helix"
  ASSUME_YES=1

  bats_run link_unlink
  [[ "$output" == *"could not remove the link"* ]]
  # the error has to reach the exit code, not only $LOG_ERRORS
  [ "$status" -ne 0 ]

  chmod 700 "$HOME/.config/helix"
  grep -qx ".config/helix/config.toml" "$LINK_MANIFEST"
}

@test "a dry run of link_unlink writes nothing and speaks in the conditional" {
  link_tree >/dev/null
  local home_before state_before tmp_before
  home_before="$(snapshot_fs "$HOME")"
  state_before="$(snapshot_fs "$XDG_STATE_HOME")"
  tmp_before="$(snapshot_fs "$TMPDIR")"
  DRY_RUN=1

  bats_run link_unlink
  [ "$status" -eq 0 ]
  [[ "$output" == *"would unlink"* ]]
  [[ "$output" == *"would be removed"* ]]
  # nothing may read as if it had already happened
  [[ "$output" != *"unlinked ."* ]]

  [ "$home_before" = "$(snapshot_fs "$HOME")" ]
  # the manifest survives a forecast untouched
  [ "$state_before" = "$(snapshot_fs "$XDG_STATE_HOME")" ]
  # not even under $TMPDIR — the kept-entries file goes to /dev/null on a dry run
  [ "$tmp_before" = "$(snapshot_fs "$TMPDIR")" ]
}
