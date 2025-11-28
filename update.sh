#!/usr/bin/env bash
# Update script - run regularly to sync dotfiles and update packages
cd "$(dirname "$0")"

echo "=== Dotfiles Update ==="
echo

# Sync dotfiles
echo "Syncing dotfiles..."
./sync.sh -f
echo "✓ Dotfiles synced"
echo

# Apply git config
echo "Configuring git..."
./git.sh
echo "✓ Git configured"
echo

# Update Homebrew and packages
echo "Updating Homebrew packages..."
./brew.sh
echo "✓ Packages updated"
echo

# Setup/update vim
echo "Setting up vim..."
./vim.sh
echo "✓ Vim configured"
echo

# Apply macOS settings (optional - uncomment if desired)
# echo "Applying macOS settings..."
# ./macos.sh
# echo "✓ macOS settings applied"
# echo

echo "=== Update Complete ==="
echo "Reload your shell to apply changes: exec zsh"
