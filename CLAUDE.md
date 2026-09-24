# CLAUDE.md

Guidance for working in this repository.

## Architecture Overview

Cross-platform (macOS + WSL2/Ubuntu) dotfiles with a **single entrypoint**: three phases
(`sync`, `packages`, `configure`), each runnable on its own, wrapped by `install` (all three, with
the system prerequisites first, on both platforms), plus `update` (fast-forward the checkout, then
`sync`) and the read-only `doctor`. `./dot help` has the full usage.

The platform is auto-detected (`uname` via `lib/os.sh`); `--linux` forces the Linux path via the
exported `$DOTFILES_OS`.

### Key components

- `bootstrap.sh` — the one executable besides `dot` (and the scripts under `home/.local/bin/`,
  which `sync` links onto `$PATH`), and the only file that runs before the repo exists: fetched by `curl` on a bare machine, it installs `git` (apt, or the Xcode CLI tools on
  macOS), clones the repo over HTTPS and stops, pointing at `./dot install`. It therefore **cannot
  source `lib/*.sh`** — none of it is on the machine yet — so its output helpers are deliberate
  duplicates of `lib/log.sh` and must stay self-contained. Piped into bash it has the script on
  stdin, so nothing in it may prompt. Not to be confused with `setup/prereqs.sh`, which is the
  system-prerequisites phase *of* `install`.
- `setup/prereqs.sh` — what has to be in place before `packages` can run: the Xcode CLI tools and
  Homebrew on macOS, the apt packages the third-party sources need on Linux (`git curl
  ca-certificates gnupg software-properties-common`). It is the **only** step
  `install` runs before `sync`, and the only one whose failure can be fatal: on macOS `cmd_install`
  turns it into `die`, because without the CLI tools or brew every phase below is the same failure
  over again; on Linux it only sets `rc=1`, because `sync` and `configure` still have work to do.
  Deliberately no apt sources here — this step installs the tools the source step *needs*
  (`curl`, `gnupg`, `add-apt-repository`), the source step uses them, and a repo added without the
  `apt.txt` batch behind it would leave a machine with a source and none of its packages. `git` and
  `curl` come from the distro repo; the later batch upgrades git to the PPA version.
