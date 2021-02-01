#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/file_utils.sh
source "$CO"/scripts/bash/file_utils.sh

# Configures Pacman.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_pacman() {
  safe_cp "$CO"/config/pacman.conf /etc/pacman.conf
  safe_cp "$CO"/config/makepkg.conf /etc/makepkg.conf
}

# Creates a swap file. See: https://wiki.archlinux.org/index.php/Swap#Manually
# Globals Read:
#   - DRY_RUN: See setup().
# Arguments:
#   - The number of gigabytes of swap to create.
function create_swap() {
  local -r gigabytes=$1

  if [[ -f /swapfile ]]; then
    verbose "Swap file already exists."
  else
    info "Creating swapfile."
    if [[ $DRY_RUN = false ]]; then
      dd if=/dev/zero of=/swapfile bs=1M count="$gigabytes"GB status=progress iflag=count_bytes
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      # This is applied upon reboot in /etc/sysctl.conf
      sysctl -q vm.swappiness=10
    fi
  fi
}

# Configures sudo.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_sudo() {
  safe_cp "$CO"/config/sudo.conf /etc/sudo.conf
  safe_cp "$CO"/config/sudoers /etc/sudoers
}

# Configures systemwide systemd units.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_system_units() {
  local -rA unit_overrides=(
    ["getty@tty1.service"]="getty-autologin.conf"
  )
  for unit in "${!unit_overrides[@]}"; do
    local destination=/etc/systemd/system/$unit.d/override.conf
    safe_cp "$CO"/config/systemd-overrides/"${unit_overrides[${unit}]}" "$destination"
    if [[ $DRY_RUN = false ]]; then
      chmod -x "$destination"
    fi
  done

  safe_cp "$CO"/config/journald.conf /etc/systemd/journald.conf
  safe_cp "$CO"/config/reflector.conf /etc/xdg/reflector/reflector.conf
  safe_cp "$CO"/config/pulse-daemon.conf /etc/pulse/daemon.conf
  safe_cp "$CO"/config/httpd.conf /etc/httpd/conf/httpd.conf
}

# Enables systemwide systemd units.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Installation progress.
function enable_system_units() {
  local -ra units=(
    # Enable reflector.
    "reflector.timer"
    # Enable bluetooth.
    "bluetooth.service"
    # Enable CUPS.
    "cups.service"
    # Enable the NetworkManager daemon.
    "NetworkManager.service"
  )

  for unit in "${units[@]}"; do
    if systemctl -q is-active "$unit"; then
      verbose "$unit is already enabled."
    else
      if [[ $DRY_RUN = false ]]; then
        info "Enabling systemd unit $unit"
        systemctl -q enable --now "$unit"
      fi
    fi
  done
  # pkgstats doesn't seem to like being enabled.
  if [[ $DRY_RUN = false ]]; then
    # Enable pkgstats.
    systemctl -q start "pkgstats.timer"
  fi
}

# Applies udev rules.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_udev_rules() {
  for rule in "$CO"/config/udev/*.rules; do
    safe_cp "$rule" /etc/udev/rules.d/"$(basename "$rule")" root:root 600
  done
}
