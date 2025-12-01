#!/usr/bin/env bash

# Setup Git configuration
echo
echo "Setting up Git configuration..."
git config --global core.excludesfile "~/.gitignore_global"
git config --global core.attributesfile "~/.gitattributes_global"
git config --global core.editor "hx"
git config --global core.autocrlf "input"
git config --global push.default "simple"
git config --global push.followTags "true"
git config --global init.defaultBranch "main"
git config --global credential.helper "osxkeychain"

# Prompt for user.name and user.email if not set
if [ -z "$(git config --global user.name)" ]; then
  read -p "Git username: " username
  git config --global user.name "$username"
fi
if [ -z "$(git config --global user.email)" ]; then
  read -p "Git email: " email
  git config --global user.email "$email"
fi

echo "✓ Git configured"

