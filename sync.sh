#!/usr/bin/env bash
cd "$(dirname "$0")"

do_it() {
  rsync \
    --exclude ".DS_Store" \
    --exclude ".gitconfig" \
    -av git/ system/ $HOME
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
  do_it
else
  read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    do_it
  fi
fi
unset do_it
