#!/usr/bin/env bash

# Apply git config settings from template (preserves user.name/email)
git config --global core.excludesfile "~/.gitignore_global"
git config --global core.attributesfile "~/.gitattributes_global"
git config --global core.editor "hx"
git config --global core.autocrlf "input"
git config --global push.default "simple"
git config --global push.followTags "true"
git config --global init.defaultBranch "main"
git config --global credential.helper "osxkeychain"
