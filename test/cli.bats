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
  [[ "$output" == *"unknown option: --bogus"* ]]

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
