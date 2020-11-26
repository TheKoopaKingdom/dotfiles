#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# This file does things that can harm the system if done incorrectly, so exit upon error.
set -e

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/file_utils.sh
source "$CO"/scripts/bash/file_utils.sh
# shellcheck source=scripts/bash/configure_system_utils.sh
source "$CO"/scripts/bash/configure_system_utils.sh
# shellcheck source=scripts/bash/update.sh
source "$CO"/scripts/bash/update.sh
# shellcheck source=scripts/bash/configure_user_utils.sh
source "$CO"/scripts/bash/configure_user_utils.sh

# Exports certain constant variables.
# Globals Exported:
#   - INSTALL_HOME: Location of the home directory of the current install user.
#   - CO: Location of this Comet Observatory repository.
#   - SYNCED_DOCUMENTS_DIR: Location of the synced documents directory of the current install user.
#   - ABS_DIR: Location of the Arch Build System directory.
#   - AUR_DIR: Location of the Arch User Repository directory.
#   - GPG_DIR: Location of the GnuPG home directory of the current install user.
#   - SSH_DIR: Location of the SSH home directory of the current install user.
#   - PACMAN_ARGS: List of Pacman arguments useful for scripts.
# Arguments:
#   - The user that is being installed for, and owns the Comet Observatory.
function export_constants() {
  INSTALL_HOME=$(eval echo "~$INSTALL_USER")
  export INSTALL_HOME

  export CO=$INSTALL_HOME/Documents/Projects/Bash/comet-observatory
  if [[ ! -d $CO ]]; then
    error "Comet Observatory directory \"$CO\" not found."
    exit 1
  fi

  export SYNCED_DOCUMENTS_DIR=$INSTALL_HOME/Documents
  export TERRACE_DOWNLOADS_DIR=$INSTALL_HOME/Terrace/Downloads
  export TERRACE_VIDEOS_DIR=$INSTALL_HOME/Terrace/Videos
  export TERRACE_MUSIC_DIR=$INSTALL_HOME/Terrace/Music
  export ABS_DIR=$INSTALL_HOME/Documents/ABS
  export AUR_DIR=$INSTALL_HOME/Documents/AUR
  export GPG_DIR=$INSTALL_HOME/.gnupg
  export SSH_DIR=$INSTALL_HOME/.ssh

  export PACMAN_ARGS=(--noconfirm --needed --noprogressbar)
}

