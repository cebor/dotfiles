#!/usr/bin/env bash

# Bootstrap script - run once for initial system setup
cd "$(dirname "$0")"

echo "=== Dotfiles Bootstrap ==="
echo "This script performs one-time system setup."
echo

# Install Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Please complete the Xcode installation and re-run this script."
  exit 1
else
  echo "✓ Xcode Command Line Tools already installed"
fi

# Install Homebrew
if [ ! -x "$(which brew)" ]; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "✓ Homebrew installed"
else
  echo "✓ Homebrew already installed"
fi

# Setup brewed ZSH as default shell
BREWED_ZSH="$(brew --prefix)/bin/zsh"
if [ "$SHELL" != "$BREWED_ZSH" ]; then
  echo "Changing default shell to brewed ZSH..."
  if ! grep -q "$BREWED_ZSH" /etc/shells; then
    echo "$BREWED_ZSH" | sudo tee -a /etc/shells
  fi
  sudo chsh -s "$BREWED_ZSH" "$USER"
  echo "✓ Default shell changed (will take effect on next login)"
else
  echo "✓ Already using brewed ZSH"
fi

# Setup Git user configuration
echo
echo "Setup Git user configuration..."
if [ -z "$(git config --global user.name)" ]; then
  read -p "Git username: " username
  git config --global user.name "$username"
fi
if [ -z "$(git config --global user.email)" ]; then
  read -p "Git email: " email
  git config --global user.email "$email"
fi
echo "✓ Git configured"

echo
echo "=== Bootstrap Complete ==="
