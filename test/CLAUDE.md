# test/

The bats suite behind `./dot test`. The root `CLAUDE.md` says *why* the suite exists and which
invariants it guards — a change to one of those is a change to its test. This file is the harness
mechanics.

- `test/helper.bash` points `$HOME`, `$XDG_STATE_HOME` and `$TMPDIR` at a temp sandbox **before**
  sourcing anything: `lib/link.sh` binds `LINK_SRC`/`LINK_MANIFEST`/`LINK_BACKUP_ROOT` at source
  time. Nothing in the suite needs root or the network, and nothing writes outside the sandbox.
- `lib/log.sh` defines `run` and `skip`, which shadow the bats builtins of the same name. Any file
  that calls `load_dotfiles` must use **`bats_run`** and `bats_skip`; `test/cli.bats` sources
  nothing and so uses plain `run`.
- bats runs test bodies under `set -e`, so a deliberately failing call needs `|| true` — otherwise
  the test aborts instead of reaching its assertion.
- `test/cli.bats` drives `./dot` as a subprocess. `dot` calls `main "$@"` at file scope and cannot
  be sourced; running the real entrypoint is the better coverage anyway, so it stays that way.
- CI and `test/Dockerfile` both provision through `test/ci-deps.sh`, so the package list has one
  home. They run the suite as an **unprivileged user** deliberately: the backup-failed and
  rm-failed paths are forced by making a directory unwritable, root ignores that, and as root those
  tests would skip and the run would go green for the wrong reason. `skip_if_root` marks them.
- `$LANG`/`$LC_ALL` are set to `C.UTF-8` in CI: shellcheck echoes the offending source line back,
  and in the images' default `C` locale the em-dashes in these comments are a hard error
  (`commitBuffer: invalid argument`), not a garbled character.
