#!/usr/bin/env bash
# Full installation script - installs dotfiles and packages
cd "$(dirname "$0")"

echo "=== Dotfiles Installation ==="
echo

# Run bootstrap if system is not set up yet
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

# Apply git config
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

# setup vim
echo
echo "Setting up vim..."
./vim.sh
echo "✓ Vim configured"

echo
echo "=== Installation Complete ==="
echo "Please reload your shell: exec zsh"
