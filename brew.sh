#!/usr/bin/env bash

brew_install () {
  if [ ! -d "$(brew --prefix "$1")" ]; then
    echo "Installing $1."
    brew install "$1"
  fi
}

cask_install () {
  echo "Installing $1."
  brew install --cask "$1"
}

if [ ! -x "$(which brew)" ]; then
  echo "Installing Homebrew."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew update
brew upgrade

while read brew; do
  brew_install "$brew"
done <brews.txt

while read cask; do
  cask_install "$cask"
done <casks.txt

brew cleanup
