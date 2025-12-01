#!/usr/bin/env bash

# Full installation script - installs dotfiles and packages
cd "$(dirname "$0")"

echo "=== Dotfiles Installation ==="
echo

# run bootstrap if system is not set up yet
if ! command -v brew &>/dev/null || ! xcode-select -p &>/dev/null; then
  echo "Running bootstrap..."
  ./bootstrap.sh
  if [ $? -ne 0 ]; then
    echo "Bootstrap failed. Please fix any issues and try again."
    exit 1
  fi
  echo
fi

echo "✓ System bootstrapped"
echo

# sync files
echo "Syncing dotfiles..."
./sync.sh -f
echo "✓ Dotfiles synced"

# apply git config
echo
echo "Configuring git..."
./git.sh
echo "✓ Git configured"

# macos settings
echo
echo "Applying macOS settings..."
./macos.sh
echo "✓ macOS settings applied"

# homebrew
echo
echo "Installing Homebrew packages..."
brew update
brew upgrade
brew bundle
brew cleanup
echo "✓ Packages installed"

# setup brewed ZSH as default shell
BREWED_ZSH="$(brew --prefix)/bin/zsh"
if [ ! -x "$BREWED_ZSH" ]; then
  echo "⚠ Brewed zsh not found - skipping shell change"
elif [ "$SHELL" != "$BREWED_ZSH" ]; then
  echo "Changing default shell to brewed ZSH..."
  if ! grep -q "$BREWED_ZSH" /etc/shells; then
    echo "$BREWED_ZSH" | sudo tee -a /etc/shells
  fi
  sudo chsh -s "$BREWED_ZSH" "$USER"
  echo "✓ Default shell changed (will take effect on next login)"
else
  echo "✓ Already using brewed ZSH"
fi

# setup vim
echo
echo "Setting up vim..."
./vim.sh
echo "✓ Vim configured"

echo
echo "=== Installation Complete ==="
echo "Please reload your shell: exec zsh"
