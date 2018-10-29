#!/usr/bin/env bash
cd "$(dirname "$0")"

brew_install () {
  if [ ! -d "$(brew --prefix "$1")" ]; then
    echo "Installing $1."
    brew install "$1"
  fi
}

cask_install () {
  echo "Installing $1."
  brew cask install "$1"
}

# install homebrew
if [ ! -x "$(which brew)" ]; then
  echo "Installing Homebrew."
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

brew prune
brew doctor
brew update
brew upgrade

brew tap homebrew/services

# install brews
for brew in {coreutils,findutils,zsh,wget,rsync,git,python,ipython,ctags,node,mongodb,vim,antigen,yarn,httpie,gpg,tree,watch,nmap,mtr,kubernetes-cli,kubernetes-helm}; do
  brew_install "$brew"
done
unset brew_install
unset brew

brew cask doctor

# install brew casks
brew tap homebrew/cask-versions

for cask in {google-chrome,iterm2,visual-studio-code,docker-edge,github,vlc,spotify,skype,teamspeak-client}; do
  cask_install "$cask"
done
unset cask_install
unset cask

brew cleanup
