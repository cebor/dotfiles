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
echo "Changing shell to ZSH."
sudo chsh -s /usr/local/bin/zsh "$USER"
# fix compaudit for zsh autocompletes
chmod go-w /usr/local/share/zsh
chmod go-w /usr/local/share/zsh/site-functions

# setup astrovim (nvim)
git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim

# docker completions
etc=/Applications/Docker.app/Contents/Resources/etc
ln -s $etc/docker.zsh-completion /usr/local/share/zsh/site-functions/_docker
ln -s $etc/docker-compose.zsh-completion /usr/local/share/zsh/site-functions/_docker-compose

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
