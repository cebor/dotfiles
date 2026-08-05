# CLAUDE.md

Guidance for working in this repository.

## Architecture Overview

Cross-platform (macOS + WSL2/Debian) dotfiles with a **single entrypoint**: three phases
(`sync`, `packages`, `configure`), each runnable on its own, wrapped by `install` (all three, with
the macOS bootstrap first when needed) and the read-only `doctor`. `./dot help` has the full usage.

The platform is auto-detected (`uname` via `lib/os.sh`); `--linux` forces the Linux path via the
exported `$DOTFILES_OS`.

### Key components

- `bootstrap.sh` — the one executable besides `dot`, and the only file that runs before the repo
  exists: fetched by `curl` on a bare machine, it installs `git` (apt, or the Xcode CLI tools on
  macOS), clones the repo over HTTPS and stops, pointing at `./dot install`. It therefore **cannot
  source `lib/*.sh`** — none of it is on the machine yet — so its output helpers are deliberate
  duplicates of `lib/log.sh` and must stay self-contained. Piped into bash it has the script on
  stdin, so nothing in it may prompt. Not to be confused with `setup/bootstrap.sh`, which is the
  macOS system phase *of* `install`.
- `dot` — the only entrypoint. Parses global flags, sources `lib/*.sh` once, then sources the
  needed `setup/*.sh` and calls its function. Everything under `lib/` and `setup/` is sourced,
  never executed.
  `main` owns the run summary and the exit code for every mutating command: non-zero when
  `$LOG_ERRORS > 0` or the command itself returned non-zero, warnings reported but not fatal.
  `doctor` and `help` report themselves and return early.
- `lib/os.sh` — platform detection and the predicates the rest of the repo is written in. Honors
  `$DOTFILES_OS`. `current_user` is `id -un`, not `$USER` — `su`, `sudo -i`, cron and containers
  leave `$USER` unset, and an empty user name is what turns `chsh` into a failed run.
- `lib/log.sh` — all output, plus `run`/`try`/`ok_run` for mutating commands and `confirm`/`ask`
  for prompts. Counts warnings/errors for the run summary.
- `lib/link.sh` — the symlink engine, plus the two read-only manifest queries `link_stale` and
  `link_orphans`.

### Symlink model

`home/` mirrors `$HOME` 1:1. **Files are symlinked, directories are mirrored as real directories** —
so `~/.config` and `~/.ssh` stay real dirs that other tools can write into. Only real files are
linked: `link_files` skips symlinks (`-type f`) and the `.gitignore` patterns `.DS_Store` / `*.swp`,
so a stray macOS turd in `home/` never lands in `$HOME`.

- The repo is the source of truth: editing `~/.zshrc` edits `home/.zshrc`.
- A real file in the way is moved to `~/.dotfiles-backup/<timestamp>/` before linking, with a
  warning if its content differed from the repo. If the backup fails the file is left untouched —
  `ln -f` must never be the thing that deletes the only copy.
- `_link_state` classifies before anything is touched, and its branch order is load-bearing: the
  `self` state (`$dest -ef $src`, i.e. a directory above `$dest` links into `home/`) has to be
  tested after `-L` — a correct link is `-ef` its source too — and before `-e`, which would call it
  an ordinary conflict and back up the repo's own file.
- A manifest at `~/.local/state/dotfiles/manifest` lets the next sync prune links whose source was
  renamed or deleted. Those links are invisible to `link_files`, so the manifest is the only record
  that will ever find them again: `link_stale` reads it (and `link_status`/`doctor` report what it
  finds, otherwise a leftover link would never be mentioned), and both `link_tree` and `link_unlink`
  carry entries they failed to remove into the new manifest rather than dropping them.
- `link_orphans` is the other half of that read: a manifest entry whose source is gone from `home/`
  and whose link points **outside** the current `$LINK_SRC` — what a moved repo leaves behind, and
  also what a link somebody made by hand at the same path looks like. The two are indistinguishable
  from here, so these are only ever reported and carried into the new manifest, never removed.
  Dropping them instead would lose the only record of them, which is the loss the manifest exists
  to prevent.
- Editing an already-linked file needs **no** sync. `./dot sync` is only for new/renamed/deleted files.

### Package sources

