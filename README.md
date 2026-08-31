# dotfiles

Personal dotfiles for **macOS** and **WSL2 (Debian/Ubuntu)**. One entrypoint, symlinked configs,
the same command on both platforms.

The platform is detected at runtime, so `./dot install` does the right thing on either machine.
Configs are **symlinked** out of this repo into `$HOME`, which means editing `~/.zshrc` edits the
repo — no copy step to forget, and `git status` shows exactly what drifted.

## Quick start

On a fresh machine, where not even `git` is installed:

```sh
curl -fsSL https://gitlab.stkn.org/felix/dotfiles/-/raw/main/bootstrap.sh | bash
```

That installs `git` (apt on Linux, Xcode CLI tools on macOS), clones the repo to `~/code/dotfiles`
and stops — nothing else is touched. Then:

```sh
cd ~/code/dotfiles
./dot install
exec zsh
```

With `git` and an SSH key already in place, clone it yourself instead and skip the bootstrap:

```sh
git clone git@github.com:cebor/dotfiles.git ~/code/dotfiles
```

`./dot install` is idempotent — it is also the regular update command.

> The repo has to stay where you cloned it: the symlinks point back at it by absolute path.

## Commands

| Command | What it does |
| --- | --- |
| `./dot install` | Everything: prerequisites → sync → packages → configure |
| `./dot sync` | Symlink `home/` into `$HOME` — dotfiles and configs only |
| `./dot packages` | Install packages: `Brewfile` on macOS, apt sources + `apt.txt` on Linux |
| `./dot configure` | Apply configuration: locale, git, login shell, vim, macOS defaults |
| `./dot doctor` | Health check: links, tools, login shell, locale, git identity |
| `./dot test` | Syntax check, shellcheck and the bats suite under `test/` |
| `./dot help` | Usage summary |

| Option | Effect |
| --- | --- |
| `-n`, `--dry-run` | Print what would happen; change nothing |
| `-y`, `--yes` | Never prompt — questions keep their default (hostname unchanged, git identity left unset with a warning). Destructive prompts are skipped, not auto-confirmed |
| `--linux` | Force the Linux path regardless of detection |
| `--status` | `sync` only: report link state, write nothing |
| `--unlink` | `sync` only: remove the symlinks again |

`configure` also takes a single step: `./dot configure locale|git|shell|vim|macos`.

## How it works

Three phases, each runnable on its own:

1. **sync** — every file under `home/` is symlinked to the same relative path in `$HOME`.
   Files are linked, directories are mirrored as real directories, so `~/.config` and `~/.ssh`
   stay yours and other tools can keep writing into them.
