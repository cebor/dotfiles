#!/usr/bin/env bash

# Script to sync dotfiles to home directory
cd "$(dirname "$0")"

# sync dotfiles from git/ and system/ to home directory
sync_dotfiles() {
  local dry_run_flag=""

  if [[ "$1" == "--dry-run" ]]; then
    dry_run_flag="--dry-run"
    echo "Dry run mode - showing what would be synced:"
    echo
  fi

  rsync \
    --exclude ".DS_Store" \
    --archive \
    --verbose \
    ${dry_run_flag} \
    git/ system/ "$HOME"
}

# prompt user for confirmation
confirm_sync() {
  read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

# main execution
main() {
  case "$1" in
    --force|-f)
      sync_dotfiles
      ;;
    --dry-run|-d)
      sync_dotfiles --dry-run
      ;;
    *)
      if confirm_sync; then
        sync_dotfiles
      fi
      ;;
  esac
}

main "$@"
