#!/usr/bin/env bats
#
# The CLI itself, driven as a subprocess the way a user drives it.
#
# `dot` calls main "$@" at file scope, so it cannot be sourced — which is fine:
# running the real entrypoint is the more honest coverage anyway. Everything here
# uses the sandbox $HOME from helper.bash, so it is safe to run on a real machine.

load helper

setup() {
  setup_sandbox
  # bats' skip is not shadowed here — nothing in this file sources lib/log.sh
}

teardown() { teardown_sandbox; }

# --- argument parsing ------------------------------------------------------

@test "no command and 'help' both print the usage" {
  run "$DOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./dot <command>"* ]]

  run "$DOT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./dot <command>"* ]]

  run "$DOT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./dot <command>"* ]]
}

@test "an unknown command fails and says so" {
  run "$DOT" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown command: bogus"* ]]
}

@test "commands reject options they do not understand" {
  run "$DOT" sync --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown sync option"* ]]

  run "$DOT" configure nonsense
  [ "$status" -ne 0 ]
}

@test "an option nobody understood is not swallowed by the usage" {
  # `./dot --bogus` used to print the help and exit 0 — the global parser dropped
  # unknown options into $args, and the no-command branch never looked at them
  run "$DOT" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unrecognised argument(s): --bogus"* ]]

  run "$DOT" help extra-arg
  [ "$status" -ne 0 ]

  # a plain help still succeeds
  run "$DOT" -h
  [ "$status" -eq 0 ]
}

@test "sync rejects --status and --unlink together" {
  run "$DOT" sync --status --unlink
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot be combined"* ]]
}

@test "--linux overrides platform detection" {
  # the flag exists so a Mac can exercise the Linux path; here it just has to
  # reach the Linux branch rather than being ignored
  run "$DOT" --linux configure locale -n
  [[ "$output" != *"skipping"*"macOS"* ]]
}

# --- sync, for real, into the sandbox --------------------------------------

@test "sync links the repo's home/ and is idempotent" {
  run "$DOT" sync -y
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [ "$(readlink "$HOME/.zshrc")" = "$DOTFILES_ROOT/home/.zshrc" ]
  [ -d "$HOME/.config" ] && [ ! -L "$HOME/.config" ]
  # and `dot` itself, onto the ~/.local/bin that home/.exports puts on $PATH
  [ "$(readlink "$HOME/.local/bin/dot")" = "$DOT" ]

  local before
  before="$(snapshot_fs "$HOME")"
  run "$DOT" sync -y
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 new, 0 replaced"* ]]
  [ "$before" = "$(snapshot_fs "$HOME")" ]
}

@test "sync --status is clean right after a sync" {
  "$DOT" sync -y >/dev/null
  run "$DOT" sync --status
  [ "$status" -eq 0 ]
  [[ "$output" != *"not linked"* ]]
  [[ "$output" != *"in the way"* ]]
}

@test "sync --status reports drift without writing" {
  "$DOT" sync -y >/dev/null
  rm "$HOME/.zshrc"
  local before
  before="$(snapshot_fs "$HOME")"

  run "$DOT" sync --status
  [ "$status" -ne 0 ]
  [[ "$output" == *".zshrc — not linked"* ]]
  [ "$before" = "$(snapshot_fs "$HOME")" ]
}

@test "sync --unlink removes what sync created" {
  "$DOT" sync -y >/dev/null
  run "$DOT" sync --unlink -y
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.zshrc" ]
  [ ! -L "$HOME/.config/helix/config.toml" ]
  [ ! -e "$HOME/.local/bin/dot" ]
}

# --- the dry-run invariant, end to end -------------------------------------

@test "a dry run of sync writes nothing" {
  local before
  before="$(snapshot_fs "$HOME")"

  run "$DOT" sync -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"would link"* ]]
  [ "$before" = "$(snapshot_fs "$HOME")" ]
  [ "$(snapshot_fs "$XDG_STATE_HOME")" != "" ]
  [ ! -e "$XDG_STATE_HOME/dotfiles/manifest" ]
}

@test "a dry run of install writes nothing and executes nothing" {
  # exit 99 if ever invoked: under --dry-run every mutating command goes through
  # `run`, which only echoes. Anything that reaches these is a bug.
  stub_bin sudo 99
  stub_bin apt-get 99
  stub_bin brew 99
  # present so the prerequisite checks pass; `has` never executes them
  stub_bin gpg 99
  stub_bin add-apt-repository 99

  local home_before state_before tmp_before
  home_before="$(snapshot_fs "$HOME")"
  state_before="$(snapshot_fs "$XDG_STATE_HOME")"
  tmp_before="$(snapshot_fs "$TMPDIR")"

  run "$DOT" install -n -y --linux

  # The exit code is deliberately not asserted: on a bare machine a missing
  # prerequisite is a real error, and that is the correct report. What must hold
  # everywhere is that nothing was written and nothing was run.
  [ "$home_before" = "$(snapshot_fs "$HOME")" ]
  [ "$state_before" = "$(snapshot_fs "$XDG_STATE_HOME")" ]
  [ "$tmp_before" = "$(snapshot_fs "$TMPDIR")" ]

  ! stub_called sudo
  ! stub_called apt-get
  ! stub_called brew
}

@test "a dry run speaks in the conditional" {
  run "$DOT" sync -n
  [[ "$output" == *"would link"* ]]
  # nothing may read as if it had already happened
  [[ "$output" != *"linked: "*" new"* ]] || [[ "$output" == *"would link: "* ]]
}

# --- update ----------------------------------------------------------------

