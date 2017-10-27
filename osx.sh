#!/usr/bin/env bash
cd "$(dirname "$0")"

read -p "Hostname: "
sudo scutil --set ComputerName "$REPLY" && \
sudo scutil --set HostName "$REPLY" && \
sudo scutil --set LocalHostName "$REPLY" && \
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$REPLY"
