#!/usr/bin/env bash

read -p "Hostname: "
sudo scutil --set ComputerName "$REPLY" && \
sudo scutil --set HostName "$REPLY" && \
sudo scutil --set LocalHostName "$REPLY" && \
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$REPLY"

# finder
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
defaults write com.apple.finder ShowRecentTags -bool false
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write -g AppleShowAllExtensions -bool true

# dock
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock "show-recents" -bool false

# disable resume system-wide
# defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# mouse & trackpad
defaults write com.apple.dock showAppExposeGestureEnabled -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode -string "TwoButton"
defaults write -g com.apple.mouse.tapBehavior -bool true

# ical
defaults write com.apple.iCal "Show Week Numbers" -bool true

# iterm2
defaults write com.googlecode.iterm2 QuitWhenAllWindowsClosed -bool true
defaults write com.googlecode.iterm2 PromptOnQuit -bool false
defaults write com.googlecode.iterm2 OnlyWhenMoreTabs -bool false
defaults write com.googlecode.iterm2 DoNotSetCtype -bool true   # fix LC_CTYPE errors on linux remotes

killall Finder
killall Dock
