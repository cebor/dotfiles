#!/usr/bin/env bats
#
# lib/log.sh — the output helpers every other step reports through.
#
# Two things here are load-bearing beyond "it prints something": the re-quoting
# in `run` (CLAUDE.md: the dry-run line has to be pasteable, so argument
# boundaries and a literal ~ must survive), and the channel split (the whole run
# report on stdout so `./dot install | tee log` keeps its order, prompts on
# stderr so they stay visible when stdout is piped).

load helper

setup() {
  setup_sandbox
  load_dotfiles
}

teardown() { teardown_sandbox; }

# --- run: the dry-run echo -------------------------------------------------

@test "run under --dry-run keeps argument boundaries intact" {
  DRY_RUN=1
  bats_run run git config --global credential.helper "cache --timeout=3600"
  [ "$status" -eq 0 ]
  # the value stays ONE argument; plain "$*" would flatten it into two
  [ "$output" = "  \$ git config --global credential.helper 'cache --timeout=3600'" ]
}

@test "run under --dry-run quotes a literal tilde" {
  DRY_RUN=1
  bats_run run ln -s /src "~/dest"
  # unquoted, the shell you paste this into would expand ~ to its own \$HOME
  [ "$output" = "  \$ ln -s /src '~/dest'" ]
}

@test "run under --dry-run escapes an embedded single quote" {
  DRY_RUN=1
  bats_run run echo "it's here"
  [ "$output" = "  \$ echo 'it'\\''s here'" ]
}

@test "run under --dry-run shows an empty argument as ''" {
  DRY_RUN=1
  bats_run run git config user.name ""
  [ "$output" = "  \$ git config user.name ''" ]
}

@test "run under --dry-run leaves safe arguments unquoted" {
  DRY_RUN=1
  bats_run run apt-get install -y --no-install-recommends ca-certificates
  [ "$output" = "  \$ apt-get install -y --no-install-recommends ca-certificates" ]
}

@test "run under --dry-run executes nothing and still returns 0" {
  DRY_RUN=1
  bats_run run touch "$SANDBOX/marker"
  [ "$status" -eq 0 ]
  [ ! -e "$SANDBOX/marker" ]

  bats_run run false
  [ "$status" -eq 0 ]
}

@test "run without --dry-run executes and reports the real status" {
  bats_run run touch "$SANDBOX/marker"
  [ "$status" -eq 0 ]
  [ -e "$SANDBOX/marker" ]

  bats_run run false
  [ "$status" -eq 1 ]
}

# --- counters --------------------------------------------------------------

@test "warn and err count, the quiet helpers do not" {
  ok "fine"; skip "skipped"; info "note"; section "heading"; blank
  [ "$LOG_WARNINGS" -eq 0 ]
  [ "$LOG_ERRORS" -eq 0 ]

  warn "careful"
  err "broken"
  err "also broken"
  [ "$LOG_WARNINGS" -eq 1 ]
  [ "$LOG_ERRORS" -eq 2 ]
}

@test "try warns and fails when the command fails" {
  bats_run try false
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed: false"* ]]

  # the counter lives in this shell, not in the one bats_run forked
  try false || true
  [ "$LOG_WARNINGS" -eq 1 ]

  try true
  [ "$LOG_WARNINGS" -eq 1 ]
}

# --- tense -----------------------------------------------------------------

@test "ok_run picks the tense from --dry-run" {
  bats_run ok_run "yq installed" "would install yq"
  [[ "$output" == *"yq installed"* ]]

  DRY_RUN=1
  bats_run ok_run "yq installed" "would install yq"
  [[ "$output" == *"would install yq"* ]]
  [[ "$output" != *"yq installed"* ]]
}

# --- prompts ---------------------------------------------------------------

@test "confirm answers yes only for --yes" {
  ASSUME_YES=1
  bats_run confirm "go ahead?"
  [ "$status" -eq 0 ]
}

@test "confirm answers no under --dry-run and without a terminal" {
  DRY_RUN=1
  bats_run confirm "go ahead?"
  [ "$status" -ne 0 ]

  # neither flag set, and bats gives the test no terminal on stdin
  DRY_RUN=""
  bats_run confirm "go ahead?"
  [ "$status" -ne 0 ]
}

@test "ask returns empty when it must not or cannot prompt" {
  ASSUME_YES=1
  bats_run ask "Your name"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  ASSUME_YES=""
  DRY_RUN=1
  bats_run ask "Your name"
  [ -z "$output" ]

  DRY_RUN=""
  bats_run ask "Your name"
  [ -z "$output" ]
}

# --- channels --------------------------------------------------------------

@test "the run report goes to stdout, warn and err included" {
  local out
  out="$( { warn "careful"; err "broken"; ok "fine"; } 2>/dev/null )"
  [[ "$out" == *"careful"* ]]
  [[ "$out" == *"broken"* ]]
  [[ "$out" == *"fine"* ]]
}

@test "the report helpers put nothing on stderr" {
  local errout
  errout="$( { ok "fine"; warn "careful"; err "broken"; info "note"; } 2>&1 >/dev/null )"
  [ -z "$errout" ]
}

@test "at a terminal, ask prints the prompt on stderr and only the answer on stdout" {
  with_tty 'Felix
' "source $DOTFILES_ROOT/lib/log.sh; ask Name >$SANDBOX/out 2>$SANDBOX/err"

  # stdout is the answer and nothing else — a prompt sharing it would corrupt
  # every `name=\"\$(ask …)\"` in setup/git.sh
  [ "$(cat "$SANDBOX/out")" = "Felix" ]
  grep -q "Name" "$SANDBOX/err"
}

@test "at a terminal, confirm reads the answer and prompts on stderr" {
  with_tty 'y
' "source $DOTFILES_ROOT/lib/log.sh; confirm Proceed >$SANDBOX/out 2>$SANDBOX/err && echo YES >>$SANDBOX/out || echo NO >>$SANDBOX/out"
  grep -q "Proceed" "$SANDBOX/err"
  grep -qx "YES" "$SANDBOX/out"

  with_tty 'n
' "source $DOTFILES_ROOT/lib/log.sh; confirm Proceed >$SANDBOX/out 2>$SANDBOX/err && echo YES >>$SANDBOX/out || echo NO >>$SANDBOX/out"
  grep -qx "NO" "$SANDBOX/out"

  # anything that is not y/yes is a no — the default the prompt advertises
  with_tty '
' "source $DOTFILES_ROOT/lib/log.sh; confirm Proceed >$SANDBOX/out 2>$SANDBOX/err && echo YES >>$SANDBOX/out || echo NO >>$SANDBOX/out"
  grep -qx "NO" "$SANDBOX/out"
}
