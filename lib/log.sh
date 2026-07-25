#!/usr/bin/env bash

# Output helpers shared by `dot` and every setup step.
# Colors are only emitted on a TTY, so piped output stays clean.
#
# Channels: everything that is part of the run report — including warn and err —
# goes to stdout, so `./dot install | tee log` captures the whole run in order.
# stderr is reserved for the interactive prompts, which must stay on the terminal
# when stdout is piped, and which for `ask` cannot share stdout at all (its
# stdout is the answer).

if [ -t 1 ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_BLUE=$'\033[34m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_BLUE="" C_GREEN="" C_YELLOW="" C_RED=""
fi

# counters consumed by the run summary in `dot`
LOG_WARNINGS=0
LOG_ERRORS=0

section() { printf '\n%s==>%s %s%s%s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
info()    { printf '    %s\n' "$*"; }
blank()   { printf '\n'; }
ok()      { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip()    { printf '  %s·%s %s%s%s\n' "$C_DIM" "$C_RESET" "$C_DIM" "$*" "$C_RESET"; }
warn()    { LOG_WARNINGS=$((LOG_WARNINGS + 1)); printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()     { LOG_ERRORS=$((LOG_ERRORS + 1)); printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*"; }
die()     { err "$*"; exit 1; }

# Run a command, or just show it when --dry-run is active.
#
# The echo re-quotes each argument so the printed line can be pasted into a shell
# as-is. Plain "$*" collapses the argument boundaries: `credential.helper "cache
# --timeout=3600"` reads back as two arguments, and a literal ~ would be expanded
# by the pasting shell. Single quotes rather than printf %q, which escapes every
# space individually and makes the `run bash -c '…'` lines unreadable.
run() {
  if [ -n "$DRY_RUN" ]; then
    local arg shown=""
    for arg in "$@"; do
      case "$arg" in
        ""|*[!A-Za-z0-9_/.:=@%+,-]*)
          arg=${arg//\'/\'\\\'\'}   # embedded ' becomes '\'' — the usual idiom
          arg="'$arg'"
          ;;
      esac
      shown="$shown $arg"
    done
    printf '  %s$%s%s\n' "$C_DIM" "$shown" "$C_RESET"
    return 0
  fi
  "$@"
}

# `run` for the many small mutating commands whose only sensible failure
# handling is "say so and keep going" — a step that must not print a blanket ok
# afterwards snapshots $LOG_WARNINGS and compares it at the end.
try() {
  run "$@" && return 0
  warn "failed: $*"
  return 1
}

# `ok` for something a preceding `run` just did. Under --dry-run `run` only echoed
# the command and returned 0, so the message must not claim it happened: $1 is the
# wording for the real run, $2 the one for the dry run. Same rule the reports in
# lib/link.sh follow with their local `did` variables.
ok_run() {
  if [ -n "$DRY_RUN" ]; then ok "$2"; else ok "$1"; fi
}

# y/n prompt. --yes answers yes; under --dry-run or without a terminal to ask,
# the answer is the displayed default, no. Never assume yes just because nobody
# is watching. Callers therefore never re-check these to decide *whether* to
# prompt — a destructive question only re-checks $ASSUME_YES, because there the
# "yes" above is exactly the wrong answer (see link_unlink).
confirm() {
  [ -n "$ASSUME_YES" ] && return 0
  # a dry run is unattended by definition and must not act on an answer it was
  # never allowed to collect — same rule as the missing terminal below
  [ -n "$DRY_RUN" ] && return 1
  [ -t 0 ] || return 1
  local reply
  printf '  %s?%s %s [y/N] ' "$C_YELLOW" "$C_RESET" "$*" >&2
  read -r reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Prompt for a value, echoing the answer back on stdout.
# Returns empty without asking when we must not or cannot prompt: --yes and
# --dry-run are meant to run unattended, and a missing terminal would block.
# Callers must therefore handle an empty answer.
ask() {
  local prompt="$1" reply
  if [ -n "$ASSUME_YES" ] || [ -n "$DRY_RUN" ] || [ ! -t 0 ]; then
    return 0
  fi
  printf '  %s?%s %s: ' "$C_YELLOW" "$C_RESET" "$prompt" >&2
  read -r reply
  printf '%s' "$reply"
}
