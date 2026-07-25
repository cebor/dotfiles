#!/usr/bin/env bash

# macOS system preferences via `defaults write` / `scutil`.
# Re-runnable: every write is absolute, and the hostname is only touched
# when you actually supply a new one.

setup_macos_defaults() {
  is_macos || { skip "macOS defaults are macOS-only"; return 0; }

  section "Applying macOS defaults"

  # every `defaults write` is a mutation, so failures have to surface; the
  # closing ok only fires when none of them warned.
  local warnings_before="$LOG_WARNINGS"

  # hostname — optional, current value shown so Enter can keep it.
  # `ask` stays silent under --yes / --dry-run, so those runs keep the hostname.
  local hostname current
  current="$(scutil --get ComputerName 2>/dev/null)"
  hostname="$(ask "Hostname (Enter keeps '$current')")"
  if [ -n "$hostname" ]; then
    # four separate mutations, and the ✓ below may only speak for all of them —
    # the same snapshot the whole function ends with, just scoped to this block
    local hostname_warnings="$LOG_WARNINGS"
    try sudo scutil --set ComputerName "$hostname"
    try sudo scutil --set HostName "$hostname"
    try sudo scutil --set LocalHostName "$hostname"
    try sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server \
      NetBIOSName -string "$hostname"
    if [ "$LOG_WARNINGS" -eq "$hostname_warnings" ]; then
      ok_run "hostname set to $hostname" "would set the hostname to $hostname"
    else
      warn "hostname only partially applied — see the warnings above"
    fi
  else
    skip "hostname unchanged ($current)"
  fi

  # finder
  try defaults write com.apple.finder NewWindowTarget -string "PfHm"
  try defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
  try defaults write com.apple.finder ShowRecentTags -bool false
  try defaults write com.apple.finder ShowPathbar -bool true
  try defaults write com.apple.finder ShowStatusBar -bool true
  try defaults write -g AppleShowAllExtensions -bool true

  # dock
  try defaults write com.apple.dock minimize-to-application -bool true
  try defaults write com.apple.dock autohide -bool true
  try defaults write com.apple.dock "show-recents" -bool false

  # mouse & trackpad
  try defaults write com.apple.dock showAppExposeGestureEnabled -bool true
  try defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  try defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  try defaults write com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode -string "TwoButton"
  try defaults write -g com.apple.mouse.tapBehavior -bool true

  # ical
  try defaults write com.apple.iCal "Show Week Numbers" -bool true

  # iterm2
  try defaults write com.googlecode.iterm2 QuitWhenAllWindowsClosed -bool true
  try defaults write com.googlecode.iterm2 PromptOnQuit -bool false
  try defaults write com.googlecode.iterm2 OnlyWhenMoreTabs -bool false
  try defaults write com.googlecode.iterm2 DoNotSetCtype -bool true  # fixes LC_CTYPE on linux remotes

  # a restart is only needed if the app is actually running — killall failing
  # because nobody is logged into a GUI is not an error.
  local app
  for app in Finder Dock; do
    if pgrep -x "$app" >/dev/null 2>&1; then
      run killall "$app" || warn "could not restart $app"
    else
      skip "$app was not running"
    fi
  done

  if [ "$LOG_WARNINGS" -ne "$warnings_before" ]; then
    warn "some macOS defaults were not applied — see the warnings above"
    return 1
  fi
  ok_run "macOS defaults applied" "would apply the macOS defaults"
}
