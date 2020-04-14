#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# This file does things that can harm the system if done incorrectly, so exit upon error.
set -e

# shellcheck source=./common.sh
source "$COMET_OBSERVATORY/scripts/bash/common.sh"
# shellcheck source=./file_utils.sh
source "$COMET_OBSERVATORY/scripts/bash/file_utils.sh"
# shellcheck source=./configure_system_utils.sh
source "$COMET_OBSERVATORY/scripts/bash/configure_system_utils.sh"
# shellcheck source=./configure_user_utils.sh
source "$COMET_OBSERVATORY/scripts/bash/configure_user_utils.sh"

# Prints a header.
# Arguments:
#   - The name of the script.
# Outputs:
#   - The Luma ASCII art, and repository info.
function print_header()
{
  local -r SCRIPT=$1

  # The comet observatory variable has not yet been checked.
  if [[ $DEBUG != true && -d $COMET_OBSERVATORY ]]; then
    cat "$COMET_OBSERVATORY/data/luma.txt" || true
  fi
  info "Comet Observatory System $SCRIPT Script"
  info "https://gitlab.com/CodingKoopa/comet-observatory"
  debug "Running in debug mode."
}

# Exports certain constant variables.
# Globals Exported:
#   - INSTALL_HOME: Location of the home directory of the current install user.
#   - COMET_OBSERVATORY: Location of this Comet Observatory repository.
#   - SYNCED_DOCUMENTS_DIR: Location of the synced documents directory of the current install user.
#   - SYNCED_GTK3_DIR: Location of the GTK 3.0 configuration directory of the current install user.
#   - ABS_DIR: Location of the Arch Build System directory.
#   - AUR_DIR: Location of the Arch User Repository directory.
#   - GPG_DIR: Location of the GnuPG home directory of the current install user.
#   - SSH_DIR: Location of the SSH home directory of the current install user.
#   - PACMAN_ARGS: List of Pacman arguments useful for scripts.
# Arguments:
#   - The user that is being installed for, and owns the Comet Observatory.
function export_constants()
{
  INSTALL_HOME=$(eval echo "~$INSTALL_USER")
  readonly INSTALL_HOME
  export INSTALL_HOME

  export COMET_OBSERVATORY="$INSTALL_HOME/Documents/Projects/Bash/comet-observatory"
  if [[ ! -d $COMET_OBSERVATORY ]]; then
    error "Comet Observatory directory \"$COMET_OBSERVATORY\" not found."
    exit 1
  fi

  export SYNCED_DOCUMENTS_DIR="$INSTALL_HOME/Documents"
  export SYNCED_GTK3_DIR="$SYNCED_DOCUMENTS_DIR/Program Configurations/GTK 3.0"
  export ABS_DIR="$INSTALL_HOME/Documents/ABS"
  export AUR_DIR="$INSTALL_HOME/Documents/AUR"
  export GPG_DIR="$INSTALL_HOME/.gnupg"
  export SSH_DIR="$INSTALL_HOME/.ssh"

  export PACMAN_ARGS=(--noconfirm --needed --noprogressbar)
}

# Enters the script directory, and sets up a trap to return.
# Arguments:
#   - The name of the script.
function enter_script_dir()
{
  # Enter the script directory so that we can use relative paths.
  pushd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null
  trap popd ERR
}

# Checks the user running the script.
# Globals Read:
#   - DRY_RUN: See setup().
# Arguments:
#   - Whether to require root or to require non root.
function check_user()
{
  local -r REQUIRE_ROOT=$1

  if [[ $DRY_RUN = false ]]; then
    if [[ $EUID -eq 0 ]]; then
      if [[ $REQUIRE_ROOT = false ]]; then
        error "This script cannot be run as root."
        exit 1
      fi
    else
      if [[ $REQUIRE_ROOT = true ]]; then
        error "This script must be run as root."
        exit 1
      fi
    fi
  fi
}

