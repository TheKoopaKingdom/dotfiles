#!/bin/bash

# Creates new directories, and sets them up with proper permissions if necessary.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Installation progress.
create_directories()
{
  declare -ra NEW_PATHS=(
    "$ABS_DIR"
    "$AUR_DIR"
    "$GPG_DIR"
  )

  for TARGET in "${NEW_PATHS[@]}"; do
    if [[ ! -d $TARGET ]]; then
      info "Making new path $TARGET."
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$TARGET"
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
#   - COMET_OBSERVATORY: See export_constants().
#   - SYNCED_DOCUMENTS_DIR: See export_constants().
#   - SYNCED_GTK3_DIR: See export_constants().
# Outputs;
#   - Link feedback.
link_directories()
{
  # The structure here (although will be random at runtime) is parallel to that of the package list.
  declare -rA LINKED_PATHS=(
    # Storage

    # Link downloads from the library to home directory.
    ["$INSTALL_HOME/Library/Downloads"]="$INSTALL_HOME/Downloads"
    # Link music from the library to home directory.
    ["$INSTALL_HOME/Library/Music"]="$INSTALL_HOME/Music"

    # Shell

    # Link Bash profile from CO to home directory.
    ["$COMET_OBSERVATORY/scripts/bash/bash-profile.sh"]="$INSTALL_HOME/.bash_profile"
    # Link Bash RC file from CO to home directory.
    ["$COMET_OBSERVATORY/scripts/bash/bash-rc.sh"]="$INSTALL_HOME/.bashrc"
    # Link X profile from CO to home directory.
    ["$COMET_OBSERVATORY/scripts/x/x-profile.sh"]="$INSTALL_HOME/.xprofile"
    # Link X RC file from CO to home directory.
    ["$COMET_OBSERVATORY/scripts/x/x-rc.sh"]="$INSTALL_HOME/.xinitrc"
    # Link CO configuration from documents to CO.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/Dotfiles Configuration.sh"]=\
"$COMET_OBSERVATORY/scripts/bash/config.sh"

    # Package Management

    # Link Octopi configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/Octopi.conf"]=\
"$INSTALL_HOME/.config/octopi/octopi.conf"

    # Desktop Environment

    # Link GTK 3.0 configuration from documents to user configuration.
    ["$SYNCED_GTK3_DIR"]="$INSTALL_HOME/.config/gtk-3.0"
    # Link GTK 3.0 configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/GTK 2.0.ini"]="$INSTALL_HOME/.gtkrc-2.0"
    # Link KDE global configuration from documents to user configuration, including standard 
    # shortcuts among other settings
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Common.conf"]=\
"$INSTALL_HOME/.config/kdeglobals"
    # Link KDE global shortcuts from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Global Shortcuts.conf"]=\
"$INSTALL_HOME/.config/kglobalshortcutsrc"
    # Link KDE custom shortcuts from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Custom Shortcuts.conf"]=\
"$INSTALL_HOME/.config/khotkeysrc"
    # Link KDED configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/KDED.conf"]="$INSTALL_HOME/.config/kded5rc"
    # Link Baloo configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Baloo.conf"]=\
"$INSTALL_HOME/.config/baloofilerc"
    # Link KWin configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/KWin.conf"]="$INSTALL_HOME/.config/kwinrc"
    # Link Plasma configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Plasma.conf"]=\
"$INSTALL_HOME/.config/plasmarc"
    # Link Plasma Shell configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Plasma Shell.conf"]=\
"$INSTALL_HOME/.config/plasmashellrc"
    # Link Plasma Desktop configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Plasma Desktop.conf"]=\
"$INSTALL_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    # Link Plasma Notification configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Plasma Notifications.conf"]=\
"$INSTALL_HOME/.config/plasmanotifyrc"

    # KDE Accessories

    # Link autostart programs from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/LinuxAutostartPrograms"]="$INSTALL_HOME/.config/autostart"
    # Link autostart scripts from CO to user configuration.
    ["$COMET_OBSERVATORY/bin/autostart/"]="$INSTALL_HOME/.config/autostart-scripts"
    # Link Konsole configuration from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Konsole Profile.profile"]=\
"$INSTALL_HOME/.local/share/konsole/Garage.profile"
    # Link RSIBreak configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/RSIBreak.conf"]=\
"$INSTALL_HOME/.config/rsibreakrc"
    # Link KDE Connect files from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/KDE Connect"]=\
"$INSTALL_HOME/.config/kdeconnect"

    # File Managers

    # Link Dolphin configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KDE/Dolphin.conf"]=\
"$INSTALL_HOME/.config/dolphinrc"
    # Link ROM properties files from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/rom-properties"]=\
"$INSTALL_HOME/.config/rom-properties"
    # Link MEGAsync configuration from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/MEGAsync.cfg"]=\
"$INSTALL_HOME/.local/share/data/Mega Limited/MEGAsync/MEGAsync.cfg"

    # Tools

    # Link Git configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/Git Configuration"]="$INSTALL_HOME/.gitconfig"
    # Link GPG configuration file from Comet Observatory to home directory.
    ["$COMET_OBSERVATORY/config/gpg.conf"]="$INSTALL_HOME/.gnupg/gpg.conf"

    # Link KeePassX configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/KeePassXC.ini"]=\
"$INSTALL_HOME/.config/keepassxc/keepassxc.ini"

    # Media

    # Link Clementine configuration from documents to user configuration. Only link the
    # configuration, because other files in the directory are subject to change.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/Clementine.conf"]=\
"$INSTALL_HOME/.config/Clementine/Clementine.conf"
    # Link mpv files from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/mpv"]="$INSTALL_HOME/.config/mpv"
    # Link OBS Studio configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/OBS Studio"]="$INSTALL_HOME/.config/obs-studio"
    # Link Blender files from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/Blender"]="$INSTALL_HOME/.config/blender"

    # Internet

    # Link HexChat files from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/HexChat"]="$INSTALL_HOME/.config/hexchat"
    
    # Gaming

    # Link Citra configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/Citra"]="$INSTALL_HOME/.config/citra-emu"
    # Link Citra data from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/Program Data/Citra"]="$INSTALL_HOME/.local/share/citra-emu"
    # Link Dolphin configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/Dolphin"]="$INSTALL_HOME/.config/dolphin-emu"
    # Link Dolphin data from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/Program Data/Dolphin"]="$INSTALL_HOME/.local/share/dolphin-emu"
    # Link Yuzu configuration from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/Yuzu"]="$INSTALL_HOME/.config/yuzu"
    # Link Yuzu data from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/Program Data/Yuzu"]="$INSTALL_HOME/.local/share/yuzu"
    # Link testing mod launcher from documents to documents.
    ["$SYNCED_DOCUMENTS_DIR/Dropbox/Donut Team Tools/Lucas' Simpsons Hit & Run Mod Launcher/\
Testing/"]="$SYNCED_DOCUMENTS_DIR/Program Data/Lucas' Simpsons Hit & Run Mod Launcher/launcher"
    # Link The Simpsons: Hit & Run data from documents to user data.
    ["$SYNCED_DOCUMENTS_DIR/Program Data/Lucas' Simpsons Hit & Run Mod Launcher"]=\
"$INSTALL_HOME/.local/share/lucas-simpsons-hit-and-run-mod-launcher"

    # Programming

    # Link VSCode extensions from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/VSCode/Extensions/"]=\
"$INSTALL_HOME/.vscode-oss/extensions"
    # Link VSCode snippets from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/VSCode/Snippets/"]=\
"$INSTALL_HOME/.config/Code - OSS/User/snippets"
    # Link VSCode keybindings from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/VSCode/Keybindings.json"]=\
"$INSTALL_HOME/.config/Code - OSS/User/keybindings.json"
    # Link VSCode settings from documents to user configuration.
    ["$SYNCED_DOCUMENTS_DIR/Program Configurations/VSCode/Settings.json"]=\
"$INSTALL_HOME/.config/Code - OSS/User/settings.json"
  )

  for TARGET in "${!LINKED_PATHS[@]}"; do
    if [[ $SYNCED_DOCUMENTS = false ]]; then
      if [[ $TARGET == "$SYNCED_DOCUMENTS_DIR"* ]]; then
        continue
      fi
    fi
    safe_ln "$TARGET" "${LINKED_PATHS[${TARGET}]}"
  done

  # SSH needs special perms, but we also want to backup its directory in its entirety (unlike GPG,
  # where we manually import the keys from the backup and leave "~/.gpg" as-is.) Our backup
  # directory is on a permission-less NTFS drive, so move the backup over and then link it back to
  # the backup directory so that MEGA can do it's thing.
  if [[ $SYNCED_DOCUMENTS = true ]]; then
    local -r SSH_BACKUP_DIR="$SYNCED_DOCUMENTS_DIR/Program Data/SSH"
    # Technically ensuring that it's a directory is redundant with checking if documents are synced.
    if [[ -d "$SSH_BACKUP_DIR" && ! -L $SSH_BACKUP_DIR ]]; then
      info "SSH directory found in synced documents. Moving to home directory and linking."
      if [[ $DRY_RUN = false ]]; then
        mv "$SSH_BACKUP_DIR" "$SSH_DIR"
      fi
      # This operation is in fact the reverse of the majority of the other links.
      safe_ln "$SSH_DIR" "$SSH_BACKUP_DIR"
    fi
  fi

  if [[ $(stat -c "%a" "$SSH_DIR") != "700" ]]; then
    info "Setting SSH directory permissions to 700."
    if [[ $DRY_RUN = false ]]; then
      # The SSH home directory needs special permissions.
      chmod 700 -R "$SSH_DIR"
    fi
  fi
}