- **macOS**: `packages/Brewfile` (`brew` CLI, `cask` GUI, `mas` App Store — casks/mas are macOS-only).
- **Linux**: sources first, packages second. `setup/packages-linux.sh` adds every third-party apt
  source up front, then **one** `apt-get install` pulls the whole of `packages/apt.txt`. Only what
  apt cannot carry at all comes after: antidote (git clone `~/.antidote`) and starship (upstream
  installer).
  - Sources: **WakeMeOps** (`deb.wakemeops.com`, components `devops terminal`) for `kubectl`,
    `helm`, `yq` and `bat`; the **git PPA** (`ppa:git-core/ppa`, Ubuntu only — upstream's own
    stable build, and there is no Debian equivalent); the **helix PPA** (Ubuntu only — no Debian
    *and* no Ubuntu package named `helix` exists); **NodeSource** for `nodejs`.
  - A source whose package exists anyway only **warns** on failure and returns 0 — git and
    NodeSource, where the run still ends with a git/node, just the distro's older one. helix
    `err`s and counts as a failed step, because there the PPA is the only source there is. Both
    Ubuntu-only sources `skip` on Debian rather than warn: nothing the step could do about it,
    and warning would leave every run on such a machine with a count it can never clear.
  - Each `_apt_repo_*` is guarded by its sources file, never by `has <tool>`: WakeMeOps on the
    exact `Components:` line (so changing the component list reaches machines that already have
    the repo), NodeSource, git and helix by grepping `sources.list.d/` for the repo host (so a
    node from nvm cannot stop the repo from being added). A `has` guard would freeze them on
    whatever the machine got first. Only WakeMeOps names a file, because the line it needs is *in*
    that file; the others grep the directory, because apt takes both the old `.list` and the
    deb822 `.sources` format and upstream installers switch between them without notice — a
    filename guard stops matching the day that happens, silently re-running the installer on
    every `./dot packages`.
  - WakeMeOps sits at apt's default priority 500, unpinned. That is a deliberate choice, and
    `yq` is where it bites: Debian ships a *different* tool under that name (a python wrapper
    around jq, 3.x). Only the version comparison keeps mikefarah's 4.x in front, so `./dot doctor`
    checks which `yq` actually landed rather than assume.
  - Prerequisites (`curl`, `ca-certificates`, `gnupg`, plus `software-properties-common` on
    Ubuntu) are installed *before* the sources, because the source setup itself needs them. `git`
    is in that list for a different reason — the antidote clone in step 4 must not depend on the
    `apt.txt` batch having gone through, the same guarantee the `has curl` gate gives curl. On
    Ubuntu the batch then upgrades it to the PPA version. They all stay listed in `apt.txt` as
    well — installing them twice costs nothing, and that list has to remain the full picture.
    Between those and `bootstrap.sh`, which brings the `git` that clones the repo, the only thing
    a bare machine needs by hand is the `curl` that fetches the bootstrap; `README.md`'s
    Requirements section says exactly that and should keep saying it.
- `packages/apt.txt` is the only place Linux package names live. Line format:
  `name [@tag] [# comment]`, with the optional tag one of `@wsl`, `@!wsl` or `@ubuntu` — that is
  how `wslu` stays WSL-only, `xclip`/`wl-clipboard` non-WSL-only (the shims use
  `win32yank.exe`/`clip.exe` under WSL) and `helix` Ubuntu-only. `_apt_read_list` parses it into
  the global `$APT_PACKAGES` rather than echoing its result: in a `pkgs="$(_apt_read_list)"` the
  `warn` for an unknown tag would land in `$pkgs` as if it were a package name, and its
  `$LOG_WARNINGS` increment would die with the subshell. An unknown tag warns and drops the line —
  a typo'd tag is indistinguishable from a real one, and installing anyway would be the wrong
  guess as often as not.

## Project Conventions

### Shell scripts

- `#!/usr/bin/env bash`. `$DOTFILES_ROOT` is set once by `dot`; scripts never `cd` and never
  self-locate — they use `$DOTFILES_ROOT`.
- Each `setup/*.sh` defines **exactly one public function** (`setup_git`, `setup_vim`, …) and does
  nothing at source time. Private helpers carry a `_` prefix, as in `lib/link.sh` (`_link_state`,
  `_prune`) and `setup/packages-linux.sh` (`_apt_read_list`, `_apt_repo_*`).
- **No `set -euo pipefail`** by design — a step may soft-fail with a warning and let the run
  continue. `dot` reports the warning/error counts at the end.
- Because nothing aborts on its own, **every mutating command must be checked**: `try foo` (or
  `run foo || warn …`) for the recoverable case, `err`/`return 1` for the rest. Never print `ok` for
  something that may not have happened — a silent ✓ over a failed command is the bug this convention
  exists to prevent. A step with many small mutations snapshots `$LOG_WARNINGS` at the top and only
  prints its closing `ok` when the count is unchanged (see `setup/git.sh`,
  `setup/macos-defaults.sh`); a step with distinguishable failures keeps its own `failed` counter
  (see `setup/packages-linux.sh`).
