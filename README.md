# dotfiles

Personal dotfiles for **macOS** and **WSL2 (Debian/Ubuntu)**. One entrypoint, symlinked configs,
the same command on both platforms.

The platform is detected at runtime, so `./dot install` does the right thing on either machine.
Configs are **symlinked** out of this repo into `$HOME`, which means editing `~/.zshrc` edits the
repo — no copy step to forget, and `git status` shows exactly what drifted.

## Quick start

```sh
git clone git@github.com:cebor/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./dot install
exec zsh
```

`./dot install` is idempotent — it is also the regular update command.

> The repo has to stay where you cloned it: the symlinks point back at it by absolute path.

## Commands

| Command | What it does |
| --- | --- |
| `./dot install` | Everything: bootstrap → sync → packages → configure |
| `./dot sync` | Symlink `home/` into `$HOME` — dotfiles and configs only |
| `./dot packages` | Install packages: `Brewfile` on macOS, apt sources + `apt.txt` on Linux |
| `./dot configure` | Apply configuration: git, login shell, vim, macOS defaults |
| `./dot doctor` | Health check: links, tools, login shell, git identity |
| `./dot help` | Usage summary |

| Option | Effect |
| --- | --- |
| `-n`, `--dry-run` | Print what would happen; change nothing |
| `-y`, `--yes` | Never prompt — questions keep their default (hostname unchanged, git identity left unset with a warning). Destructive prompts are skipped, not auto-confirmed |
| `--linux` | Force the Linux path regardless of detection |
| `--status` | `sync` only: report link state, write nothing |
| `--unlink` | `sync` only: remove the symlinks again |

`configure` also takes a single step: `./dot configure git|shell|vim|macos`.

## How it works

Three phases, each runnable on its own:

1. **sync** — every file under `home/` is symlinked to the same relative path in `$HOME`.
   Files are linked, directories are mirrored as real directories, so `~/.config` and `~/.ssh`
   stay yours and other tools can keep writing into them.
2. **packages** — `brew bundle` against `packages/Brewfile` on macOS; on Linux the apt sources
   ([WakeMeOps](https://docs.wakemeops.com/), the helix PPA, NodeSource) first, then everything in
   `packages/apt.txt` in one go, then antidote and starship, which apt cannot provide.
3. **configure** — imperative settings that are not files: `git config --global`, the login shell,
   vim-plug, and `defaults write` on macOS.

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
├── dot                    # the only entrypoint
├── home/                  # mirrored 1:1 into $HOME
│   ├── .zshrc             #   sources .exports/.aliases/.functions, then antidote + starship
│   ├── .exports           #   environment variables
│   ├── .aliases           #   command shortcuts
│   ├── .functions         #   shell functions + cross-platform pbcopy/pbpaste/open shims
│   ├── .zsh_plugins.txt   #   antidote plugin list
│   ├── .vimrc .tmux.conf .latexmkrc .gitignore_global
│   ├── .ssh/config
│   └── .config/           #   helix, pycodestyle
├── lib/                   # sourced helpers, never executed
│   ├── os.sh              #   platform detection, `has`, brew shellenv, arch mapping
│   ├── log.sh             #   section/info/ok/warn/err, prompts, dry-run `run`
│   └── link.sh            #   symlink engine: link, backup, prune, status
├── setup/                 # one file per step, one function each
│   ├── bootstrap.sh       #   macOS: Xcode CLI tools + Homebrew
│   ├── packages.sh        #   dispatches to brew bundle or packages-linux.sh
│   ├── packages-linux.sh  #   apt sources, then the apt list, then the rest
│   ├── git.sh shell.sh vim.sh
│   └── macos-defaults.sh  #   defaults write / scutil
└── packages/
    ├── Brewfile           #   brew, cask, mas
    └── apt.txt            #   apt list: name [@tag] [# comment]
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
| Packages | `packages/Brewfile` (brew, cask, mas) | `packages/apt.txt` (+ WakeMeOps, helix PPA, NodeSource) |
| Bootstrap | Xcode CLI tools + Homebrew | none needed |
| Git credentials | `osxkeychain` | libsecret, else 1 h cache |
| Clipboard | native `pbcopy`/`pbpaste` | shims in `home/.functions` |
| Browser | native `open` | `wslview` (WSL) / `xdg-open` |
| `bat` | `bat` | `bat` from WakeMeOps; Debian's own ships as `batcat`, symlinked to `~/.local/bin/bat` |
| SSH `UseKeychain` | honoured | ignored via `IgnoreUnknown` |
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

macOS or Debian/Ubuntu (incl. WSL2), `git`, `curl`, and `sudo` rights for package installation.
Everything else is installed by `./dot install`.

## License

MIT — see [LICENSE](LICENSE).
