#!/bin/bash

# Configures the initial ramdisk.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs;
#   - Copy feedback.
configure_initial_ramdisk()
{
  safe_cp ../../config/mkinitcpio.conf /etc/mkinitcpio.conf

  for PRESET in ../../config/mkinitcpio-presets/*.preset; do
    safe_cp "$PRESET" "/etc/mkinitcpio.d/$(basename "$PRESET")"
  done
}

# Applies sysctl configurations.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs;
#   - Copy feedback.
configure_kernel_attributes()
{
  for CONF in ../../config/sysctl/*.conf; do
    safe_cp "$CONF" "/etc/sysctl.d/$(basename "$CONF")"
  done
}

# Applies kernel module configurations.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs;
#   - Copy feedback.
configure_kernel_modules()
{
  for CONF in ../../config/modules-load/*.conf; do
    safe_cp "$CONF" "/etc/modules-load.d/$(basename "$CONF")"
  done
  for CONF in ../../config/modules/*.conf; do
    safe_cp "$CONF" "/etc/modprobe.d/$(basename "$CONF")"
  done
}

# Creates 4GB of swap. See: https://wiki.archlinux.org/index.php/Swap#Manually
create_swap()
{
  if [[ -f /swapfile ]]; then
      verbose "Swap file already exists."
  else
      info "Creating swapfile."
      if [[ $DRY_RUN = false ]]; then
        truncate -s 0 /swapfile
        fallocate -l 4G /swapfile
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
# Outputs;
#   - Copy feedback.
configure_system_units()
{
  safe_cp ../../config/getty-autologin.conf /etc/systemd/system/getty@tty1.service.d/override.conf
  safe_cp ../../config/httpd.conf /etc/httpd/conf/httpd.conf
  safe_cp ../../config/journald.conf /etc/systemd/journald.conf
}

# Enables systemwide systemd units.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs:
#   - Installation progress.
enable_system_units()
{
  UNITS=(
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
    # Enable octopi speedup.
    "octopi.service"
  )

  for UNIT in "${UNITS[@]}"; do
    if systemctl -q is-active "$UNIT"; then
      verbose "$UNIT is already enabled."
    else
      if [[ $DRY_RUN = false ]]; then
        info "Enabling systemd unit $UNIT"
        systemctl -q enable "$UNIT"
      fi
    fi
  done
}

# Applies udev rules.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs;
#   - Copy feedback.
configure_udev_rules()
{
  for RULE in ../../config/udev/*.rules; do
    safe_cp "$RULE" "/etc/udev/rules.d/$(basename "$RULE")"
  done
}

# Configures Pacman.
# Globals Read:
#   - DRY_RUN: See setup().
# Outputs;
#   - Copy feedback.
configure_pacman()
{
  safe_cp "../../config/pacman.conf" /etc/pacman.conf
  safe_cp "../../config/makepkg.conf" /etc/makepkg.conf

  if [[ $DRY_RUN = false ]]; then
    info "Importing Chaotic AUR keys into pacman."
    pacman-key --keyserver keys.mozilla.org -r 3056513887B78AEB > /dev/null
    pacman-key --lsign-key 3056513887B78AEB > /dev/null
  fi
}