# A throwaway checkout of this repo in the sandbox, with a bare upstream it can
# be fast-forwarded from. `dot update` acts on its own $DOTFILES_ROOT, so this is
# the only way to exercise it without touching the real repo.
#
# Sets $CLONE (the work tree, whose ./dot is the one under test) and $UPSTREAM.
seed_checkout() {
  command -v git >/dev/null || skip "needs git"
  CLONE="$SANDBOX/repo"
  UPSTREAM="$SANDBOX/upstream.git"
  mkdir -p "$CLONE"
  # the working tree, not `git archive HEAD` — the point is to run the ./dot
  # that is being edited, not the one that was last committed
  cp -a "$DOTFILES_ROOT"/. "$CLONE"/
  rm -rf "$CLONE/.git"
  git -C "$CLONE" init -q -b main
  git -C "$CLONE" add -A
  git -C "$CLONE" -c user.name=t -c user.email=t@t commit -qm init
  git clone -q --bare "$CLONE" "$UPSTREAM"
  git -C "$CLONE" remote add origin "$UPSTREAM"
  git -C "$CLONE" fetch -q origin
  git -C "$CLONE" branch -q -u origin/main main
}

# One commit on the upstream: a new file under home/ (so the sync that follows
# has something to do) and a line inserted near the top of `dot`, which shifts
# every byte below it — the running interpreter is parked in that file.
push_upstream_commit() {
  local work="$SANDBOX/upstream-work"
  git clone -q "$UPSTREAM" "$work"
  printf 'newfile\n' > "$work/home/.a-new-dotfile"
  # head/tail rather than `sed -i`, whose insert syntax differs between GNU and
  # BSD; the redirection makes a fresh file, so the exec bit has to be restored
  { head -n 1 "$work/dot"
    printf '# an inserted line that shifts every byte below it\n'
    tail -n +2 "$work/dot"
  } > "$work/dot.new"
  mv "$work/dot.new" "$work/dot"
  chmod +x "$work/dot"
  git -C "$work" add -A
  git -C "$work" -c user.name=t -c user.email=t@t commit -qm "add a dotfile"
  git -C "$work" push -q origin HEAD:main
}

@test "update rejects options it does not understand" {
  run "$DOT" update --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"update takes no options"* ]]
}

@test "update fast-forwards and then syncs, across a commit that changes ./dot" {
  seed_checkout
  push_upstream_commit

  run "$CLONE/dot" update -y
  [ "$status" -eq 0 ]
  [[ "$output" == *"fast-forwarded to origin/main"* ]]

  # the follow-on sync ran: the file the new commit added is linked
  [ -L "$HOME/.a-new-dotfile" ]

  # …and the commit that rewrote ./dot mid-run left no trace in the output. See
  # the tail-of-dot test in repo.bats for what this is guarding against; the
  # symptom is a stray fragment of the new file being run as a command.
  [[ "$output" != *"command not found"* ]]
  [[ "$output" != *"syntax error"* ]]
  [[ "$output" != *"unexpected"* ]]
}

@test "update says so when there is nothing to pull" {
  seed_checkout
  run "$CLONE/dot" update -y
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date with origin/main"* ]]
}

@test "update fails on a branch with no upstream" {
  seed_checkout
  git -C "$CLONE" branch --unset-upstream

  run "$CLONE/dot" update -y
  [ "$status" -ne 0 ]
  [[ "$output" == *"no upstream"* ]]
}

@test "a dry run of update writes nothing and speaks in the conditional" {
  seed_checkout
  push_upstream_commit
  # a real fetch first, so the dry run has an up-to-date origin/main to compare
  # against — under --dry-run its own fetch is only echoed
  git -C "$CLONE" fetch -q origin

  local home_before head_before
  home_before="$(snapshot_fs "$HOME")"
  head_before="$(git -C "$CLONE" rev-parse HEAD)"

  run "$CLONE/dot" update -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"would fast-forward"* ]]
  [[ "$output" != *"fast-forwarded to"* ]]
  [ "$home_before" = "$(snapshot_fs "$HOME")" ]
  [ "$head_before" = "$(git -C "$CLONE" rev-parse HEAD)" ]
}

# --- doctor ----------------------------------------------------------------

@test "doctor reports a bare \$HOME as unhealthy but reads it correctly" {
  run "$DOT" doctor
  # a sandbox $HOME has no links, no git identity and (in a container) few tools
  [ "$status" -eq 1 ]
  [[ "$output" == *"issues found"* ]]
  [[ "$output" == *".zshrc — not linked"* ]]
  [[ "$output" == *"git identity incomplete"* ]]
}

@test "doctor stops complaining about links once they are there" {
  "$DOT" sync -y >/dev/null
  run "$DOT" doctor
  [[ "$output" != *"not linked"* ]]
  [[ "$output" != *"a real file is in the way"* ]]
}

@test "doctor writes nothing" {
  "$DOT" sync -y >/dev/null
  local before
  before="$(snapshot_fs "$HOME")"
  run "$DOT" doctor
  [ "$before" = "$(snapshot_fs "$HOME")" ]
}

# --- exit codes ------------------------------------------------------------

@test "a run with errors exits non-zero" {
  # a real file in the way that cannot be backed up is a per-file error, and
  # main turns \$LOG_ERRORS > 0 into exit 1 regardless of what the command returned
  skip_if_root
  mkfile "$HOME/.zshrc" "mine"
  mkdir -p "$HOME/.dotfiles-backup"
  chmod 500 "$HOME/.dotfiles-backup"

  run "$DOT" sync -y
  [ "$status" -eq 1 ]
  [[ "$output" == *"error(s)"* ]]

  chmod 700 "$HOME/.dotfiles-backup"
}
