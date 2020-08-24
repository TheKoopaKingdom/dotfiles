#!/bin/bash

# Copyright 2020 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

set -e

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/makepkg/repos.sh
source "$CO"/scripts/makepkg/repos.sh

# shellcheck disable=2054
PACKAGE_IGNORE_ARGS=(--ignore linux"$KERNEL_VER"-tkg-pds,linux"$KERNEL_VER"-tkg-pds-headers
  --ignore nvidia-dkms-tkg,nvidia-utils-tkg,lib32-nvidia-utils-tkg,nvidia-settings-tkg
  --ignore proton-tkg-git --ignore vkd3d-proton-tkg-git)

# Prints the usage info for this script.
# Outputs:
#   - The help message.
function print_help() {
  # Keep the help string in its own variable because a single quote in a heredoc messes up syntax
  # highlighting.
  HELP_STRING="
Usage: update [-hpc]
Updates the system, including official prebuilt packages, AUR packages, and, and custom Frogging
Family packages. Also handles some routine maintenance tasks.

  -h    Show this help message and exit.
  -a    Do everything.
  -c    Update custom packages. This pulls the latest Git repos, reviews changes, and builds the
packages.
  -p    Update prebuilt packages. This essentially runs pacman -Syu for official and AUR packages.
  -f    Run fstrim.
"
  echo "$HELP_STRING"
  exit 0
}

# Updates the system.
# Globals Read:
#   - AUR_DIR: The directory where the repositories are located.
#   - KERNEL_VER: The two digit TkG kernel version.
# Arguments:
#   - One or more flags dictating the action to be taken. See print_help().
# Outputs:
#   - Update progress.
function update() {
  local update_prebuilt=false
  local update_custom=false
  local run_fstrim=false

  while getopts "hpcfa" opt; do
    case $opt in
    h)
      print_help
      ;;
    a)
      update_prebuilt=true
      update_custom=true
      run_fstrim=true
      ;;
    c)
      update_custom=true
      ;;
    p)
      update_prebuilt=true
      ;;
    f)
      run_fstrim=true
      ;;
    *)
      print_help
      ;;
    esac
  done
  if [[ $# -eq 0 ]]; then
    error "No operations specified."
    print_help
  fi

  # Ask for the sudo password now so that the rest of the process can proceed without it.
  sudo echo >/dev/null

  if [[ $update_custom = true ]]; then
    section "Updating Custom Package Sources"

    safe_cd "$AUR_DIR"
    subsect "Checking repository directories."
    check_repos
    subsect "Updating community patches."
    update_repo community-patches
    subsect "Updating TkG Linux kernel $KERNEL_VER source."
    update_repo linux-tkg/linux"$KERNEL_VER"-tkg customization.cfg
    subsect "Updating Nvidia drivers."
    update_repo nvidia-all customization.cfg
    subsect "Updating DXVK."
    update_repo dxvk-tools updxvk.cfg
    subsect "Updating vkd3d."
    update_repo vkd3d-git customization.cfg
    subsect "Building TkG Proton."
    update_repo wine-tkg-git/proton-tkg proton-tkg.cfg \
      proton-tkg-profiles/advanced-customization.cfg

    section "Building Custom Packages"

    subsect "Building TKG Linux kernel $KERNEL_VER."
    build_repo linux-tkg/linux"$KERNEL_VER"-tkg
    subsect "Building Nvidia drivers."
    build_repo nvidia-all
    subsect "Building DXVK."
    build_dxvk
    subsect "Building vkd3d."
    build_repo vkd3d-git
    subsect "Building TkG Proton."
    build_repo wine-tkg-git/proton-tkg
  fi
  if [[ $update_prebuilt = true ]]; then
    section "Updating Prebuilt Packages"

    subsect "Syncing official and Chaotic AUR packages."
    pikaur -Syu --noconfirm --ignore linux$KERNEL_VER-tkg-pds,linux$KERNEL_VER-tkg-pds-headers \
      --ignore nvidia-dev-dkms-tkg,nvidia-dev-utils-tkg,lib32-nvidia-dev-utils-tkg \
      --ignore nvidia-dev-settings-tkg,nvidia-dev-egl-wayland-tkg \
      --ignore opencl-nvidia-dev-tkg,lib32-opencl-nvidia-dev-tkg \
      --ignore mingw-w64-binutils --ignore mingw-w64-binutils \
      --ignore proton-tkg-git --ignore vkd3d-tkg-git
  fi
  if [[ $run_fstrim = true ]]; then
    section "Running fstrim"
    fstrim --fstab --verbose
  fi
}