- Use `lib/log.sh` for all output; no bare `echo`. Wrap mutating commands in `run`/`try` so
  `--dry-run` works (`run` returns the command's status, and `0` under `$DRY_RUN`). Never put a
  redirect on the `run` call itself (`run foo >/dev/null`) — that swallows the dry-run echo; put it
  inside a `run bash -c '…'` instead.
- A dry run **writes nothing at all**, not even under `$TMPDIR` (see the `/dev/null` manifest in
  `link_tree`), and it reports in the conditional: `would remove`, never `removed`. `run` is a
  no-op under `$DRY_RUN` and returns 0, so any `ok` after it has to carry the tense itself:
  `ok_run "yq installed" "would install yq"` for a single message, a local `did="would remove"`
  where a loop reuses the wording (see `_prune`, `link_unlink`). A bare `ok` after a `run` is only
  correct when it states something that was true before the run, too.
- The whole run report goes to **stdout**, `warn` and `err` included, so `./dot install | tee log`
  captures it in order. **stderr** carries only the interactive prompts — `ask` cannot share stdout
  (its stdout is the answer) and a prompt has to stay visible when stdout is piped.
- A command that aggregates steps must collect their statuses in a local `rc` (`setup_git || rc=1`)
  and `return "$rc"`. A bare sequence returns only its last command — and `if is_macos; …; fi` is
  0 on Linux — so a failed step would vanish from the exit code (see `cmd_configure`, `cmd_install`).
- Use `has foo` instead of `command -v foo >/dev/null`; `is_macos`/`is_linux`/`is_wsl`/`is_ubuntu`
  instead of ad-hoc `uname`/`/proc/version`/`/etc/os-release` checks; `current_user` instead of
  `$USER`.
- `case` for arg parsing; every command rejects options it does not understand rather than
  ignoring them.
- Prompts go through `confirm`/`ask`, which handle `$ASSUME_YES`, `$DRY_RUN` and a missing terminal
  centrally — callers never re-check those just to decide *whether* to prompt. `confirm` answers
  **no** when it cannot ask; `ask` returns empty, so callers must handle an empty answer.
  Destructive prompts are additionally gated on `[ -z "$ASSUME_YES" ]` — and only on that. A
  missing terminal and `$DRY_RUN` already answer no inside `confirm`, but `--yes` answers *yes*,
  which for "restore this backup over `$HOME`?" is the one case where the shared default is the
  wrong one (see `link_unlink`).
- An empty `ask` answer means "the user left it blank" only when we were actually allowed to ask.
  A step must not fail the run over a question it was told not to ask — `./dot install -y` on a
  fresh machine would otherwise exit 1 because the git identity is unset. Where that distinction
  matters, re-derive it once (`setup/git.sh`'s `$interactive`) and warn in both cases,
  but `return 1` only in the interactive one. `./dot doctor` is what keeps the gap visible.

### Keep sourced shell files fast

`home/.aliases` and `home/.functions` are sourced on every interactive shell start — they must
**not** source `lib/*.sh` or spawn heavy subshells. Use `[[ "$OSTYPE" == ... ]]` globs and
`command -v`.

### Dotfile organization

- `home/` — everything that maps into `$HOME`, at its real relative path.
- OS differences stay **inline** in the config files, not in per-OS overlay directories.
- Git config is applied imperatively by `setup/git.sh`; there is no static `.gitconfig`.
  `user.name`/`user.email` are prompted only when unset.
- `home/.exports` is the single source of truth for `LANG`. `setup/locale.sh` parses the value back
  out of that file rather than reading `$LANG` from the environment — the process running `./dot`
  need never have sourced it. Anything else that needs the locale should go through
  `_locale_wanted`, not hardcode a name.
- `home/.gitignore_global` contains two **literal carriage returns** after `Icon` (macOS names
  folder-icon files `Icon\r`). `.editorconfig` and `.gitattributes` both carve out an exception for
  it — do not "clean up" that line, and check with `od -c` after editing.
- Zsh plugins that only apply to one OS go in `home/.zsh_plugins.txt` with antidote's
  `conditional:<func>` annotation, with the function defined in `home/.zshrc` before `antidote load`
  (see `conditional:has_brew`). A bare `antidote bundle …` in `.zshrc` does **not** load anything —
  it prints the load script to stdout.

### Editor / style

Primary editor **helix** (`hx`); vim uses vim-plug, Solarized, persistent undo. `setup/git.sh`
points `core.editor` at `hx` only when it is actually installed and falls back to vim — on plain
Debian `./dot packages` cannot install helix, and a `core.editor` that does not exist breaks every
`git commit`.
EditorConfig: 2-space indent, LF.

## Custom Functions to Preserve

- `svenv()` — walks upward to find and activate `venv`/`.venv`, with `✓/✗` feedback.
- `scpp()` — `scp` to stkn.org, sets perms, copies URL to clipboard via `pbcopy` (shim on Linux).
- `tunnel()` — SSH port forwarding.
- `pwgen()` — `openssl rand -base64` with configurable length.
- `server()` — `python3 -m http.server` with auto-open browser via `open` (shim on Linux).
- `f()` — `find . -name "$1"`.

## Common Tasks

- **Add a package**: edit `packages/Brewfile` or `packages/apt.txt` → `./dot packages`. If it only
  applies to some Linux machines, tag the `apt.txt` line (`@wsl`, `@!wsl`, `@ubuntu`); if it needs
  an apt source that is not there yet, add an `_apt_repo_*` in `setup/packages-linux.sh` first.
- **Add an alias**: edit `home/.aliases` → `exec zsh` (already linked, no sync needed).
- **Add a new config file**: place it under `home/` at its `$HOME` path → `./dot sync`.
- **Add a zsh plugin**: edit `home/.zsh_plugins.txt` → `exec zsh`.
- **Modify a macOS setting**: edit `setup/macos-defaults.sh` → `./dot configure macos`.
- **Change the locale**: edit `LANG` in `home/.exports` → `./dot configure locale`.
- **Check the setup**: `./dot doctor`, or `./dot sync --status` for links only.

## Platform Gotchas

- `bat` comes from WakeMeOps under its real name. Only when that repo is unreachable does the name
  resolve to Debian's own package, whose binary is `batcat` (a clash with bacula's `bat`) —
  `setup/packages-linux.sh` keeps the `~/.local/bin/bat` symlink as the fallback for exactly that.
- `home/.ssh/config` uses `IgnoreUnknown UseKeychain` so the macOS-only option does not break Linux
  OpenSSH. `link_tree` chmods `~/.ssh` to 700 after linking.
- Git credentials: keychain on macOS; libsecret or a 1 h cache on Linux.
- glibc ships only `C`, `C.UTF-8` and `POSIX` precompiled, so the `LANG=en_US.UTF-8` from
  `home/.exports` names a locale that does not exist on a fresh Debian/Ubuntu — and on every WSL
  image, whose `/etc/default/locale` says `C.UTF-8`. `setlocale()` then falls back to `C`: perl
  warns on every apt run with a maintainer script, and UTF-8 ctype is silently gone. `setup/locale.sh`
  enables the line in `/etc/locale.gen` and runs `locale-gen "$lang"`; `doctor` reports the gap.
  The argument is load-bearing: a **bare** `locale-gen` first `rm -rf`s `/usr/lib/locale/*` and the
  locale-archive and rebuilds the whole file, so it would delete locales it did not create. The
  in-place edit stays anyway — `locale-gen`'s positional argument is undocumented (`locale-gen(8)`
  synopsis is `locale-gen [--keep-existing]`), and the line is what makes the locale survive the
  next bare run. The other two candidates are dead ends: `dpkg-reconfigure locales` drives a debconf
  *multiselect* that replaces the whole list, and `/var/lib/locales/supported.d/` is off-limits per
  its man page.
  It deliberately does *not* call `update-locale` — `/etc/default/locale` is the system-wide default
  for login sessions and services, and `.exports` already owns `LANG` for this user's shells.
  macOS needs none of this and the step skips there, which is also why `LANG` cannot just be set to
  `C.UTF-8` to sidestep the whole problem: BSD libc has no such locale, so the Mac would fall back
  to `C` — the worse failure, and a silent one. `en_US.UTF-8` is the portable common denominator.
- The two `locale -a` spellings differ from `LANG`'s: glibc normalizes the charset (`en_US.utf8`),
  the canonical name does not (`en_US.UTF-8`). `_locale_normalize` lowercases and drops dashes so
  the comparison works on both platforms; never compare the two strings directly.
- helix has no Debian apt package, only an Ubuntu PPA, so `./dot packages` cannot install it on
  plain Debian. `doctor` therefore reports it separately — pointing at `./dot packages` there
  would send you at something that will never fix it.
- The repo must not be moved after `sync` — links point at it by absolute path. If it moves, re-run
  `./dot sync` (stale links are detected and replaced).
