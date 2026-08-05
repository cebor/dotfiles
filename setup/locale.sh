#!/usr/bin/env bash

# Generate the locale home/.exports asks for. Linux only.
#
# macOS ships every locale precompiled; glibc does not. A fresh Debian/Ubuntu —
# and every WSL image — carries only C, C.UTF-8 and POSIX, so the LANG in
# home/.exports names a locale that does not exist. setlocale() then falls back
# to C, which is how you get `perl: warning: Setting locale failed` on every apt
# run that touches a Perl maintainer script, and, quietly, no UTF-8 ctype:
# umlauts in filenames, `[[:alpha:]]`, `wc -m` and every TUI's box-drawing
# characters all go wrong.
#
# Only the locale is generated, deliberately not `update-locale`: /etc/default/locale
# is the system-wide default for login sessions and services, and home/.exports
# already owns LANG for this user's shells. Generating what LANG names is the whole
# fix; overwriting the machine's default would be a second, unasked-for change.

# `locale -a` prints the charset in glibc's normalized form (`en_US.utf8`), LANG
# carries the canonical one (`en_US.UTF-8`). Lowercase and drop the dashes and the
# two spellings meet.
_locale_normalize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '-'; }

_locale_available() {
  locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '-' |
    grep -qxF "$(_locale_normalize "$1")"
}

