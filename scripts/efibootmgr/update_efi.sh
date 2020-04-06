#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

set -e

# shellcheck source=../bash/common.sh
source "$COMET_OBSERVATORY/scripts/bash/common.sh"

# Finds the bootnum from the name of a boot entry.
# Arguments:
#   - The name of the boot entry to find.
# Outputs:
#   The bootnums of the found boot entries, or nothing if none is found.
function find_bootnum()
{
  # Escapes a string for usage in a sed pattern. Sed expression copied from 
  # https://stackoverflow.com/a/2705678.
  # Arguments:
  #   - The string to escape.
  # Outputs:
  #   The escaped string.
  function sed_escape_pattern()
  {
    if [[ $# -ge 1 ]]; then
      # shellcheck disable=SC1003
      printf '%s\n' "$1" | sed 's/[]\\'"${2:-/}"'$*.^[]/\\&/g'
    else
      sed 's/[]\\/$*.^[]/\\&/g'
    fi
  }

  efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? '"$(sed_escape_pattern "$1")"'$/\1/p'
}

# Removes a boot entry if it exists.
# Arguments:
#   - The label of the boot entry.
# Outputs:
#   Deletion message.
function remove_entry_if_existing()
{
  local -r LABEL=$1

  bootnum="$(find_bootnum "$LABEL")"
  if [[ -n "$bootnum" ]]; then
    info "Existing boot entry for \"$LABEL\" found, deleting."
    efibootmgr -q -b "$bootnum" -B
  fi
}

# Adds a UEFI boot entry. Empty parameters are handled like unset.
# Arguments:
#   - The label of the boot entry.
#   - The loader for the boot entry.
#   - Command line arguments for the loader.
# Outputs:
#   The bootnum of the boot entry.
function add_entry()
{
  local -r LABEL=$1
  local -r LOADER=$2
  local -r CMDLINE=$3

  # It's necessary to delete the existing entry and replace it, because efibootmgr doesn't support
  # editing an existing entry: https://github.com/rhboot/efibootmgr/issues/49.
  remove_entry_if_existing "$LABEL"
  efibootmgr -q -c --label "$LABEL" -l "$LOADER" -u "$CMDLINE"
}

# Updates Arch Linux UEFI boot entries.
# Arguments:
#   The type of entries to generate, out of "normal", "quiet", "debug", "rescue", and
# "fallback-rescue".
# Outputs:
#   Changes being made to EFI boot entries.
function update_efi()
{
  figlet -k -f slant update-efi | lolcat -f -s 100 -p 1
  info "Comet Observatory UEFI Boot Entry Updater Script"
  info "https://gitlab.com/CodingKoopa/comet-observatory"

  local -r TYPE=$1  

  local -r ROOT="PARTUUID=91fb9373-d9b2-4e6d-a376-0388afe85bf0"
  local -r MICROCODE="amd-ucode.img"

  # Set the initial ramdisk to the microcode, for functionality. This is set separately because it
  # has to come before the kernel initrd.
  local -r MICROCODE_INITRD_STR="initrd=\\$MICROCODE"
  local -ra CMDLINE_ARRAY=(
    # Enable r/w on the file system, for functionality.
    "rw"
    # Set the root filesystem, for functionality.
    "root=$ROOT"
    # Disable the watch dog, optimize for performance, and disable staggered spinup, for
    # performance.
    "nowatchdog workqueue.power_efficient=0 libahci.ignore_sss=1"
    # Enable early DRM modesetting, for functionality.
    "nvidia-drm.modeset=1"
  )
  local -r CMDLINE_STR="${CMDLINE_ARRAY[*]}"
  # Set the kernel logging level to errors, set the initrd systemd logging level to errors,
  # and hide the cursor, for less verbosity.
  local -ra CMDLINE_SILENT_STR="quiet rd.udev.log_priority=3 vt.global_cursor_default=0"
  # Print early EFI kernel messages, allocate a larger kernel message buffer, ignore the kernel
  # logging level, allocate a larger log buffer, set the systemd log level to debug, write systemd
  # logs to the kernel log buffer, and allow unlimited logging from userspace, for more verbosity.
  local -ra CMDLINE_DEBUG_STR="earlyprintk=efi,keep log_buf_len=16M ignore_loglevel \
systemd.log_level=debug systemd.log_target=kmsg printk.devkmsg=on"
  # Enable rescue mode, for emergencies.
  local -ra CMDLINE_RESCUE_STR="rescue"

  # Decides what configuration to use, and adds a UEFI boot entry acoordingly using add-entry().
  # Arguments:
  #   - The name of the kernel.
  #   - The vmlinux suffix, if applicable.
  # Outputs:
  #   Entry addition progress.
  function add_entry_decide_configuration
  {
    local -r VMLINUZ_PATH=/vmlinuz-linux${2}
    local -r KERNEL_INITRD_STR=initrd=initramfs-linux${2}.img
    local -r FALLBACK_KERNEL_INITRD_STR=initrd=initramfs-linux${2}.img

    case $TYPE in
      *debug*)
        info "Updating $1 debug UEFI boot entry ($VMLINUZ_PATH)."
        add_entry "$1 (Debug)" "$VMLINUZ_PATH" "$MICROCODE_INITRD_STR $KERNEL_INITRD_STR \
$CMDLINE_STR $CMDLINE_DEBUG_STR"
        ;;
      *rescue-fallback*)
        info "Updating $1 fallback rescue UEFI boot entry ($VMLINUZ_PATH)."
        add_entry "$1 (Fallback Rescue)" "$VMLINUZ_PATH" "$MICROCODE_INITRD_STR \
$FALLBACK_KERNEL_INITRD_STR $CMDLINE_STR $CMDLINE_DEBUG_STR $CMDLINE_RESCUE_STR"
        ;;
      *rescue*)
        info "Updating $1 rescue UEFI boot entry ($VMLINUZ_PATH)."
        add_entry "$1 (Rescue)" "$VMLINUZ_PATH" "$MICROCODE_INITRD_STR $KERNEL_INITRD_STR \
$CMDLINE_STR $CMDLINE_DEBUG_STR $CMDLINE_RESCUE_STR"
        ;;
      *quiet*)
        info "Updating $1 quiet UEFI boot entry ($VMLINUZ_PATH)."
        add_entry "$1 (Silent)" "$VMLINUZ_PATH" "$MICROCODE_INITRD_STR $KERNEL_INITRD_STR \
$CMDLINE_STR $CMDLINE_SILENT_STR"
        ;;
      *)
        info "Updating $1 normal UEFI boot entry ($VMLINUZ_PATH)."
        add_entry "$1 (Normal)" "$VMLINUZ_PATH" "$MICROCODE_INITRD_STR $KERNEL_INITRD_STR $CMDLINE_STR"
        ;;
    esac
  }

  local -r VMLINUZ_TKG_PATH=$(find /boot -mindepth 1 -maxdepth 1 -type f \
-name 'vmlinuz-linux-tkg*' -print -quit)
  # Assign a vmlinux suffix to the different kernels.
  local -rA KERNELS=(
    ["Vanilla"]=""
    ["TkG"]="${VMLINUZ_TKG_PATH#/boot/vmlinuz-linux}"
  )

  local -ra CONFIGURATIONS=(
    "Debug"
    "Rescue"
    "Fallback Rescue"
    "Silent"
    "Normal"
  )

  info "Scanning existing boot entries."
  for KERNEL in "${!KERNELS[@]}"; do
    for CONFIGURATION in "${CONFIGURATIONS[@]}"; do
      remove_entry_if_existing "Arch Linux ($KERNEL) ($CONFIGURATION)"
    done
  done

  info "Adding new boot entries."
  for KERNEL in "${!KERNELS[@]}"; do
    add_entry_decide_configuration "Arch Linux ($KERNEL)" "${KERNELS[${KERNEL}]}"
  done

  local -r DEFAULT_ENTRY="Arch Linux (TkG) (Normal)"
  local -r DEFAULT_ENTRY_NUM=$(find_bootnum "$DEFAULT_ENTRY")
  if [[ -n $DEFAULT_ENTRY_NUM ]]; then
    info "Setting $DEFAULT_ENTRY as default entry."
    efibootmgr -q -O
    efibootmgr -q -o "$DEFAULT_ENTRY_NUM"
  fi
}