2. **packages** — `brew bundle` against `packages/Brewfile` on macOS; on Linux the apt sources
   ([WakeMeOps](https://docs.wakemeops.com/), the git and helix PPAs, NodeSource) first, then everything in
   `packages/apt.txt` in one go, then antidote and starship, which apt cannot provide.
3. **configure** — imperative settings that are not files: the locale, `git config --global`, the
   login shell, vim-plug, and `defaults write` on macOS.

**The repo is the source of truth.** `~/.zshrc` is a link into `home/.zshrc`, so:

```sh
hx ~/.zshrc            # really edits ~/code/dotfiles/home/.zshrc
cd ~/code/dotfiles && git diff
```

Nothing is ever overwritten silently. When `sync` finds a real file where a link should go, it moves
it to `~/.dotfiles-backup/<timestamp>/` first and tells you if the content differed — and if that
backup cannot be written, the file is left alone instead of being linked over. Files removed or
renamed inside `home/` have their stale links cleaned up on the next `sync`, tracked through a
manifest at `~/.local/state/dotfiles/manifest`.

## Project structure

```
.
├── bootstrap.sh           # curl-able: installs git and clones this repo, nothing more
├── dot                    # the only entrypoint
├── home/                  # mirrored 1:1 into $HOME
│   ├── .zshrc             #   sources .exports/.aliases/.functions, then antidote + starship
│   ├── .exports           #   environment variables
│   ├── .aliases           #   command shortcuts
│   ├── .functions         #   shell functions + cross-platform pbcopy/pbpaste/open shims
│   ├── .zsh_plugins.txt   #   antidote plugin list
│   ├── .vimrc .tmux.conf .latexmkrc
│   ├── .ssh/config
│   └── .config/           #   git/ignore (the global gitignore), helix, pycodestyle
├── lib/                   # sourced helpers, never executed
│   ├── os.sh              #   platform detection, `has`, brew shellenv, arch mapping
│   ├── log.sh             #   section/info/ok/warn/err, prompts, dry-run `run`
│   └── link.sh            #   symlink engine: link, backup, prune, status
├── setup/                 # one file per step, one function each
│   ├── prereqs.sh         #   Xcode CLI tools + Homebrew / the apt prerequisites
│   ├── packages.sh        #   dispatches to brew bundle or packages-linux.sh
│   ├── packages-linux.sh  #   apt sources, then the apt list, then the rest
│   ├── locale.sh          #   generate the LANG from home/.exports (Linux)
│   ├── git.sh shell.sh vim.sh
│   └── macos-defaults.sh  #   defaults write / scutil
├── packages/
│   ├── Brewfile           #   brew, cask, mas
│   └── apt.txt            #   apt list: name [@tag] [# comment]
└── test/                  # bats suite, run by ./dot test
    ├── helper.bash        #   sandbox $HOME, command stubs, filesystem snapshots
    ├── *.bats             #   one file per unit under test, plus cli.bats end to end
    ├── ci-deps.sh         #   what a bare image needs; used by CI and the Dockerfile
    └── Dockerfile         #   reproduce a CI job locally
```

## What's included

**Shell** — zsh with [antidote](https://github.com/mattmc3/antidote) for plugins and
[starship](https://starship.rs) for the prompt. Plugins: oh-my-zsh `lib`/`git`/`extract`,
`rupa/z`, plus zsh-completions, zsh-autosuggestions and zsh-syntax-highlighting.

**Editors** — [helix](https://helix-editor.com) (`hx`) is the primary editor and git's `core.editor`;
vim is configured with vim-plug, Solarized and persistent undo.

**Custom functions** (`home/.functions`):

```sh
svenv                    # walk upward, find and activate venv/.venv
scpp report.pdf          # scp to stkn.org, fix perms, copy the URL to the clipboard
server                   # python3 -m http.server + open the browser
tunnel host 3306 3307    # ssh forwarding: host's port 3306 -> localhost:3307
pwgen 32                 # openssl rand -base64
f '*.conf'               # find . -name
```

On Linux, `pbcopy`, `pbpaste` and `open` are defined as shims (win32yank / clip.exe / wl-copy /
xclip, and wslview / xdg-open) so the same functions work in WSL.

## Platform differences

| | macOS | Linux / WSL2 |
| --- | --- | --- |
| Packages | `packages/Brewfile` (brew, cask, mas) | `packages/apt.txt` (+ WakeMeOps, git PPA, helix PPA, NodeSource) |
| Prerequisites | Xcode CLI tools + Homebrew | apt: `git`, `curl`, `ca-certificates`, `gnupg` (+ `software-properties-common` on Ubuntu) |
| Git credentials | `osxkeychain` | libsecret, else 1 h cache |
| Clipboard | native `pbcopy`/`pbpaste` | shims in `home/.functions` |
| Browser | native `open` | `wslview` (WSL) / `xdg-open` |
| `bat` | `bat` | `bat` from WakeMeOps; Debian's own ships as `batcat`, symlinked to `~/.local/bin/bat` |
| SSH `UseKeychain` | honoured | ignored via `IgnoreUnknown` |
| Locale | every locale ships precompiled | `LANG` from `home/.exports` generated by `setup/locale.sh` |
| System settings | `setup/macos-defaults.sh` | n/a |

OS differences inside config files are handled inline (`[[ "$OSTYPE" == darwin* ]]`), so every
config exists exactly once.

## Customization

| Task | Steps |
| --- | --- |
| Add an alias | edit `home/.aliases` → `exec zsh` (it is already linked) |
| Add a config file | put it at its `$HOME` path under `home/` → `./dot sync` |
| Add a package | edit `packages/Brewfile` or `packages/apt.txt` → `./dot packages` |
| Add a zsh plugin | edit `home/.zsh_plugins.txt` → `exec zsh` |
| Change a macOS setting | edit `setup/macos-defaults.sh` → `./dot configure macos` |
| Change the locale | edit `LANG` in `home/.exports` → `./dot configure locale` |

Editing anything already linked needs no sync — `./dot sync` is only for **new**, renamed or
deleted files.

## Maintenance

```sh
./dot doctor           # is anything missing or unlinked?
./dot sync --status    # link state only, no writes
./dot sync --unlink    # remove all links, then offer to restore the newest backup
./dot install -n       # dry run the whole thing
```

Backups of replaced files live in `~/.dotfiles-backup/<timestamp>/` and are never deleted
automatically.

Coming from the older rsync-based layout, `$HOME` still holds real copies rather than links — the
first `./dot sync` backs each one up before linking. One leftover it cannot clean up is
`~/.gitattributes_global`: the file is gone from the repo and `./dot configure git` drops the
matching `core.attributesfile` setting, but the empty file in `$HOME` is yours to delete.

## Requirements

macOS or Debian/Ubuntu (incl. WSL2), `curl` to fetch the bootstrap, and `sudo` rights for package
installation. Nothing else has to be installed by hand: `bootstrap.sh` brings the `git` that clones
the repo, and `curl`, `gnupg` and the rest are prerequisites `./dot install` installs for itself, in
its own first phase, before it adds the apt sources that need them.

That first phase is why `./dot packages` on its own expects an already-provisioned machine: it
checks for what it needs and points at `./dot install` rather than installing it.

On a Mac without the Xcode CLI tools the bootstrap starts their installer and stops — finish it,
then run the same command again.

## Development

```sh
./dot test
```

runs three stages and stops at the first that fails: `bash -n` over every script, `shellcheck -x`,
then the [bats](https://github.com/bats-core/bats-core) suite in `test/`. Neither shellcheck nor
bats is needed to *use* these dotfiles — install them with `brew install shellcheck bats-core` or
`apt-get install shellcheck bats`. A missing shellcheck is reported and skipped; a missing bats
fails, because then nothing was tested.

The suite never touches your real home directory: `test/helper.bash` points `$HOME`,
`$XDG_STATE_HOME` and `$TMPDIR` at a temp sandbox before anything is sourced, and stubs any command
that would reach the system. It needs no root and no network.

To run it the way CI does, on either target distribution:

```sh
docker build -f test/Dockerfile -t dot-test .                              # debian:trixie
docker build --build-arg BASE=ubuntu:24.04 -f test/Dockerfile -t dot-test .
docker run --rm dot-test
```

Both distributions are worth running — `is_ubuntu` switches real branches in `packages/apt.txt` and
`setup/packages-linux.sh`. The container runs the suite as an unprivileged user on purpose: several
failure paths in `lib/link.sh` are forced by making a directory unwritable, and root ignores that,
so as root they would skip and the run would go green for the wrong reason.

`.gitlab-ci.yml` runs the same `./dot test` across both images and expects a runner with the docker
executor.

What the tests are for is less "does bash work" than pinning the decisions this repo documents but
cannot otherwise enforce: the branch order in `_link_state`, that a dry run writes nothing at all,
the argument re-quoting in `run`, the manifest carrying forward a link it failed to remove, and the
two literal carriage returns in `home/.config/git/ignore`. Changing one of those on purpose means
changing its test; having one break by accident is the point.

## License

MIT — see [LICENSE](LICENSE).
