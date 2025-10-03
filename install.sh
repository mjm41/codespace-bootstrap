#!/usr/bin/env bash
set -euo pipefail

# ================================
# Config (override via env vars)
# ================================
: "${NVIM_VERSION:=0.11.4}"
: "${NVIM_CONFIG_URL:=https://github.com/NvChad/starter}"   # your nvim config repo
: "${INSTALL_FONTS:=1}"                                     # set 0 to skip Nerd Font
: "${INSTALL_TMUX:=1}"                                      # set 0 to skip tmux install
: "${INSTALL_RIPGREP:=1}"                                   # set 0 to skip ripgrep
: "${INSTALL_BUILD_ESSENTIAL:=1}"                           # set 0 to skip build-essential
: "${TMUX_CFG_INSTALL:=https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh}"

# Helpers
log() { printf "\n\033[1;32m==> %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m[warn]\033[0m %s\n" "$*"; }
die() { printf "\n\033[1;31m[error]\033[0m %s\n" "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    need_cmd sudo
  fi
}

# Detect Debian/Ubuntu (Codespaces are Debian-based)
if [ -f /etc/debian_version ]; then
  PKG_MGR="apt-get"
else
  warn "This script is tuned for Debian/Ubuntu (like Codespaces). Proceeding anyway."
  PKG_MGR="apt-get"
fi

log "Updating package index"
sudo ${PKG_MGR} update -y

# Base tools always handy
log "Installing base tools (curl, wget, unzip, fontconfig)"
sudo ${PKG_MGR} install -y curl wget unzip fontconfig || true

# Optional installs
if [ "${INSTALL_TMUX}" = "1" ]; then
  log "Installing tmux"
  sudo ${PKG_MGR} install -y tmux || true
fi

if [ "${INSTALL_RIPGREP}" = "1" ]; then
  log "Installing ripgrep"
  sudo ${PKG_MGR} install -y ripgrep || true
fi

if [ "${INSTALL_BUILD_ESSENTIAL}" = "1" ]; then
  log "Installing build-essential (gcc, g++, make)"
  sudo ${PKG_MGR} install -y build-essential || true
fi

# Remove distro Neovim if present
if dpkg -l | awk '{print $2}' | grep -qx neovim; then
  log "Removing distro Neovim to avoid conflicts"
  sudo ${PKG_MGR} remove --purge -y neovim || true
  sudo ${PKG_MGR} autoremove -y || true
fi

# Install Neovim ${NVIM_VERSION}
log "Installing Neovim v${NVIM_VERSION}"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64|amd64) NVIM_URL_1="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
                 NVIM_URL_2="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux64.tar.gz"
                 ;;
  aarch64|arm64) NVIM_URL_1="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-arm64.tar.gz"
                 NVIM_URL_2=""
                 ;;
  *)
    warn "Unrecognized arch '${ARCH}'. Attempting linux64 artifact."
    NVIM_URL_1="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux64.tar.gz"
    NVIM_URL_2=""
    ;;
esac

rm -f /tmp/nvim.tar.gz
if curl -fL -o /tmp/nvim.tar.gz "$NVIM_URL_1"; then
  log "Downloaded Neovim from $NVIM_URL_1"
elif [ -n "$NVIM_URL_2" ] && curl -fL -o /tmp/nvim.tar.gz "$NVIM_URL_2"; then
  log "Downloaded Neovim from $NVIM_URL_2"
else
  die "Could not download Neovim v${NVIM_VERSION} (arch: ${ARCH})."
fi

require_sudo
sudo tar -C /opt -xzf /tmp/nvim.tar.gz

# Find extracted dir and symlink
if [ -d /opt/nvim-linux-x86_64 ]; then
  SRC="/opt/nvim-linux-x86_64/bin/nvim"
elif [ -d /opt/nvim-linux64 ]; then
  SRC="/opt/nvim-linux64/bin/nvim"
elif [ -d /opt/nvim-linux-arm64 ]; then
  SRC="/opt/nvim-linux-arm64/bin/nvim"
else
  die "Unexpected Neovim extract dir in /opt. Contents: $(ls -la /opt | sed -n '1,80p')"
fi

sudo ln -sf "$SRC" /usr/local/bin/nvim
log "Neovim installed: $(nvim --version | head -n 1)"

# tmux config
if [ "${INSTALL_TMUX}" = "1" ]; then
  log "Installing tmux config (gpakosz/.tmux)"
  # avoid caching with a timestamp anchor
  curl -fsSL "${TMUX_CFG_INSTALL}#$(date +%s)" | bash || warn "tmux config install script returned non-zero"
fi

# Nerd Font (JetBrainsMono)
if [ "${INSTALL_FONTS}" = "1" ]; then
  log "Installing JetBrainsMono Nerd Font (latest release)"
  mkdir -p "${HOME}/.local/share/fonts"
  pushd /tmp >/dev/null
  rm -f JetBrainsMono.zip
  if curl -fL -o JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
    unzip -o JetBrainsMono.zip -d "${HOME}/.local/share/fonts"
    fc-cache -fv || true
    log "Set your terminal font to: 'JetBrainsMono Nerd Font' (non-Mono) for best icon sizing."
  else
    warn "Could not download JetBrainsMono Nerd Font."
  fi
  popd >/dev/null
fi

# Neovim config
log "Installing Neovim config from: ${NVIM_CONFIG_URL}"
# backup any existing config
if [ -d "${HOME}/.config/nvim" ]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  log "Backing up existing ~/.config/nvim -> ~/.config/nvim_backup_${TS}"
  mv "${HOME}/.config/nvim" "${HOME}/.config/nvim_backup_${TS}"
fi

git clone "${NVIM_CONFIG_URL}" "${HOME}/.config/nvim"

log "Bootstrap complete."
echo
echo "Next steps:"
echo "  1) Start Neovim: nvim"
echo "  2) Run your plugin manager sync (e.g., :Lazy sync)"
echo "  3) In your terminal settings, choose font: 'JetBrainsMono Nerd Font' (non-Mono)."
echo
echo "Environment overrides (examples):"
echo "  NVIM_VERSION=0.11.0 NVIM_CONFIG_URL=https://github.com/youruser/your-nvim.git ./install.sh"
