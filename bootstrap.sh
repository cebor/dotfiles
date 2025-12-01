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

echo
echo "=== Bootstrap Complete ==="
