#!/usr/bin/env bash
cd "$(dirname "$0")"

# fetch submodules
git submodule init
git submodule update

# sync files
./sync.sh -f
if [ ! -f $HOME/.gitconfig ]; then
  cp .gitconfig $HOME
fi

# homebrew
if test ! $(which brew)
then
  echo "Installing Homebrew."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# setup & update brew
brew doctor
brew update
brew upgrade --all
brew cleanup

# zsh
BREWZSH="/usr/local/bin/zsh"
if ! grep -Fxq "$BREWZSH" /etc/shells
then
  if [ ! -d "$(brew --prefix zsh)" ]; then
    echo "Installing ZSH."
    brew install zsh
  fi
  echo "$BREWZSH" | sudo tee -a  /etc/shells
  echo "Changing shell to ZSH."
  chsh -s "$BREWZSH"
fi
unset BREWZSH

# oh-my-zsh
if [ ! -d ~/.oh-my-zsh ]; then
  echo "Installing oh-my-zsh."
  git clone https://github.com/robbyrussell/oh-my-zsh.git $HOME/.oh-my-zsh
fi

# gnu coreutils
if [ ! -d "$(brew --prefix coreutils)" ]; then
  echo "Installing coreutils."
  brew install coreutils
fi

# gnu findutils
if [ ! -d "$(brew --prefix findutils)" ]; then
  echo "Installing findutils."
  brew install findutils
fi

# python
if [ ! -d "$(brew --prefix python)" ]; then
  echo "Installing python."
  brew install python
fi

# node
if [ ! -d "$(brew --prefix node)" ]; then
  echo "Installing node."
  brew install node
fi

# vim
if [ ! -d "$(brew --prefix vim)" ]; then
  echo "Installing vim."
  brew install vim

  # Create Directorys
  mkdir -p \
    $HOME/.vim/autoload \
    $HOME/.vim/bundle \
    $HOME/.vim/colors \
    $HOME/.vim/backups \
    $HOME/.vim/swaps \
    $HOME/.vim/undo

  # Pathogen
  curl -LSso $HOME/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

  # Add Themes
  git clone git://github.com/altercation/vim-colors-solarized.git $HOME/.vim/bundle/vim-colors-solarized
  curl -LSso $HOME/.vim/colors/badwolf.vim https://raw.githubusercontent.com/sjl/badwolf/master/colors/badwolf.vim
  curl -LSso $HOME/.vim/colors/molokai.vim https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim
fi

# git
echo "Configurating GIT ...."
if ! grep -Fq "name" $HOME/.gitconfig
then
  read -p "Username: "
  git config --global user.name "$REPLY"
fi
if ! grep -Fq "email" $HOME/.gitconfig
then
  read -p "Email: "
  git config --global user.email "$REPLY"
fi
git config --global credential.helper osxkeychain

echo "Installation & configuration finished! Please reload you shell!"
