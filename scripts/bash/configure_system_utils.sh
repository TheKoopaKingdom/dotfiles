#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/file_utils.sh
source "$CO"/scripts/bash/file_utils.sh

# Configures the initial ramdisk.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_initial_ramdisk() {
  safe_cp "$CO"/config/mkinitcpio.conf /etc/mkinitcpio.conf

  for PRESET in "$CO"/config/mkinitcpio-presets/*.preset; do
    safe_cp "$PRESET" /etc/mkinitcpio.d/"$(basename "$PRESET")"
  done
}

# Creates a swap file. See: https://wiki.archlinux.org/index.php/Swap#Manually
# Globals Read:
#   - DRY_RUN: See setup().
# Arguments:
#   - The number of gigabytes of swap to create.
function create_swap() {
  local -r GIGABYTES=$1

  if [[ -f /swapfile ]]; then
    verbose "Swap file already exists."
  else
    info "Creating swapfile."
    if [[ $DRY_RUN = false ]]; then
      truncate -s 0 /swapfile
      fallocate -l "${GIGABYTES}"G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      # This is applied upon reboot in /etc/sysctl.conf
      sysctl -q vm.swappiness=10
    fi
  fi
}

# Configures systemwide systemd units.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_system_units() {
  local -rA UNIT_OVERRIDES=(
    ["getty@tty1.service"]="getty-autologin.conf"
  )
  for UNIT in "${!UNIT_OVERRIDES[@]}"; do
    local -r DESTINATION=/etc/systemd/system/"$UNIT".d/override.conf
    safe_cp "$CO"/config/systemd-overrides/"${UNIT_OVERRIDES[${UNIT}]}" "$DESTINATION"
    if [[ $DRY_RUN = false ]]; then
      chmod -x "$DESTINATION"
    fi
  done

  safe_cp "$CO"/config/httpd.conf /etc/httpd/conf/httpd.conf
  safe_cp "$CO"/config/journald.conf /etc/systemd/journald.conf
  safe_cp "$CO"/config/geoclue.conf /etc/geoclue/geoclue.conf
}

# Enables systemwide systemd units.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Installation progress.
function enable_system_units() {
  local -ra UNITS=(
    # Enable periodic TRIM.
    "fstrim.timer"
    # Enable bluetooth.
    "bluetooth.service"
    # Enable CUPS.
    "org.cups.cupsd.service"
    # Enable the NetworkManager daemon.
    "NetworkManager.service"
    # Enable Apache.
    "httpd.service"
  )

  for UNIT in "${UNITS[@]}"; do
    if systemctl -q is-active "$UNIT"; then
      verbose "$UNIT is already enabled."
    else
      if [[ $DRY_RUN = false ]]; then
        info "Enabling systemd unit $UNIT"
        systemctl -q enable --now "$UNIT"
      fi
    fi
  done
}

# Applies udev rules.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_udev_rules() {
  for RULE in "$CO"/config/udev/*.rules; do
    safe_cp "$RULE" /etc/udev/rules.d/"$(basename "$RULE")"
  done
}

# Configures Pacman.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_pacman() {
  safe_cp "$CO"/config/pacman.conf /etc/pacman.conf
  safe_cp "$CO"/config/makepkg.conf /etc/makepkg.conf

  if [[ $DRY_RUN = false ]]; then
    info "Importing Chaotic AUR keys into pacman."
    pacman-key --keyserver keys.mozilla.org -r 3056513887B78AEB >/dev/null
    pacman-key --lsign-key 3056513887B78AEB >/dev/null
  fi
}
