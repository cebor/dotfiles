#!/usr/bin/env bash

# Linux package installer (Debian/Ubuntu) - parallels `brew bundle` on macOS.
# Installs the apt list from packages/apt.txt, then the tools that are not
# available via apt. Every step is guarded so the script is safe to re-run.
cd "$(dirname "$0")"

echo "=== Installing Linux packages (apt) ==="

# apt packages from the list
sudo apt-get update
grep -vE '^\s*#|^\s*$' packages/apt.txt | sed 's/#.*//' | xargs sudo apt-get install -y

# WSL-only: wslu provides wslview (used by the `open` shim), wslpath, etc.
if grep -qi microsoft /proc/version 2>/dev/null; then
  sudo apt-get install -y wslu
fi

# Node.js (current) - Debian's `nodejs` is stale
if ! command -v node &>/dev/null; then
  echo "Installing Node.js (current)..."
  curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# antidote - zsh plugin manager (not in apt)
if [ ! -d "$HOME/.antidote" ]; then
  echo "Installing antidote..."
  git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
fi

# starship prompt (official installer, writes to /usr/local/bin)
if ! command -v starship &>/dev/null; then
  echo "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# helix editor
if ! command -v hx &>/dev/null; then
  if grep -qi ubuntu /etc/os-release; then
    echo "Installing helix (PPA)..."
    sudo add-apt-repository -y ppa:maveonair/helix-editor
    sudo apt-get update && sudo apt-get install -y helix
  else
    echo "⚠ helix: no Debian apt package - install manually from GitHub releases."
  fi
fi

# kubectl (pkgs.k8s.io apt repo)
if ! command -v kubectl &>/dev/null; then
  echo "Installing kubectl..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update && sudo apt-get install -y kubectl
fi

# helm (official installer script)
if ! command -v helm &>/dev/null; then
  echo "Installing helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# yq (mikefarah, GitHub binary - apt's `yq` is a different tool)
if ! command -v yq &>/dev/null; then
  echo "Installing yq..."
  sudo curl -fsSL -o /usr/local/bin/yq \
    https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod +x /usr/local/bin/yq
fi

# bat ships as `batcat` on Debian/Ubuntu (name clash with bacula's `bat`);
# expose it as `bat` via a symlink in ~/.local/bin (already on PATH)
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

# halloy config hardcodes a macOS path; rewrite it for this host if present
HALLOY_CONFIG="$HOME/.config/halloy/config.toml"
if [ -f "$HALLOY_CONFIG" ]; then
  sed -i "s#/Users/felix/#$HOME/#g" "$HALLOY_CONFIG"
fi

echo
echo "=== Linux packages installed ==="
