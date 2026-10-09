# setup/

Guidance for the phase scripts. See the root `CLAUDE.md` for the architecture and the shell-script
conventions that apply everywhere.

## Third-party apt sources (`packages-linux.sh`)

`setup/packages-linux.sh` adds every third-party apt source up front, then **one** `apt-get install`
pulls the whole of `packages/apt.txt` — helix included, as `hx`, from Ubuntu 26.04 on. Only what
apt cannot carry at all comes after: helix on older releases (classic snap), antidote (git clone
`~/.antidote`) and starship (upstream installer).

- Sources: **WakeMeOps** (`deb.wakemeops.com`, components `devops terminal`) for `kubectl`,
  `helm`, `yq` and `bat`; the **git PPA** (`ppa:git-core/ppa` — upstream's own stable build);
  **NodeSource** for `nodejs`, pinned to an explicit major (`local major` in `_apt_repo_node`) —
  `setup_current.x` would write whichever major is current that day, and the guard would keep
  every machine on it forever.
- A source whose package exists anyway only **warns** on failure and returns 0 — git and
  NodeSource, where the run still ends with a git/node, just the distro's older one. The helix
  step in section 4 `err`s and counts as a failed step, because once apt had no `hx` the snap is
  the only source there is. It also errs when snapd is installed but not running (no
  `/run/snapd.socket`) — the `snapd` package always ships `/usr/bin/snap`.
- Each `_apt_repo_*` is guarded by its sources file, never by `has <tool>`: WakeMeOps on the
  exact `Components:` line (so changing the component list reaches machines that already have
  the repo), NodeSource and git through `_apt_source_enabled`, which searches `sources.list.d/`
  — NodeSource for the URL of its major (so a bump reaches every machine), git for the PPA plus
  the current release codename from `os_codename`. A `has` guard would freeze them on whatever
  the machine got first, and a node from nvm would stop the repo from being added at all. Only
  WakeMeOps names a file, because the line it needs is *in* that file; the others search the
  directory, because apt takes both the old `.list` and the deb822 `.sources` format and
  upstream installers switch between them without notice — a filename guard stops matching the
  day that happens, silently re-running the installer on every `./dot packages`.
- A source only counts when it is **enabled**: a commented-out line or a deb822 `Enabled: no`
  does not — `do-release-upgrade` leaves third-party sources behind in exactly those two shapes,
  and a guard that took them for live would never re-add them.
- WakeMeOps sits at apt's default priority 500, unpinned. That is a deliberate choice, and
  `yq` is where it bites: the distro ships a *different* tool under that name (a python wrapper
  around jq, 3.x). Only the version comparison keeps mikefarah's 4.x in front, so `./dot doctor`
  checks which `yq` actually landed rather than assume.
- The prerequisites the sources need are installed by `setup/prereqs.sh`, one phase earlier;
  step 1 here only *checks* for them (`curl`, `gpg` and `add-apt-repository`) and
  `err`s pointing at `./dot install` — the same shape as the `has brew` check in
  `setup/packages.sh`, and the reason `./dot packages` is no longer self-sufficient on a bare
  machine. `git` is in that prereq list for a reason of its own: the antidote clone in step 4
  must not depend on the `apt.txt` batch having gone through. They all stay listed in `apt.txt`
  as well — installing them twice costs nothing, and that list has to remain the full picture.
  Between those and `bootstrap.sh`, which brings the `git` that clones the repo, the only thing
  a bare machine needs by hand is the `curl` that fetches the bootstrap; `README.md`'s
  Requirements section says exactly that and should keep saying it.
