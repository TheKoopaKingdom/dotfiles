#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/file_utils.sh
source "$CO"/scripts/bash/file_utils.sh
# shellcheck source=scripts/makepkg/repos.sh
source "$CO"/scripts/makepkg/repos.sh

# Creates new directories, and sets them up with proper permissions if necessary.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Installation progress.
function create_directories() {
  declare -ra new_paths=(
    "$TERRACE_DOWNLOADS_DIR"
    "$TERRACE_VIDEOS_DIR"
    "$TERRACE_MUSIC_DIR"
    "$ABS_DIR"
    "$AUR_DIR"
    "$GPG_DIR"
  )

  for target in "${new_paths[@]}"; do
    if [[ ! -d $target ]]; then
      info "Making new path $target."
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$target"
      fi
    fi
  done
  if [[ $(stat -c "%a" "$GPG_DIR") != "700" ]]; then
    info "Setting GnuPG directory permissions to 700."
    if [[ $DRY_RUN = false ]]; then
      # The GPG home directory needs special permissions.
      chmod 700 -R "$GPG_DIR"
    fi
  fi
}

# Creates new directories, and sets them up with proper permissions if necessary.
# Globals Read:
#   - DRY_RUN: See setup().
#   - INSTALL_HOME: See export_constants().
#   - INSTALL_USER: See setup_system().
#   - CO: See export_constants().
#   - SYNCED_DOCUMENTS_DIR: See export_constants().
# Outputs:
#   - Link feedback.
function link_directories() {
  # The structure here (although will be random at runtime) is parallel to that of the package list.
  declare -rA linked_paths=(
    # Storage

    # Link downloads from the terrace to home directory.
    ["$TERRACE_DOWNLOADS_DIR"]="$INSTALL_HOME/Downloads"
    # Link videos from the terrace to home directory.
    ["$TERRACE_VIDEOS_DIR"]="$INSTALL_HOME/Videos"
    # Link music from the terrace to home directory.
    ["$TERRACE_MUSIC_DIR"]="$INSTALL_HOME/Music"
    # Wine prints an error if we don't have a Desktop directory.
    ["$INSTALL_HOME/Documents"]="$INSTALL_HOME/Desktop"

    # Shell

    # Link PAM environemnt from CO to home directory.
    ["$CO/config/pam-environment.env"]="$INSTALL_HOME/.pam_environment"
    # Link Bash profile from CO to home directory.
    ["$CO/scripts/bash/bash_profile.sh"]="$INSTALL_HOME/.bash_profile"
    # Link Bash RC file from CO to home directory.
    ["$CO/scripts/bash/bash_rc.sh"]="$INSTALL_HOME/.bashrc"
    # Link X RC file from CO to home directory.
    ["$CO/scripts/x/x_rc.sh"]="$INSTALL_HOME/.xinitrc"
    # Link X Compose file from CO to home directory.
    ["$CO/config/compose-keys.conf"]="$INSTALL_HOME/.XCompose"

    # Desktop Environment

    # Link user directory configuration from CO to user configuration.
    ["$CO/config/user-dirs.dirs"]="$INSTALL_HOME/.config/user-dirs.dirs"
    # Link PulseAudio startup script from CO to user configuration.
    ["$CO/config/default.pa"]="$INSTALL_HOME/.config/pulse/default.pa"

    # KDE Accessories

    # Link autostart programs from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/LinuxAutostartPrograms"]="$INSTALL_HOME/.config/autostart"
    # Link autostart scripts from CO to user configuration.
    ["$CO/config/autostart/"]="$INSTALL_HOME/.config/autostart-scripts"

    # File Managers

    # Tools

    # Link top configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/ProgramConfigurations/Top Configuration"]="$INSTALL_HOME/.config/procps/toprc"
    # Link Git configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/ProgramConfigurations/Git Configuration"]="$INSTALL_HOME/.gitconfig"
    # Link GPG configuration file from CO to home directory.
    ["$CO/config/gpg.conf"]="$INSTALL_HOME/.gnupg/gpg.conf"
    # Link GPG configuration file from CO to home directory.
    ["$CO/config/gpg-agent.conf"]="$INSTALL_HOME/.gnupg/gpg-agent.conf"
    # Link Pikaur configuration file from CO to home directory.
    ["$CO/config/pikaur.conf"]="$INSTALL_HOME/.config/pikaur.conf"
    # Link KeePassX configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/ProgramConfigurations/KeePassXC.ini"]="$INSTALL_HOME/.config/keepassxc/keepassxc.ini"

    # Media

    # Link mpv configuration from CO to user configuration.
    ["$CO/config/mpv.conf"]="$INSTALL_HOME/.config/mpv/mpv.conf"
    # Link OBS Studio configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/ProgramConfigurations/OBS Studio"]="$INSTALL_HOME/.config/obs-studio"
    # Link Blender files from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/ProgramConfigurations/Blender"]="$INSTALL_HOME/.config/blender"

    # Gaming

    # Link GameMode configuration from CO to user configuration.
    ["$CO/config/gamemode.ini"]="$INSTALL_HOME/.config/gamemode.ini"
    # Link Citra configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/ProgramConfigurations/Citra"]="$INSTALL_HOME/.config/citra-emu"
    # Link Citra data from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/ProgramData/Citra"]="$INSTALL_HOME/.local/share/citra-emu"
    # Link Dolphin configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/ProgramConfigurations/Dolphin"]="$INSTALL_HOME/.config/dolphin-emu"
    # Link Dolphin data from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/ProgramData/Dolphin"]="$INSTALL_HOME/.local/share/dolphin-emu"
    # Link Yuzu configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/ProgramConfigurations/Yuzu"]="$INSTALL_HOME/.config/yuzu"
    # Link Yuzu data from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/ProgramData/Yuzu"]="$INSTALL_HOME/.local/share/yuzu"
    # Link Lucas' Simpsons Hit & Run Mod Launcher data from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/ProgramData/Lucas' Simpsons Hit & Run Mod Launcher"]="$INSTALL_HOME/Documents/My Games/Lucas' Simpsons Hit & Run Mod Launcher/"
    # Link The Simpsons: Hit & Run data from Fountain to user data.
    ["$INSTALL_HOME/Fountain/Games/PC/IndependentWindows/The Simpsons Hit & Run/"]="$INSTALL_HOME/.local/share/the-simpsons-hit-and-run"

    # Programming

    # Link VSCode keybindings from CO to user configuration.
    ["$CO/config/vs-code/Keybindings.json"]="$INSTALL_HOME/.config/Code - OSS/User/keybindings.json"
    # Link VSCode settings from documents to user configuration.
    ["$CO/config/vs-code/Settings.json"]="$INSTALL_HOME/.config/Code - OSS/User/settings.json"
    # Link VSCode snippets from documents to user configuration.
    ["$CO/config/vs-code/Snippets/"]="$INSTALL_HOME/.config/Code - OSS/User/snippets"

    # Frogging Family

    # Link TKG Kernel configuration from CO to user configuration.
    ["$CO/config/tkg/linux-tkg.cfg"]="$INSTALL_HOME/.config/frogminer/linux-tkg.cfg"
    # Link TKG Nvidia configuration from CO to user configuration.
    ["$CO/config/tkg/nvidia-all.cfg"]="$INSTALL_HOME/.config/frogminer/nvidia-all.cfg"
    # Link TKG Wine configuration from CO to user configuration.
    ["$CO/config/tkg/proton-tkg.cfg"]="$INSTALL_HOME/.config/frogminer/proton-tkg.cfg"
  )

  for target in "${!linked_paths[@]}"; do
    if [[ $SYNCED_DOCUMENTS = false ]]; then
      if [[ $target == "$SYNCED_DOCUMENTS_DIR"* ]]; then
        continue
      fi
    fi
    safe_ln "$target" "${linked_paths[${target}]}"
  done
}

