#!/usr/bin/env bash
set -euo pipefail

clear

cat <<'BANNER'
 ██████╗ █████╗  ██████╗██╗  ██╗██╗   ██╗ ██████╗ ███████╗
██╔════╝██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝██╔═══██╗██╔════╝
██║     ███████║██║     ███████║ ╚████╔╝ ██║   ██║███████╗
██║     ██╔══██║██║     ██╔══██║  ╚██╔╝  ██║   ██║╚════██║
╚██████╗██║  ██║╚██████╗██║  ██║   ██║   ╚██████╔╝███████║
 ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
BANNER

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
BOLD="$(tput bold)"
RESET="$(tput sgr0)"

log() {
  printf "%s%s==>%s %s\n" "${BOLD}" "${BLUE}" "${RESET}" "$*"
}

ok() {
  printf "%s%s✔%s %s\n" "${GREEN}" "${BOLD}" "${RESET}" "$*"
}

warn() {
  printf "%s%s⚠%s %s\n" "${YELLOW}" "${BOLD}" "${RESET}" "$*"
}

die() {
  printf "%s%s✖%s %s\n" "${RED}" "${BOLD}" "${RESET}" "$*" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    return 1
  fi
}

RESOURCE_ZIP="${RESOURCE_ZIP:-resources.zip}"
PLAYBOOK="${PLAYBOOK:-playbook.yml}"
CONFIG_TARGET="${CONFIG_TARGET:-$HOME/.config}"

log "Starting install script"

printf "%s%sCachyOS Desktop Setup%s\n" "${BOLD}" "${BLUE}" "${RESET}"
printf "%sInstalls config files, packages, and desktop tweaks for a fresh CachyOS setup.%s\n" "${YELLOW}" "${RESET}"
printf "%s\n" "${RESET}"

read -r -p "Proceed with setup? [y/N] " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
  warn "Setup cancelled by user."
  exit 0
fi

if [[ ! -f "${RESOURCE_ZIP}" ]]; then
  die "Missing ${RESOURCE_ZIP} in $(pwd)"
fi

if ! require_cmd unzip; then
  log "Installing unzip (required to extract ${RESOURCE_ZIP})"
  sudo pacman -S --needed --noconfirm unzip
fi

log "Extracting ${RESOURCE_ZIP}"
unzip -o -q "${RESOURCE_ZIP}"
ok "Extracted ${RESOURCE_ZIP}"

RESOURCE_DIR="."
if [[ -d resources ]]; then
  RESOURCE_DIR="resources"
fi

log "Copying config folders into ${CONFIG_TARGET}"
mkdir -p "${CONFIG_TARGET}"
for cfg in fish ghostty tmux; do
  if [[ -d "${RESOURCE_DIR}/${cfg}" ]]; then
    cp -a "${RESOURCE_DIR}/${cfg}" "${CONFIG_TARGET}/"
    ok "Copied ${cfg} to ${CONFIG_TARGET}"
  else
    warn "Missing ${RESOURCE_DIR}/${cfg}, skipping"
  fi
done

log "Copying user fonts/themes/icons"
for dir in .fonts .themes .icons; do
  if [[ -d "${RESOURCE_DIR}/${dir}" ]]; then
    cp -a "${RESOURCE_DIR}/${dir}" "${HOME}/"
    ok "Copied ${dir} to ${HOME}"
  else
    warn "Missing ${RESOURCE_DIR}/${dir}, skipping"
  fi
done

if ! require_cmd git; then
  log "Installing git"
  sudo pacman -S --needed --noconfirm git
fi

if [[ ! -d yay ]]; then
  log "Cloning yay"
  git clone https://aur.archlinux.org/yay.git
else
  warn "yay directory already exists, using it"
fi

log "Building yay"
(
  cd yay
  if ! require_cmd makepkg; then
    log "Installing base-devel (required for makepkg)"
    sudo pacman -S --needed --noconfirm base-devel
  fi
  makepkg -si --noconfirm
)
ok "yay built and installed"

log "Installing packages with yay"
yay -S --needed --noconfirm \
  brave-bin \
  dracula-gtk-theme \
  ghostty \
  heroic-games-launcher \
  obsidian \
  spotify-launcher
ok "Installed AUR packages"

log "Installing ansible"
yay -S --needed --noconfirm ansible
ok "Ansible installed"

if [[ ! -f "${PLAYBOOK}" ]]; then
  die "Missing ansible playbook: ${PLAYBOOK}"
fi

log "Running ansible playbook: ${PLAYBOOK}"
ansible-playbook -K "${PLAYBOOK}"
ok "Ansible playbook completed"
