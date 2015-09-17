#!/usr/bin/env bash
cd "$(dirname "$0")"

git pull

function doIt() {
  rsync \
    --exclude "$(basename "$0")" \
    --exclude ".git/" \
    --exclude ".DS_Store" \
    --exclude "install.sh" \
    --exclude "README.md" \
    --exclude ".gitconfig" \
    --exclude "LICENSE" \
    --exclude ".gitmodules" \
    -av . $HOME
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
  doIt
else
  read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    doIt
  fi
fi
unset doIt