# Sets up the system components of the system.
# Globals Read:
#   - COMET_OBSERVATORY: See export_constants().
#   - PACMAN_ARGS: See export_constants().
#   - SYNCED_GTK_DIR: See export_constants().
# Globals Exported:
#   - DRY_RUN: Whether to actually perform actions.
#   - INSTALL_USER: The user that is being installed for, and owns the Comet Observatory.
# Outputs:
#   - Installation progress.
# Returns:
#   - 1 if the user couldn't be found.
function setup_system()
{
  print_header "System Setup"

  # Customize the setup.
  info_section "Initializing Setup"

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

  info "Entering script directory."
  enter_script_dir

  info "Checking permissions."
  check_user true

  info "Setting constants."
  export_constants

  # System Tools
  info_section "Setting Up System Programs"

  info "Configuring pacman."
  configure_pacman

  info_section "Setting Up System Packages"

  info "Syncing packages."
  if [[ $DRY_RUN = false ]]; then    
    pacman -Syu "${PACMAN_ARGS[@]}"
  fi

  info "Installing new packages."
  if [[ $DRY_RUN = false ]]; then  
    # Initially run pikaur as the user, to utilize the pikaur cache in their home directory.
    grep -v "^#" "$COMET_OBSERVATORY/data/packages.txt" | sudo -u "$INSTALL_USER" xargs pikaur -S "${PACMAN_ARGS[@]}"
  fi

  # Kernel & Hardware
  info_section "Setting Up Kernel & Hardware"

  info "Configuring initial ramdisk."
  configure_initial_ramdisk

  info "Making initial ramdisks."
  if [[ $DRY_RUN = false ]]; then    
    mkinitcpio -P || true
  fi

  info "Configuring kernel attributes."
  safe_cp ../../config/sysctl.conf /etc/sysctl.d/99-sysctl.conf

  info "Configuring kernel modules."
  configure_kernel_modules

  info "Configuring filesystems."
  safe_cp ../../config/fstab /etc/fstab

  info "Creating swap memory."
  create_swap

  # System Services
  info_section "Setting Up System Services"

  info "Configuring system systemd services."
  configure_system_units

  info "Enabling system systemd services."
  enable_system_units

  info "Configuring udev."
  configure_udev_rules

  info "Setting up root GTK."
  # Apply the GTK configuration to root, to make applications like Gparted look nice.
  safe_ln "$SYNCED_GTK3_DIR" /root/.config/gtk-3.0
  
  popd > /dev/null

  info "Setup complete!"
}

# Sets up the user components of the system. Strictly only user commands that cannot be ran as 
# root.
# Globals Read:
#   - INSTALL_HOME: See export_constants().
#   - COMET_OBSERVATORY: See export_constants().
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
function setup_user()
{
  print_header "User Setup"

  # Customize the setup.
  info_section "Initializing Setup"

  info "Configuring setup."
  # See above.
  config_bool "Is this a dry run? (y/n)?" DRY_RUN "$1"
  local -r INSTALL_USER=$(whoami)
  if ! id "$INSTALL_USER" >/dev/null 2>&1; then
    error "User \"$INSTALL_USER\" doesn't exist."
    exit 1
  fi
  config_bool "Have private documents been synced yet? (y/n)?" SYNCED_DOCUMENTS "$2"

  info "Entering script directory."
  enter_script_dir

  info "Checking permissions."
  check_user false

  info "Setting constants."
  export_constants

  # File Structure
  info_section "Setting Up File Structure"

  info "Creating new directories."
  create_directories

  info "Linking directories."
  link_directories

  # User Services
  info_section "Setting Up User Services"

  info "Configuring user systemd services."
  configure_user_units

  info "Enabling user systemd services."
  enable_user_units

  # User Services
  info_section "Setting Up User Programs"

  info "Silencing login message."
  if [[ $DRY_RUN = false ]]; then
    touch "$INSTALL_HOME"/.hushlogin
  fi

  info "Configuring GPG."
  configure_gpg

  info_section "Setting Up Pikaur"
  install_pikaur

  popd > /dev/null

  info "Setup complete!"
}