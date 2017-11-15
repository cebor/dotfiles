#!/usr/bin/env bash
cd "$(dirname "$0")"

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

# disable resume system-wide
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# mouse & trackpad
defaults write com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode -string TwoButton
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.dock showAppExposeGestureEnabled -bool true

killall Finder
killall Dock
