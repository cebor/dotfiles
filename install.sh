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
sudo chsh -s /usr/local/bin/zsh "$USER"
# fix compaudit for zsh autocompletes
chmod go-w /usr/local/share/zsh
chmod go-w /usr/local/share/zsh/site-functions

# docker completions
etc=/Applications/Docker.app/Contents/Resources/etc
ln -s $etc/docker.zsh-completion /usr/local/share/zsh/site-functions/_docker
ln -s $etc/docker-compose.zsh-completion /usr/local/share/zsh/site-functions/_docker-compose

# rust
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
rustup completions zsh > /usr/local/share/zsh/site-functions/_rustup
ln -s "$HOME"/.rustup/toolchains/stable-x86_64-apple-darwin/share/zsh/site-functions/_cargo /usr/local/share/zsh/site-functions/_cargo

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
