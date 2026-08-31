#!/usr/bin/env bash

# Symlink engine: mirrors home/ into $HOME.
#
# Rule: FILES are symlinked, DIRECTORIES are mirrored as real directories.
# That keeps ~/.config and ~/.ssh real directories owned by you rather than
# links into this repo, so unrelated tools can keep writing into them.
#
# A manifest of everything linked in the last run lets the next run remove
# links whose source has since been renamed or deleted in the repo.

LINK_SRC="$DOTFILES_ROOT/home"
LINK_MANIFEST="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/manifest"
LINK_BACKUP_ROOT="$HOME/.dotfiles-backup"

# One directory per run, stamped up front so every conflict in this run lands
# together. Created lazily by _backup, so a clean run leaves nothing behind.
_link_backup_dir=""

# All tracked files, as paths relative to home/. Only real files are linked;
# the ignored patterns mirror the repo .gitignore so a stray .DS_Store dropped
# into home/ never ends up linked into $HOME.
link_files() {
  [ -d "$LINK_SRC" ] || return 0
  (cd "$LINK_SRC" && find . -type f ! -name '.DS_Store' ! -name '*.swp' |
    sed 's|^\./||' | sort)
}

# Classify a single relative path: linked | stale-link | self | conflict | missing
#
# The branch order matters. `self` means $dest and $src are the same file, which
# happens when a directory above $dest is a symlink into home/ (a leftover from a
# "link whole directories" setup: ~/.config -> …/dotfiles/home/.config). Only the
# last component is a real file there, so the -L tests see nothing and the path
# would look like an ordinary conflict. It has to be tested after -L, because a
# correctly linked file is `-ef` its source too, and before -e, which would
# otherwise claim it.
_link_state() {
  local rel="$1" src="$LINK_SRC/$1" dest="$HOME/$1"
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then echo "linked"; else echo "stale-link"; fi
  elif [ -e "$dest" ] && [ "$dest" -ef "$src" ]; then
    echo "self"
  elif [ -e "$dest" ]; then
    echo "conflict"
  else
    echo "missing"
  fi
}

# Move an existing real file out of the way before linking over it.
# Prints the backup path on success. Fails without touching $dest if the backup
# cannot be written — the caller must then leave the file alone rather than let
# `ln -f` delete the only copy of it.
_backup() {
  local rel="$1" dest="$HOME/$1"
  if [ -z "$DRY_RUN" ]; then
    # stderr, because the caller reads this in a command substitution: a message
    # from here would bypass the run report entirely. The caller reports the
    # failure itself ("could not back up … left untouched").
    mkdir -p "$_link_backup_dir/$(dirname "$rel")" 2>/dev/null || return 1
    mv "$dest" "$_link_backup_dir/$rel" 2>/dev/null || return 1
  fi
  printf '%s/%s' "$_link_backup_dir" "$rel"
}