# Sets up the system components of the system.
# Globals Read:
#   - INSTALL_HOME: See export_constants().
#   - CO: See export_constants().
#   - PACMAN_ARGS: See export_constants().
#   - SYNCED_GTK_DIR: See export_constants().
# Globals Exported:
#   - DRY_RUN: Whether to actually perform actions.
#   - INSTALL_USER: The user that is being installed for, and owns the Comet Observatory.
# Outputs:
#   - Installation progress.
# Returns:
#   - 1 if the user couldn't be found.
function setup_system() {
  print_header "System Setup"

  # Customize the setup.
  section "Initializing Setup"

  info "Configuring setup."
  # Dry runs should print messages when action is about to be taken, but must not execute the
  # actions. All functions called here should have dry run support implemented within the function,
  # for consistency.
  config_bool "Is this a dry run? (y/n)?" DRY_RUN "$1"
  config_str "What user owns the Comet Observatory?" INSTALL_USER "$2"
  if ! id "$INSTALL_USER" >/dev/null 2>&1; then
    error "User \"$INSTALL_USER\" doesn't exist."
    exit 1
  fi

  info "Checking permissions."
  check_user true

  info "Setting constants."
  export_constants

  # Package Management
  section "Setting Up Packages"

  info "Configuring pacman."
  configure_pacman

  info "Syncing packages."
  if [[ $DRY_RUN = false ]]; then
    pacman -Syu "${PACMAN_ARGS[@]}" "${PACKAGE_IGNORE_ARGS[@]}"
  fi

  info "Installing packages."
  if [[ $DRY_RUN = false ]]; then
    # Initially run pikaur as the user, to utilize the pikaur cache in their home directory.
    grep -v "^#" "$CO"/data/packages.txt |
      sudo -u "$INSTALL_USER" xargs pikaur -S "${PACMAN_ARGS[@]}"
  fi

  # Kernel & Hardware
  section "Setting Up Kernel & Hardware"

  info "Configuring initial ramdisk."
  safe_cp "$CO"/config/mkinitcpio.conf /etc/mkinitcpio.conf

  info "Making initial ramdisks."
  if [[ $DRY_RUN = false ]]; then
    mkinitcpio -P || true
  fi

  info "Configuring kernel attributes."
  safe_cp "$CO"/config/sysctl.conf /etc/sysctl.d/99-sysctl.conf

  info "Configuring kernel modules."
  # This is not to be confused with the legacy "/etc/modprobe.conf".
  safe_cp "$CO"/config/modprobe.conf /etc/modprobe.d/modprobe.conf

  info "Configuring filesystems."
  safe_cp "$CO"/config/fstab /etc/fstab

  info "Creating swap memory."
  create_swap 8

  # System Services
  section "Setting Up System Services"

  info "Configuring sudo."
  configure_sudo

  info "Configuring system systemd services."
  configure_system_units

  info "Enabling system systemd services."
  enable_system_units

  info "Configuring udev."
  configure_udev_rules

  info "Setting up root GTK."
  # Apply the GTK configuration to root, to make applications like Gparted look nice.
  safe_ln "$INSTALL_HOME/.config/gtk-3.0" /root/.config/gtk-3.0

  info "Setup complete!"
}

# Sets up the user components of the system. Strictly only user commands that cannot be ran as
# root.
# Globals Read:
#   - INSTALL_HOME: See export_constants().
#   - CO: See export_constants().
#   - SYNCED_DOCUMENTS_DIR: See export_constants().
#   - SYNCED_GTK_DIR: See export_constants().
#   - ABS_DIR: See export_constants().
#   - AUR_DIR: See export_constants().
#   - GPG_DIR: See export_constants().
#   - SSH_DIR: See export_constants().
# Globals Exported:
#   - DRY_RUN: See setup().
#   - INSTALL_USER: See setup().
#   - SYNCED_DOCUMENTS: Whether documents have been synced.
# Outputs:
#   - Installation progress messages.
# Returns:
#   - 1 if the user couldn't be found.
function setup_user() {
  print_header "User Setup"

  # Customize the setup.
  section "Initializing Setup"

  info "Configuring setup."
  # See above.
  config_bool "Is this a dry run? (y/n)?" DRY_RUN "$1"
  local -r INSTALL_USER=$(whoami)
  if ! id "$INSTALL_USER" >/dev/null 2>&1; then
    error "User \"$INSTALL_USER\" doesn't exist."
    exit 1
  fi
  config_bool "Have private documents been synced yet? (y/n)?" SYNCED_DOCUMENTS "$2"

  info "Checking permissions."
  check_user false

  info "Setting constants."
  export_constants

  # File Structure
  section "Setting Up File Structure"

  info "Creating new directories."
  create_directories

  info "Linking directories."
  link_directories

  info "Adding link for deprecated mimeapps.list location."
  safe_ln "$INSTALL_HOME"/.config/mimeapps.list \
    "$INSTALL_HOME"/.local/share/applications/mimeapps.list

  # User Services
  section "Setting Up User Services"

  info "Configuring user systemd services."
  configure_user_units

  info "Enabling user systemd services."
  enable_user_units

  # User Services
  section "Setting Up User Programs"

  info "Silencing login message."
  if [[ $DRY_RUN = false ]]; then
    touch "$INSTALL_HOME"/.hushlogin
  fi

  info "Configuring GPG."
  configure_gpg

  section "Setting Up Pikaur"
  install_pikaur

  info "Setup complete!"
}
