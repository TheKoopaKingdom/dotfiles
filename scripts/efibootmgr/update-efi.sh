#!/bin/bash

set -e

# Escapes a string for usage in a sed pattern. Sed expression copied from 
# https://stackoverflow.com/a/2705678.
# Arguments:
#   - The string to escape. If omitted it's read from stdin
#   - The seperator char. Defaults to /
# Outputs:
#   The escaped string.
sed_escape_pattern()
{
  if [ $# -ge 1 ]; then
    # shellcheck disable=SC1003
    printf '%s\n' "$1" | sed 's/[]\\'"${2:-/}"'$*.^[]/\\&/g'
  else
    sed 's/[]\\/$*.^[]/\\&/g'
  fi
}

# Finds the bootnum from the name of a boot entry.
# Arguments:
#   - The name of the boot entry to find.
# Outputs:
#   The bootnums of the found boot entries, or nothing if none is found.
find_bootnum()
{
  efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? '"$(sed_escape_pattern "$1")"'$/\1/p'
}

# Updates a boot entry with new parameters. Empty parameters are handled like unset. See
# efibootmgr(8) for parameter defaults.
# Arguments:
#   - The label of the boot entry.
#   - The loader for the boot entry.
#   - Command line arguments for the loader.
# Outputs:
#   The bootnum of the boot entry.
update_entry()
{
  local -r LABEL=$1
  local -r LOADER=$2
  local -r CMDLINE=$3

  # It's necessary to delete the existing entry and replace it, because efibootmgr doesn't support
  # editing an existing entry: https://github.com/rhboot/efibootmgr/issues/49.
  old_bootnum="$(find_bootnum "$1")"
  if [ -n "$old_bootnum" ]; then
    efibootmgr -q -b "$old_bootnum" -B
  fi
  efibootmgr -q -c --label "$LABEL" -l "$LOADER" -u "$CMDLINE"
}

# Updates Arch Linux UEFI boot entries.
# Arguments:
#   The type of entries to generate, out of "quiet", "debug", "rescue", and "fallback-rescue".
# Outputs:
#   Changes being made to EFI boot entries.
function update-efi()
{
  local -r TYPE=$1  

  local -r ROOT="PARTUUID=91fb9373-d9b2-4e6d-a376-0388afe85bf0"
  local -r MICROCODE="amd-ucode.img"

  local -ra CMDLINE_ARRAY=(
    # Enable r/w on the file system, for functionality.
    "rw"
    # Set the root filesystem, for functionality.
    "root=$ROOT"
    # Set the initial ramdisk to the microcode, for functionality.
    "initrd=\\$MICROCODE"
    # Disable the watch dog, optimize for performance, and disable staggered spinup, for
    # performance.
    "nowatchdog workqueue.power_efficient=0 libahci.ignore_sss=1"
    # Enable early DRM modesetting, for functionality.
    "nvidia-drm.modeset=1"
  )
  local -r CMDLINE_STR="${CMDLINE_ARRAY[*]}"
  # Restrict kernel logging to errors, restrict systemd logging, restrict systemd initramfs logging,
  # and hide the cursor, for less verbosity.
  local -ra CMDLINE_SILENT_STR="quiet loglevel=3 rd.udev.log_priority=3 udev.log_priority=3 \
rd.systemd.show_status=auto vt.global_cursor_default=0"
  # Enable kernel debugging, ignore the kernel log level, allocate a larger log buffer,
  # and keep early logs, for more verbosity.
  local -ra CMDLINE_DEBUG_STR="debug ignore_loglevel log_buf_len=16M earlyprintk=efi,keep"
  # Enable rescue mode, for emergencies.
  local -ra CMDLINE_RESCUE_STR="rescue"

  function _update_entry
  {
    local -r VMLINUZ_PATH=/vmlinuz-linux${2}
    local -r INITRD_STR=initrd=initramfs-linux${2}.img
    local -r FALLBACK_INITRD_STR=initrd=initramfs-linux${2}.img

    case $TYPE in
      *debug*)
        echo "Updating $1 debug UEFI boot entry ($VMLINUZ_PATH)."
        update_entry "$1 (Debug)" "$VMLINUZ_PATH" "$INITRD_STR $CMDLINE_STR $CMDLINE_DEBUG_STR"
        ;;
      *rescue-fallback*)
        echo "Updating $1 fallback rescue UEFI boot entry ($VMLINUZ_PATH)."
        update_entry "$1 (Fallback Rescue)" "$VMLINUZ_PATH" "$FALLBACK_INITRD_STR $CMDLINE_STR \
$CMDLINE_DEBUG_STR $CMDLINE_RESCUE_STR"
        ;;
      *rescue*)
        echo "Updating $1 rescue UEFI boot entry ($VMLINUZ_PATH)."
        update_entry "$1 (Rescue)" "$VMLINUZ_PATH" "$INITRD_STR $CMDLINE_STR $CMDLINE_DEBUG_STR \
$CMDLINE_RESCUE_STR"
        ;;
      *)
        echo "Updating $1 quiet UEFI boot entry ($VMLINUZ_PATH)."
        update_entry "$1 (Silent)" "$VMLINUZ_PATH" "$INITRD_STR $CMDLINE_STR $CMDLINE_SILENT_STR"
        ;;
    esac
  }

  local -r VMLINUZ_TKG_PATH="$(find /boot -mindepth 1 -maxdepth 1 -type f -name 'vmlinuz-linux-tkg*' -print -quit)"
  _update_entry "Arch Linux (TkG)" "${VMLINUZ_TKG_PATH#/boot/vmlinuz-linux}"
  _update_entry "Arch Linux (Vanilla)"

  echo "Setting Arch Linux (TkG) (Silent) as default."
  efibootmgr -q -O
  efibootmgr -q -o  "$(find_bootnum "Arch Linux (TkG) (Silent)")"
}