# The LANG home/.exports exports, which is the value the shells will actually run
# with — the repo is the source of truth, so this must not read $LANG from the
# current environment. Last assignment wins, the same way the shell would resolve it.
_locale_wanted() {
  sed -n 's/^[[:space:]]*export[[:space:]]\{1,\}LANG=["'\'']\{0,1\}\([^"'\''[:space:]#]*\).*/\1/p' \
    "$DOTFILES_ROOT/home/.exports" 2>/dev/null | tail -n 1
}

setup_locale() {
  section "Configuring locale"

  if ! is_linux; then
    skip "locale (macOS ships every locale precompiled)"
    return 0
  fi

  local lang
  lang="$(_locale_wanted)"
  if [ -z "$lang" ]; then
    skip "locale (home/.exports sets no LANG)"
    return 0
  fi

  # Nothing to do for a locale glibc has built in (C.UTF-8) or that a previous run
  # already generated. Checked before /etc/locale.gen so a machine that never needs
  # the `locales` package is never asked for one.
  if _locale_available "$lang"; then
    skip "$lang already available"
    return 0
  fi

  # The charset half of the /etc/locale.gen line: `en_US.UTF-8` -> `UTF-8`.
  local charset="${lang#*.}"
  if [ "$charset" = "$lang" ]; then
    warn "LANG=$lang names no charset — cannot write a /etc/locale.gen line for it"
    return 1
  fi

  # `has locale-gen` alone is not the right question: the binary lives in
  # /usr/sbin, which Ubuntu puts on a normal user's PATH and Debian does not — and
  # it is invoked through `sudo` below, whose secure_path carries /usr/sbin on
  # both. So on Debian `has` would call it missing and fail a step that would have
  # worked, which is exactly what `./dot install` did there.
  local gen="/etc/locale.gen"
  if [ ! -f "$gen" ] || { ! has locale-gen && [ ! -x /usr/sbin/locale-gen ]; }; then
    # Under --dry-run the packages phase would have installed `locales` before this
    # step ever ran, so its absence here is an artefact of the forecast, not a
    # finding. Same guard as in setup/shell.sh and setup/vim.sh.
    if [ -n "$DRY_RUN" ]; then
      info "the locales package is not installed yet — ./dot packages installs it before this step"
      ok "would generate $lang once it is there"
      return 0
    fi
    err "no $gen / locale-gen — install the locales package (it is in packages/apt.txt)"
    return 1
  fi

  # Escape the regex metacharacters in the locale name — `en_US.UTF-8` carries a
  # `.`, which would otherwise match `en_USxUTF-8` too.
  local escaped
  escaped="$(printf '%s' "$lang" | sed 's/[].[^$*\/]/\\&/g')"

  # Enable the line in /etc/locale.gen before generating. Edited in place rather
  # than through a tool, because for "enable one locale, non-interactively" there
  # is none:
  #
  #   - `locale-gen <locale>` does add the line itself (its add_to_locale_gen), but
  #     locale-gen(8) documents the synopsis as `locale-gen [--keep-existing]` — the
  #     positional argument is undocumented, so it is fine to *use* (below) and not
  #     something to *depend* on for the enabling half.
  #   - `dpkg-reconfigure locales` is the documented way and is interactive. Driving
  #     it from debconf works, but locales/locales_to_be_generated is a multiselect:
  #     the preseeded value replaces the whole list, so enabling one locale disables
  #     and deletes every other. Wrong tool for an additive change.
  #   - /var/lib/locales/supported.d/ is the drop-in directory locale-gen also reads,
  #     which would be ideal — except locale-gen(8) says "Do not edit these manually,
  #     they will be overwritten on package upgrades". It belongs to language-pack
  #     packages.
  #
  # So: locale.gen it is, in the format locale.gen(5) specifies. It is not a dpkg
  # conffile (debconf generates it), and editing it is what the man page means by
  # "after selecting the locales into /etc/locale.gen".
  #
  # Doing it here rather than leaving it to `locale-gen <locale>` also buys the two
  # things the argument alone does not guarantee: that the locale survives the next
  # bare `locale-gen` (a glibc upgrade, `dpkg-reconfigure locales`), and a locale-gen
  # whose argument handling differs. One that ignores its argument regenerates from
  # locale.gen and would otherwise find every line commented out — and then generate
  # nothing, quietly, with status 0.
  #
  # Three states, and only the middle one is the common case. Already enabled means
  # the line is there but locale-gen never ran over it; absent entirely is what a
  # locale outside the shipped list looks like.
  if grep -qE "^[[:space:]]*${escaped}([[:space:]]|$)" "$gen"; then
    skip "$lang already enabled in $gen"
  elif grep -qE "^[[:space:]]*#[[:space:]]*${escaped}[[:space:]]" "$gen"; then
    if ! run sudo sed -i -E "s/^[[:space:]]*#[[:space:]]*(${escaped}[[:space:]].*)/\1/" "$gen"; then
      err "could not enable $lang in $gen"
      return 1
    fi
    ok_run "enabled $lang in $gen" "would enable $lang in $gen"
  else
    if ! run bash -c "printf '%s %s\n' '$lang' '$charset' | sudo tee -a '$gen' >/dev/null"; then
      err "could not add $lang to $gen"
      return 1
    fi
    ok_run "added '$lang $charset' to $gen" "would add '$lang $charset' to $gen"
  fi

  # With the locale as an argument, not bare. A bare `locale-gen` first `rm -rf`s
  # /usr/lib/locale/* and the locale-archive and then rebuilds everything listed in
  # locale.gen — so it would throw away locales that were generated by hand or by
  # another package, to regenerate one. Given an argument it skips that purge
  # entirely (`if [ -z "$1" ] && [ "$KEEP" -eq 0 ]` in the script) and compiles just
  # this one.
  info "Generating $lang..."
  if ! run sudo locale-gen "$lang"; then
    err "locale-gen failed — $lang is still unavailable"
    return 1
  fi

  # `run` is a no-op under --dry-run, so there is nothing to verify there and the
  # message has to stay in the conditional.
  if [ -n "$DRY_RUN" ]; then
    ok "would generate $lang"
    return 0
  fi
  # Not a blanket ok after the run. locale-gen does reject an unsupported name with
  # status 1, but it runs `localedef … || :` per entry, so a locale that fails to
  # compile still leaves it exiting 0 — as does a version that ignored the argument
  # and found nothing to do. A ✓ over a locale that is still not there is exactly
  # the silent success this repo's conventions exist to prevent.
  if ! _locale_available "$lang"; then
    err "locale-gen ran but $lang is still not in \`locale -a\`"
    return 1
  fi
  ok "$lang generated"
}
