#!/usr/bin/env bash
cd "$(dirname "$0")"

# fetch submodules
git submodule init
git submodule update

# sync files
./sync.sh -f
[ ! -f "$HOME"/.gitconfig ] && cp .gitconfig "$HOME"

# brew
if test ! "$(which brew)"
then
  echo "Installing Homebrew."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

brew prune
brew doctor
brew update
brew upgrade

brewInstall () {
  if [ ! -d "$(brew --prefix "$1")" ]; then
    echo "Installing $1."
    brew install "$1"
  fi
}

# install all the brew stuff
for brew in {coreutils,findutils,zsh,wget,curl,git,python,node,vim}; do
  brewInstall "$brew"
done

unset brew
unset brewInstall

brew cleanup

# setup zsh
BREWZSH="/usr/local/bin/zsh"
if ! grep -Fxq "$BREWZSH" /etc/shells
then
  echo "$BREWZSH" | sudo tee -a /etc/shells
  echo "Changing shell to ZSH."
  chsh -s "$BREWZSH"
fi
unset BREWZSH

# oh-my-zsh
if [ ! -d "$HOME"/.oh-my-zsh ]; then
  echo "Installing oh-my-zsh."
  git clone https://github.com/robbyrussell/oh-my-zsh.git "$HOME"/.oh-my-zsh
fi

# setup vim
if [ ! -d "$HOME"/.vim ]; then
  # create dirs
  mkdir -p \
    "$HOME"/.vim/autoload \
    "$HOME"/.vim/bundle \
    "$HOME"/.vim/colors \
    "$HOME"/.vim/backups \
    "$HOME"/.vim/swaps \
    "$HOME"/.vim/undo

  # pathogen
  curl -LSso "$HOME"/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

  # themes
  git clone git://github.com/altercation/vim-colors-solarized.git "$HOME"/.vim/bundle/vim-colors-solarized
  curl -LSso "$HOME"/.vim/colors/molokai.vim https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim

  # vim-bracketed-paste
  git clone https://github.com/ConradIrwin/vim-bracketed-paste.git "$HOME"/.vim/bundle/vim-bracketed-paste

  # typescript
  git clone https://github.com/leafgarland/typescript-vim.git "$HOME"/.vim/bundle/typescript-vim
fi

# setup git
echo "Setup Git ..."
if ! grep -Fq "name" "$HOME"/.gitconfig
then
  read -p "Username: "
  git config --global user.name "$REPLY"
fi
if ! grep -Fq "email" "$HOME"/.gitconfig
then
  read -p "Email: "
  git config --global user.email "$REPLY"
fi
git config --global credential.helper osxkeychain

echo "Installation & configuration finished! Please reload you shell!"
