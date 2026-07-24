#!/usr/bin/env bash

# Full installation script - installs dotfiles and packages
cd "$(dirname "$0")"

# parse args: --linux forces the Linux path (overrides auto-detection)
for arg in "$@"; do
  case "$arg" in
    --linux) export DOTFILES_OS=linux ;;
  esac
done

# shellcheck source=lib/os.sh
source "./lib/os.sh"

echo "=== Dotfiles Installation ($OS) ==="
echo

# run bootstrap if system is not set up yet (macOS: Xcode + Homebrew)
if [ "$OS" = "macos" ]; then
  if ! command -v brew &>/dev/null || ! xcode-select -p &>/dev/null; then
    echo "Running bootstrap..."
    ./macos-bootstrap.sh
    if [ $? -ne 0 ]; then
      echo "Bootstrap failed. Please fix any issues and try again."
      exit 1
    fi
    echo
  fi
  echo "✓ System bootstrapped"
  echo
fi

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
if [ "$OS" = "macos" ]; then
  echo
  echo "Applying macOS settings..."
  ./macos.sh
  echo "✓ macOS settings applied"
fi

# packages
echo
echo "Installing packages..."
if [ "$OS" = "macos" ]; then
  brew update
  brew upgrade
  brew bundle
  brew cleanup
else
  ./linux.sh
fi
echo "✓ Packages installed"

# setup ZSH as default shell
if [ "$OS" = "macos" ]; then
  TARGET_ZSH="$(brew --prefix)/bin/zsh"
else
  TARGET_ZSH="$(command -v zsh)"
fi
if [ -z "$TARGET_ZSH" ] || [ ! -x "$TARGET_ZSH" ]; then
  echo "⚠ zsh not found - skipping shell change"
elif [ "$SHELL" != "$TARGET_ZSH" ]; then
  echo "Changing default shell to $TARGET_ZSH..."
  if ! grep -q "$TARGET_ZSH" /etc/shells; then
    echo "$TARGET_ZSH" | sudo tee -a /etc/shells
  fi
  sudo chsh -s "$TARGET_ZSH" "$USER"
  echo "✓ Default shell changed (will take effect on next login)"
else
  echo "✓ Already using zsh"
fi

# setup vim
echo
echo "Setting up vim..."
./vim.sh
echo "✓ Vim configured"

echo
echo "=== Installation Complete ==="
echo "Please reload your shell: exec zsh"