# Configures user systemd units.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Copy feedback.
function configure_user_units() {
  for service in "$CO"/config/systemd-user-units/*.service; do
    safe_cp "$service" "$INSTALL_HOME"/.config/systemd/user/"$(basename "$service")" \
      "$INSTALL_USER":"$INSTALL_USER" 600
  done
}

# Enables user systemd units.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Installation progress.
function enable_user_units() {
  local -ra units=(
    # Enable the SSH agent.
    "ssh-agent.service"
    # Enable the modprobed-db service.
    "modprobed-db.service"
  )

  for unit in "${units[@]}"; do
    if systemctl --user -q is-active "$unit"; then
      verbose "$unit is already enabled."
    else
      if [[ $DRY_RUN = false ]]; then
        info "Enabling systemd unit $unit"
        systemctl --user -q enable "$unit"
      fi
    fi
  done
}

# Imports data into GPG.
# Globals Read:
#   - DRY_RUN: See setup().
function configure_gpg() {
  if [[ $DRY_RUN = false && $SYNCED_DOCUMENTS = true ]]; then
    info "Importing GnuPG data from the private documents."
    gpg -q --import "$SYNCED_DOCUMENTS_DIR/Passwords & 2FA/GnuPG/Private Key.key"
    gpg -q --import-ownertrust "$SYNCED_DOCUMENTS_DIR/Passwords & 2FA/GnuPG/Owner Trust.txt"
  fi
}

# Installs pikaur.
# Globals Read:
#   - DRY_RUN: See setup().
#   - PACMAN_ARGS: See export_constants().
#   - AUR_DIR: See export_constants().
# Outputs:
#   - Installation progress.
function install_pikaur() {
  local -r PACKAGE=pikaur
  if ! pacman -Qi "$PACKAGE" >/dev/null; then
    info "Installing build dependencies."
    if [[ $DRY_RUN = false ]]; then
      sudo pacman -S "${PACMAN_ARGS[@]}" base-devel git >/dev/null
    fi

    info "Installing pikaur."
    if [[ $DRY_RUN = false ]]; then
      local -r package_build_dir="$AUR_DIR/$PACKAGE"
      # Make sure there's no pikaur dir becuase, if there is, Git will throw a fit.
      rm -rf "$package_build_dir"
      # Clone the AUR package Git repository.
      git clone -q "https://aur.archlinux.org/$PACKAGE.git" "$package_build_dir"
      # Skip the PGP check becasue we have not yet established our PGP keyring.
      cd "$package_build_dir" && makepkg -cis --skippgpcheck
    fi
  else
    verbose "Pikaur is already installed."
  fi
}