# Configures user systemd services.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs;
#   - Copy feedback.
configure_user_units()
{
  for SERVICE in ../../config/systemd-services/*.service; do
    safe_cp "$SERVICE" "$INSTALL_HOME/.config/systemd/user/$(basename "$SERVICE")"
  done
}

# Enables user systemd units.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Installation progress.
enable_user_units()
{
  local -ra UNITS=(
    # Enable the SSH agent.
    "ssh-agent.service"
  )

  for UNIT in "${UNITS[@]}"; do
    if systemctl --user -q is-active "$UNIT"; then
      verbose "$UNIT is already enabled."
    else
      if [[ $DRY_RUN = false ]]; then
        info "Enabling systemd unit $UNIT"
        systemctl --user -q enable "$UNIT"
      fi
    fi
  done
}

# Imports data into GPG.
# Globals Read:
#   - DRY_RUN: See setup().
configure_gpg()
{
  if [[ $DRY_RUN = false && $SYNCED_DOCUMENTS ]]; then
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
install_pikaur()
{
  local -r PACKAGE=pikaur
  if ! pacman -Qi "$PACKAGE" > /dev/null; then
    info "Installing build dependencies."
    if [[ $DRY_RUN = false ]]; then 
      sudo pacman -S "${PACMAN_ARGS[@]}" base-devel git > /dev/null
    fi

    info "Installing pikaur."
    if [[ $DRY_RUN = false ]]; then
      local -r PACKAGE_BUILD_DIR="$AUR_DIR/$PACKAGE"
      # Make sure there's no pikaur dir becuase, if there is, Git will throw a fit.
      rm -rf "$PACKAGE_BUILD_DIR"
      # Clone the AUR package Git repository.
      git clone -q "https://aur.archlinux.org/$PACKAGE.git" "$PACKAGE_BUILD_DIR"
      # Skip the PGP check becasue we have not yet established our PGP keyring.
      cd "$PACKAGE_BUILD_DIR" && makepkg -cis --skippgpcheck
    fi
  else
    verbose "Pikaur is already installed."
  fi
}