- `dot` — the only entrypoint. Parses global flags, sources `lib/*.sh` once, then sources the
  needed `setup/*.sh` and calls its function. Everything under `lib/` and `setup/` is sourced,
  never executed.
  `$DOTFILES_ROOT` resolves `$BASH_SOURCE` through **its own symlink** before taking the dirname:
  `sync` links `~/.local/bin/dot` at this file, and reached that way `$BASH_SOURCE` is
  `~/.local/bin/dot` — a real directory, which `pwd -P` canonicalises happily, leaving every
  `source` looking for `lib/` inside `~/.local/bin`. With no `set -e` that failure is silent and
  surfaces as every helper being an unknown command. The loop is hand-rolled (BSD `readlink` had
  no `-f` for most of this repo's life) and bounded, so a link pointing at itself cannot spin.
  `main` owns the run summary and the exit code for every mutating command: non-zero when
  `$LOG_ERRORS > 0` or the command itself returned non-zero, warnings reported but not fatal.
  `doctor` and `help` report themselves and return early.
  Its last line is `{ main "$@"; exit $?; }`, not a bare `main "$@"`: `./dot update` replaces this
  very file mid-run, and bash reads a script one command at a time from a file offset it would
  otherwise return to afterwards. git's rename-into-place is what keeps a bare call harmless today
  — the descriptor still points at the old inode — which is exactly why the guard is easy to drop
  by accident. The group is parsed in full before it runs and the `exit` ends the read.
  `cmd_update` is `git fetch` + `merge --ff-only` against the branch's upstream, then `cmd_sync` —
  `sync` and nothing else: it is the one phase a new commit can invalidate on its own, while
  `packages` and `configure` want sudo and the network, which is more than "update the repo" should
  imply. Uncommitted changes only **warn** — `merge --ff-only` refuses on its own if the update
  would overwrite one, so nothing can be lost, and refusing up front would block the common case of
  an edit under `home/` while the incoming commits touch `setup/`. Only `fetch` and `merge` go
  through `run`; the queries around them are read-only, like the `git config --get` calls in
  `cmd_doctor`. So a dry run compares against whatever the last real fetch left behind, and says
  so. The run finishes with the code it started with — everything was sourced before the merge — so
  a commit that changes `link_tree` takes effect on the *next* invocation.
- `lib/os.sh` — platform detection and the predicates the rest of the repo is written in. Honors
  `$DOTFILES_OS`. `current_user` is `id -un`, not `$USER` — `su`, `sudo -i`, cron and containers
  leave `$USER` unset, and an empty user name is what turns `chsh` into a failed run.
- `lib/log.sh` — all output, plus `run`/`try`/`ok_run` for mutating commands and `confirm`/`ask`
  for prompts. Counts warnings/errors for the run summary.
- `lib/link.sh` — the symlink engine, plus the two read-only manifest queries `link_stale` and
  `link_orphans`.
- `test/` — the bats suite behind `./dot test`, plus `ci-deps.sh` and a `Dockerfile` shared with
  `.gitlab-ci.yml`. See the Tests section under Project Conventions.

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
- `~/.local/bin/dot` is the one link that is **not** a mirror of `home/`: it points at
  `$DOTFILES_ROOT/dot` itself, so `dot` is on `$PATH` (`home/.exports` already prepends that
  directory, guarded on it existing — hence the `exec zsh` hint after the first sync). It is
  deliberately kept **out of the manifest**: an entry there is exactly what `link_orphans` calls
  somebody else's link — source missing from `$LINK_SRC`, target pointing outside it — and every
  sync from then on would warn about it. So it is handled by name instead, by `link_bin` /
  `link_bin_status` / `_link_bin_state`, called from `link_tree`, `link_status` and `link_unlink`.
  A real file already at that path is the one conflict this repo does **not** back up and link
  over: what sits there is somebody's own binary, not a dotfile we own. `doctor` additionally
  reports when `command -v dot` resolves somewhere else — graphviz ships a `dot` too.
- Editing an already-linked file needs **no** sync. `./dot sync` is only for new/renamed/deleted files.

### Package sources

- **macOS**: `packages/Brewfile` (`brew` CLI, `cask` GUI, `mas` App Store — casks/mas are macOS-only).
- **Linux**: sources first, packages second. `setup/packages-linux.sh` adds every third-party apt
  source up front, then **one** `apt-get install` pulls the whole of `packages/apt.txt`. Only what
  apt cannot carry at all comes after: helix (classic snap — the PPA it used to come from stopped
  at Ubuntu 24.10), antidote (git clone `~/.antidote`) and starship (upstream
  installer). The sources themselves — which repo, which guard, which failure policy — are
  documented in `setup/CLAUDE.md`, next to the code that adds them.
- `packages/apt.txt` is the only place Linux package names live. Line format:
  `name [@tag] [# comment]`, with the optional tag one of `@wsl`, `@!wsl` or `@ubuntu` — that is
  how `xclip`/`wl-clipboard` stay non-WSL-only (the shims use `win32yank.exe`/`clip.exe` under
  WSL). `@wsl` and `@ubuntu` are supported but currently carried by no line — `@wsl` last carried
  `wslu`, which Ubuntu 26.04 dropped (its `wslview` is replaced by `home/.local/bin/winopen`), and
  `@ubuntu` is there for a package a derivative might not have. `_apt_read_list` parses it into
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

`home/.exports`, `home/.aliases` and `home/.functions` are sourced on every interactive shell start
— all three, by the one loop in `home/.zshrc` — so they must **not** source `lib/*.sh` or spawn
subshells. Use `[[ "$OSTYPE" == ... ]]` globs and `command -v`; for the two probes that used to fork,
zsh answers without one: `$TTY` instead of `$(tty)`, and `"$(</proc/version)"` instead of a `grep`
pipeline (same test as `is_wsl`, which these files may not source). `test/repo.bats` asserts the
no-sourcing half, anchored at column 0 — `svenv` sourcing a venv's `activate` from inside a function
body costs a shell start nothing.

### Tests

`./dot test` runs `bash -n`, then `shellcheck -x`, then bats over `test/*.bats`, stopping at the
first stage that fails. `cmd_test` owns its exit code the way `cmd_doctor` does — a failing test is
not a failed configuration step, and bats output is not the run report.

The suite exists for the rules in this file that nothing else enforces: the branch order in
`_link_state`, "a dry run writes nothing at all", the re-quoting in `run`, `_apt_read_list` filling
a global rather than echoing, the manifest carrying forward a link it failed to remove — in
`link_tree` *and* in `link_unlink` — the stdout/stderr split, that `~/.local/bin/dot` never enters
the manifest, that `dot` still works when invoked through that link, that the last line of `dot`
is a group ending in `exit`, the two literal carriage
returns in `home/.config/git/ignore`, and that `home/.zshrc` defines `has_brew` before
`antidote load`. `README.md` repeats the list; keep the two in step.
**A change to one of those is a change to its test** — if a documented invariant is not asserted
anywhere, it is prose, which is the state this suite was written to end. New invariants come with
a test.

The harness mechanics — sandbox setup, the `run`/`skip` name clash with bats, the CI image — are
documented in `test/CLAUDE.md`, next to the suite.

### Dotfile organization

- `home/` — everything that maps into `$HOME`, at its real relative path.
- OS differences stay **inline** in the config files, not in per-OS overlay directories.
- Git config is applied imperatively by `setup/git.sh`; there is no static `.gitconfig`.
  `user.name`/`user.email` are prompted only when unset. It sets no `core.excludesfile` and no
  migration guards for the pre-XDG layout — `3a01b9b` dropped those on purpose, both machines
  being past that point. On a machine that is not, a leftover `core.excludesfile` hides
  `~/.config/git/ignore` entirely (git reads the file the setting names, not both), so it has to
  be cleared by hand.
- The global ignore file lives at `home/.config/git/ignore`, which is git's own default
  (`$XDG_CONFIG_HOME/git/ignore`) — so `core.excludesfile` is deliberately **not** set: leaving it
  unset is what makes the file take effect. The one thing this trades away is a custom
  `$XDG_CONFIG_HOME` — git would then look elsewhere while `sync` still links into `~/.config`.
  Nothing here sets that variable, and `home/.config/` already assumes the default.
- `home/.exports` is the single source of truth for `LANG`. `setup/locale.sh` parses the value back
  out of that file rather than reading `$LANG` from the environment — the process running `./dot`
  need never have sourced it. Anything else that needs the locale should go through
  `_locale_wanted`, not hardcode a name.
- `home/.config/git/ignore` contains two **literal carriage returns** after `Icon` (macOS names
  folder-icon files `Icon\r`). `.editorconfig` and `.gitattributes` both carve out an exception for
  it — do not "clean up" that line, and check with `od -c` after editing.
- Zsh plugins that only apply to one OS go in `home/.zsh_plugins.txt` with antidote's
  `conditional:<func>` annotation, with the function defined in `home/.zshrc` before `antidote load`
  (see `conditional:has_brew`). A bare `antidote bundle …` in `.zshrc` does **not** load anything —
  it prints the load script to stdout.

### Editor / style

Primary editor **helix** (`hx`); vim uses vim-plug, Solarized, persistent undo. `setup/git.sh`
points `core.editor` at `hx` only when it is actually installed and falls back to vim — the step
can run before `./dot packages` has installed helix, and a `core.editor` that does not exist breaks
every `git commit`.
EditorConfig: 2-space indent, LF.

## Custom Functions to Preserve

The functions in `home/.functions` (`svenv`, `scpp`, `tunnel`, `pwgen`, `server`, `f`, `bump`,
`dcl`) are load-bearing — do not remove them or rewrite their behavior.

## Common Tasks

- **Add a package**: edit `packages/Brewfile` or `packages/apt.txt` → `./dot packages`. If it only
  applies to some Linux machines, tag the `apt.txt` line (`@wsl`, `@!wsl`, `@ubuntu`); if it needs
  an apt source that is not there yet, add an `_apt_repo_*` in `setup/packages-linux.sh` first.
- **Add an alias**: edit `home/.aliases` → `exec zsh` (already linked, no sync needed).
- **Add a new config file**: place it under `home/` at its `$HOME` path → `./dot sync`.
- **Add a zsh plugin**: edit `home/.zsh_plugins.txt` → `exec zsh`.
- **Modify a macOS setting**: edit `setup/macos-defaults.sh` → `./dot configure macos`.
- **Change the locale**: edit `LANG` in `home/.exports` → `./dot configure locale`.
- **Update the repo**: `./dot update` (fetch, fast-forward, re-link). `./dot install` for the rest.
- **Check the setup**: `./dot doctor`, or `./dot sync --status` for links only.
- **Run the tests**: `./dot test` (syntax → shellcheck → bats, stopping at the first failure), or
  `docker build -f test/Dockerfile -t dot-test . && docker run --rm dot-test` for a CI-shaped run.
  A single file: `bats test/link.bats`.

## Platform Gotchas

- `bat` comes from WakeMeOps under its real name. Only when that repo is unreachable does the name
  resolve to the distro's own package, whose binary is `batcat` (a clash with bacula's `bat`) —
  `setup/packages-linux.sh` keeps the `~/.local/bin/bat` symlink as the fallback for exactly that.
- `home/.ssh/config` uses `IgnoreUnknown UseKeychain` so the macOS-only option does not break Linux
  OpenSSH. `link_tree` chmods `~/.ssh` to 700 after linking.
- Git credentials: keychain on macOS; libsecret or a 1 h cache on Linux.
- glibc ships only `C`, `C.UTF-8` and `POSIX` precompiled, so the `LANG=en_US.UTF-8` from
  `home/.exports` names a locale that does not exist on a fresh Ubuntu — and on every WSL
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
- The repo must not be moved after `sync` — links point at it by absolute path. If it moves, re-run
  `./dot sync` (stale links are detected and replaced).
