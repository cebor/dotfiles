#!/usr/bin/env bash

if [ ! -x "$(which brew)" ]; then
  echo "Installing Homebrew."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew update
brew upgrade
brew bundle
brew cleanup