# Links recorded last run whose source no longer exists in home/, as paths
# relative to home/. Invisible to link_files, so the manifest is the only record
# of them. Read-only, so link_status can report what _prune would remove.
link_stale() {
  [ -f "$LINK_MANIFEST" ] || return 0
  local rel dest
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "$LINK_SRC/$rel" ] && continue
    dest="$HOME/$rel"
    [ -L "$dest" ] || continue
    case "$(readlink "$dest")" in
      "$LINK_SRC"/*) printf '%s\n' "$rel" ;;
    esac
  done < "$LINK_MANIFEST"
}

# The other half of link_stale: manifest entries whose source is gone from home/
# and whose link does *not* point into the current $LINK_SRC. That is what a
# repo that was moved and then had a file deleted leaves behind — but it is also
# what a link somebody made by hand at the same path looks like, and the two are
# indistinguishable from here, so _prune deliberately leaves them alone.
#
# Dropping them from the manifest instead would lose the only record that will
# ever find them again — the exact loss the manifest exists to prevent — so
# link_tree carries them forward and link_status reports them. Read-only.
link_orphans() {
  [ -f "$LINK_MANIFEST" ] || return 0
  local rel dest
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "$LINK_SRC/$rel" ] && continue
    dest="$HOME/$rel"
    [ -L "$dest" ] || continue
    case "$(readlink "$dest")" in
      "$LINK_SRC"/*) ;;
      *) printf '%s\n' "$rel" ;;
    esac
  done < "$LINK_MANIFEST"
}

# Remove the links link_stale found. link_unlink reuses this before dropping the
# manifest. Sets $_link_pruned.
#
# $1, if given, is a file to append entries we failed to remove to. The caller
# must carry those into the new manifest: the link is still out there, and this
# record is the only thing that will ever find it again — dropping it on a
# transient rm failure would orphan the link permanently.
_link_pruned=0
_prune() {
  local keep="$1"
  _link_pruned=0
  # `run` is a no-op under --dry-run, so the report has to stay in the
  # conditional — nothing may read as if it had already happened
  local did="removed"
  [ -n "$DRY_RUN" ] && did="would remove"
  local rel dest
  while IFS= read -r rel; do
    dest="$HOME/$rel"
    if run rm -f "$dest"; then
      _link_pruned=$((_link_pruned + 1))
      ok "$did $rel (no longer in home/)"
    else
      err "$rel — could not remove stale link $dest"
      if [ -n "$keep" ]; then printf '%s\n' "$rel" >> "$keep"; fi
    fi
  done < <(link_stale)
}

# Link every file in home/ into $HOME. Idempotent.
link_tree() {
  local rel src dest parent state note backup identical what
  local linked=0 replaced=0 unchanged=0 failed=0
  # parents we already created — only a dry run needs this: there `mkdir` never
  # runs, so `[ ! -d "$parent" ]` stays true and every file in a directory would
  # echo the same `mkdir -p` again. A ':'-joined string rather than an
  # associative array: macOS still ships bash 3.2.
  local made_parents=""
  # dry-run tense for the ✓ below; the $note texts already carry their own
  local did=""
  [ -n "$DRY_RUN" ] && did="would link "
  local manifest_tmp
  if [ -n "$DRY_RUN" ]; then
    # a dry run writes nothing at all, not even under $TMPDIR — and it never
    # installs the manifest anyway, so the collected entries go nowhere
    manifest_tmp=/dev/null
  else
    # an explicit template: BSD/macOS mktemp does not take a bare invocation
    manifest_tmp="$(mktemp "${TMPDIR:-/tmp}/dotfiles-manifest.XXXXXX")" ||
      { err "could not create a temp file for the manifest"; return 1; }
  fi
  _link_backup_dir="$LINK_BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"

  # stale links we could not remove go straight into the new manifest, so the
  # next run gets another chance at them
  _prune "$manifest_tmp"

  # links we refuse to remove but must not forget either — see link_orphans.
  # Disjoint from both loops around it: _prune takes the ones pointing into
  # $LINK_SRC, the loop below only ever sees paths that still exist in home/.
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    warn "$rel — points at another checkout ($(readlink "$HOME/$rel")), left untouched — remove it by hand"
    printf '%s\n' "$rel" >> "$manifest_tmp"
  done < <(link_orphans)

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    src="$LINK_SRC/$rel"
    dest="$HOME/$rel"
    parent="$(dirname "$dest")"
    state="$(_link_state "$rel")"
    note=""
    # per iteration, not per run: the error paths below report it, and a value
    # left over from an earlier file would name the wrong backup
    backup=""

    case "$state" in
      linked)
        unchanged=$((unchanged + 1))
        printf '%s\n' "$rel" >> "$manifest_tmp"
        skip "$rel"
        continue
        ;;
      self)
        # nothing to link (see _link_state) — as a conflict this would back up the
        # repo's own file and leave a link pointing at itself
        err "$rel — $dest is the repo file itself (a directory above it links into home/), left untouched"
        failed=$((failed + 1))
        continue
        ;;
      conflict)
        # A real file is in the way. Move it aside first — and if that fails,
        # leave it exactly where it is instead of linking over it.
        identical=""
        what="had local changes"
        if [ -d "$dest" ]; then
          what="was a directory"
        elif cmp -s "$src" "$dest" 2>/dev/null; then
          identical=1
        fi
        if ! backup="$(_backup "$rel")"; then
          err "$rel — could not back up $dest, left untouched"
          failed=$((failed + 1))
          continue
        fi
        if [ -n "$identical" ] && [ -n "$DRY_RUN" ]; then
          note=" (identical copy would be backed up)"
        elif [ -n "$identical" ]; then
          note=" (identical copy backed up)"
        elif [ -n "$DRY_RUN" ]; then
          warn "$rel $what — would be saved to $backup"
          note=" (local version would be backed up)"
        else
          warn "$rel $what — saved to $backup"
          note=" (local version backed up)"
        fi
        ;;
      stale-link)
        if ! run rm -f "$dest"; then
          err "$rel — could not remove the old link"
          failed=$((failed + 1))
          continue
        fi
        note=" (was pointing elsewhere)"
        ;;
    esac

    # `":$parent/"` also matches the ancestors: `mkdir -p a/b` already created `a`.
    # The errors carry $backup when there is one — a conflict moved aside and then
    # not linked is gone from $HOME, and for an identical copy nothing else says
    # where it went.
    if [ ! -d "$parent" ] &&
       [[ ":$made_parents:" != *":$parent:"* ]] &&
       [[ ":$made_parents:" != *":$parent/"* ]]; then
      if ! run mkdir -p "$parent"; then
        err "$rel — could not create $parent${backup:+; your copy is at $backup}"
        failed=$((failed + 1))
        continue
      fi
      made_parents="$made_parents:$parent"
    fi
    if ! run ln -sfn "$src" "$dest"; then
      err "$rel — could not create the link${backup:+; your copy is at $backup}"
      failed=$((failed + 1))
      continue
    fi

    # recorded only now: a file that failed above must not show up in the
    # manifest as if it had been linked
    printf '%s\n' "$rel" >> "$manifest_tmp"
    case "$state" in
      missing) linked=$((linked + 1)) ;;
      *)       replaced=$((replaced + 1)) ;;
    esac
    ok "$did$rel$note"
  done < <(link_files)

  # ~/.ssh must not be group/world readable
  if [ -d "$HOME/.ssh" ]; then
    run chmod 700 "$HOME/.ssh" || warn "could not chmod 700 $HOME/.ssh"
  fi

  # nothing to install or clean up under --dry-run: manifest_tmp is /dev/null
  if [ -z "$DRY_RUN" ]; then
    if mkdir -p "$(dirname "$LINK_MANIFEST")" && mv "$manifest_tmp" "$LINK_MANIFEST"; then
      :
    else
      warn "could not write $LINK_MANIFEST — the next sync cannot prune removed files"
      rm -f "$manifest_tmp"
    fi
  fi

  blank
  local summary="linked"
  [ -n "$DRY_RUN" ] && summary="would link"
  info "$summary: $linked new, $replaced replaced, $unchanged already current"
  if [ "$failed" -gt 0 ]; then
    info "$failed failed — see the errors above"
    return 1
  fi
  return 0
}

# Read-only report, reused by `dot doctor`.
link_status() {
  local rel state bad=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    state="$(_link_state "$rel")"
    case "$state" in
      linked)     skip "$rel" ;;
      missing)    warn "$rel — not linked" ; bad=1 ;;
      self)       warn "$rel — resolves to the repo file itself: a directory above it links into home/" ; bad=1 ;;
      conflict)   warn "$rel — a real file is in the way" ; bad=1 ;;
      stale-link) warn "$rel — link points elsewhere: $(readlink "$HOME/$rel")" ; bad=1 ;;
    esac
  done < <(link_files)

  # links whose source is gone from home/: only the manifest knows about them, so
  # without this they stay invisible and `doctor` would report all clear
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    warn "$rel — no longer in home/, stale link left over — run ./dot sync"
    bad=1
  done < <(link_stale)

  # …and the ones ./dot sync will not clean up on its own
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    warn "$rel — no longer in home/, points at another checkout: $(readlink "$HOME/$rel")"
    bad=1
  done < <(link_orphans)

  return $bad
}

# Remove every link we created and restore the newest backup, if any.
link_unlink() {
  local rel dest removed=0 newest
  local did="unlinked" summary="removed"
  # Nothing here aborts on its own, so the status is collected the way link_tree
  # collects its $failed — via the error count, because the failures are spread
  # over three branches plus _prune, which reports its own.
  local errors_before="$LOG_ERRORS"
  if [ -n "$DRY_RUN" ]; then did="would unlink"; summary="would be removed"; fi

  # Links we could not remove have to survive in the manifest — it is the only
  # record that will ever find them again, and this command drops it otherwise.
  local kept
  if [ -n "$DRY_RUN" ]; then
    kept=/dev/null
  else
    kept="$(mktemp "${TMPDIR:-/tmp}/dotfiles-manifest.XXXXXX")" ||
      { err "could not create a temp file for the manifest"; return 1; }
  fi

  # First the links whose source is already gone from home/: link_files cannot
  # see them, and dropping the manifest below would strand them for good.
  _prune "$kept"
  removed=$((removed + _link_pruned))

  # not ours to remove, but the record has to survive the manifest being dropped
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    warn "$rel — points at another checkout ($(readlink "$HOME/$rel")), left untouched"
    printf '%s\n' "$rel" >> "$kept"
  done < <(link_orphans)

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    dest="$HOME/$rel"
    [ -L "$dest" ] || continue
    # A link at our path that points somewhere else — what link_status calls a
    # stale-link, typically a leftover from an older checkout path. Not ours to
    # remove (same reasoning as link_orphans), but staying silent about it is
    # worse: the closing "N link(s) removed" would read as "nothing was left".
    if [ "$(readlink "$dest")" != "$LINK_SRC/$rel" ]; then
      warn "$rel — points at another checkout ($(readlink "$dest")), left untouched"
      continue
    fi
    if ! run rm -f "$dest"; then
      err "$rel — could not remove the link"
      printf '%s\n' "$rel" >> "$kept"
      continue
    fi
    removed=$((removed + 1))
    ok "$did $rel"
  done < <(link_files)

  # nothing survived -> the manifest has no purpose left; otherwise it keeps the
  # leftovers so the next ./dot sync can try again
  if [ -z "$DRY_RUN" ]; then
    if [ -s "$kept" ]; then
      if mkdir -p "$(dirname "$LINK_MANIFEST")" && mv "$kept" "$LINK_MANIFEST"; then
        warn "$(wc -l < "$LINK_MANIFEST" | tr -d ' ') link(s) left behind — kept in the manifest so the next ./dot sync still knows about them"
      else
        err "could not update $LINK_MANIFEST — the links left behind are now untracked"
        rm -f "$kept"
      fi
    else
      rm -f "$kept" "$LINK_MANIFEST"
    fi
  fi

  newest="$(find "$LINK_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
  if [ -n "$newest" ]; then
    blank
    info "Newest backup: $newest"
    # Copying a backup back over $HOME is destructive, so it is only ever offered
    # to a human at a terminal. The missing terminal and --dry-run cases are
    # handled inside confirm; --yes has to be re-checked here, because confirm
    # answers *yes* to it and this is the one question where that is wrong.
    if [ -z "$ASSUME_YES" ] && confirm "Restore it into \$HOME?"; then
      if run cp -a "$newest/." "$HOME/"; then
        ok_run "backup restored" "would restore the backup"
      else
        err "could not restore the backup"
      fi
    else
      info "Restore it with: cp -a '$newest/.' \"\$HOME/\""
    fi
  fi

  blank
  info "$removed link(s) $summary"
  if [ "$LOG_ERRORS" -ne "$errors_before" ]; then
    return 1
  fi
  return 0
}
