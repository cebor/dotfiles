#!/usr/bin/env bash
cd "$(dirname "$0")"

xcode-select --install

# sync files
./sync.sh -f
[ ! -f "$HOME"/.gitconfig ] && cp git/.gitconfig "$HOME"

# macos settings
./macos.sh

# homebrew
./brew.sh

# setup zsh
echo "Changing shell to brewed ZSH."
sudo chsh -s "$(brew --prefix)/bin/zsh" "$USER"

# setup vim
./vim.sh

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
