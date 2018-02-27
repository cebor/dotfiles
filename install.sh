#!/usr/bin/env bash
cd "$(dirname "$0")"

xcode-select --install

# sync files
./sync.sh -f
[ ! -f "$HOME"/.gitconfig ] && cp git/.gitconfig "$HOME"

# osx settings
./osx.sh

# homebrew
./brew.sh

# setup zsh
BREWED_ZSH="/usr/local/bin/zsh"
if ! grep -Fxq "$BREWED_ZSH" /etc/shells; then
  echo "$BREWED_ZSH" | sudo tee -a /etc/shells
  echo "Changing shell to ZSH."
  sudo chsh -s "$BREWED_ZSH" "$USER"
fi
unset BREWED_ZSH

# setup vim
./vim.sh

# python stuff
pip3 install --upgrade virtualenv
pip3 install --upgrade virtualenvwrapper
pip3 install --upgrade ipython

# angular-cli
yarn global add @angular/cli
ng set --global packageManager=yarn
ng completion --zsh >> "$HOME"/.completions

# rvm
gpg --keyserver hkp://keys.gnupg.net --recv-keys \
  409B6B1796C275462A1703113804BB82D39DC0E3 \
  7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable --ruby --gems=rails,jekyll --ignore-dotfiles

# setup git
echo "Setup Git ..."
if ! grep -Fq "name" "$HOME"/.gitconfig; then
  read -p "Username: "
  git config --global user.name "$REPLY"
fi
if ! grep -Fq "email" "$HOME"/.gitconfig; then
  read -p "Email: "
  git config --global user.email "$REPLY"
fi
git config --global credential.helper osxkeychain

echo "Installation & configuration finished! Please reload your shell!"
