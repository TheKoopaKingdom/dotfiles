#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh

declare -r PROGRAM_NAME=${0##*/}

# Prints the usage message for this script.
print_help() {
  # Keep the help string in its own variable because a single quote in a heredoc messes up syntax
  # highlighting.
  HELP_STRING="
Usage: $PROGRAM_NAME [-h] { run | install | create | uefi } [ image [ video-driver [ viewer [
install-image [ driver-image ]]]]]
Launches QEMU with an image. Please see the source of this script for possible options."
  echo "$HELP_STRING"
  exit 0
}

# Launches a QEMU image with the best options.
# Arguments:
#   - The name of the image to launch.
#   - (Optional) Video driver to use, out of "qxl", "virtio", and "std". Default "qxl".
#   - (Optional) Viewer to use, out of "spice", "qemu-stl", and "qemu-gtk". Default "spice".
#   - (Optional) An image to mount to the CD drive.
function launch_qemu() {
  # Use arguments.
  local -r main_img=$1
  if [[ $main_img = *"Win*" || $main_img = *"w10"* ]]; then
    local -r windows=true
  else
    local -r windows=false
  fi
  local -r qemu_video_driver=$2
  local -r qemu_viewer=$3
  if [[ -n $4 ]]; then
    local -r installer_img=$4
  fi
  if [[ -n $4 ]]; then
    local -r driver_img=$5
  fi

  # Define constants.
  local -r QEMU_EXE="qemu-system-x86_64"

  # Define options.
  local -a qemu_opts
  case ${qemu_video_driver,,} in
  *qxl*)
    info "Using QXL video driver."
    local -r QXL=true
    local -r VIDEO_DRIVER_STR=QXL
    ;;
  *virtio*)
    info "Using Virtio video driver."
    local -r VIRTIO=true
    local -r VIDEO_DRIVER_STR=Virtio
    ;;
  *)
    info "Using standard video driver."
    local -r STD=true
    local -r VIDEO_DRIVER_STR=Standard
    ;;
  esac
  case ${qemu_viewer,,} in
  *spice*)
    info "Using SPICE viewer."
    local -r SPICE=true
    local -r VIEWER_STR=SPICE
    ;;
  *qemu-sdl)
    info "Using QEMU SDL viewer."
    local -r QEMUSDL=true
    local -r VIEWER_STR=QEMU-SDL
    ;;
  *)
    info "Using QEMU GTK viewer."
    local -r QEMUGTK=true
    local -r VIEWER_STR=QEMU-GTK
    ;;
  esac
  if [[ -n $installer_img ]]; then
    info "Using installer image \"$installer_img\"."
  fi
  if [[ -n $driver_img ]]; then
    info "Using driver image \"$driver_img\"."
  fi

  # Standard Options
  # Emulate a PC with KVM acceleration. KVM is the best hypervisor currently, requiring the least
  # setup, and with good results.
  qemu_opts+="-machine pc,accel=kvm"
  # Pass through CPU attributes so that specific optimizations can be applied. This will result in
  # the following warning being printed:
  # "kernel: Decoding supported only on Scalable MCA processors."
  # Disabling the mca or mce flags doesn't seem to help this.
  #
  if [[ $windows = true ]]; then
    # Workaround: For Windows, core2duo is needed to avoid a BSOD on boot..
    qemu_opts+=" -cpu core2duo"
  else
    qemu_opts+=" -cpu host"
  fi
  # Allow the VM 3GB of RAM.
  qemu_opts+=" -m 3G"
  # Add Intel HD Audio.
  qemu_opts+=" -soundhw hda"
  # For QXL, add QXL paravirtual graphics card, for performance. Doing this from here allows us to
  # allocate more video memory, for supporting multiple heads if needed.
  # Workaround: max_outputs is required to avoid a low-resolution issue with QXL video.
  qemu_opts+=${QXL+" -device qxl-vga,max_outputs=1,vgamem_mb=32"}
  # For Virtio graphics, add Virtio graphics card, for performance. Doing this from here seems to
  # work better
  qemu_opts+=${VIRTIO+" -device virtio-vga"}
  # Add a virtio serial port PCI device, to integrate with SPICE.
  qemu_opts+=${SPICE+" -device virtio-serial-pci"}
  # Add a virtio serial port input device, that the guest spice-vdagent can access.
  qemu_opts+=${SPICE+" -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"}
  # Set the name of the VM.
  qemu_opts+=" -name main_img.$VIDEO_DRIVER_STR.$VIEWER_STR"

  # Block Device Options

  if [[ $main_img != "none" ]]; then
    # Use the disk image as vda, through virtio.
    qemu_opts+=" -drive file=$main_img,if=virtio,index=0,media=disk"
  fi
  # Use an installer ISO as a CD-ROM image, if specified.
  qemu_opts+=${installer_img+" -drive file=$installer_img,index=1,media=cdrom"}
  # Use a drive ISO as a CD-ROM image, if specified. This is meant for an image with virtio drivers.
  qemu_opts+=${driver_img+" -drive file=$driver_img,index=2,media=cdrom"}
  # Use the OVMF binary as the bios file.
  qemu_opts+=" -bios /usr/share/edk2-ovmf/x64/OVMF.fd"
  # Add a virtual filesystem for a directory shared with the host.
  qemu_opts+=" -virtfs local,path=${QR_SHARE-/home/kyle/Terrace/Documents/Virtualization/Share},\
mount_tag=share,security_model=none"

  # USB Options

  # Display Options
  # For QEMU GTK, enable the respective UI.
  qemu_opts+=${QEMUGTK+" -display gtk"}
  # For QEMU SDL, enable the respective UI. Enable OGL for virtio, unfortunately this seems to be
  # the only display it works with.
  qemu_opts+=${QEMUSDL+" -display sdl"${VIRTIO+",gl=on"}}
  # For Spice, enable the respective UI.
  # Research shows that I have no idea how one would go about changing the app here. There doesn't
  # seem to be a SPICE mime type, and xdg-open just beelines for remote-viewer. perl-file-mimeinfo
  # has no idea what it's even looking at.
  qemu_opts+=${SPICE+" -display spice-app"}
  # For standard, enable the standard video driver.
  qemu_opts+=${STD+" -vga std"}
  # For QXL, disable the VGA card because we will have a separate QXL device.
  qemu_opts+=${QXL+" -vga none"}
  # For Virtio, enable the virtio video driver.
  qemu_opts+=${VIRTIO+" -vga none"}
  # Enable SPICE, using a Unix socket, without authentication. To make full use of this, Debian
  # packages "spice-vdagent xserver-xorg-video-qxl" should be installed. See:
  # https://wiki.archlinux.org/index.php/QEMU#SPICE_support_on_the_guest
  qemu_opts+=${SPICE+" -spice unix,disable-ticketing"}

  # i386 Target Options

  # Network Options

  # Character Device Options
  # Add a Spice VM Channel character device, for cut/paste support, that spice-vdagent can access.
  qemu_opts+=${SPICE+" -chardev spicevmc,id=spicechannel0,name=vdagent"}

  # Bluetooth Options

  # TPM Options

  # Linux/Multiboot Boot Options

  # Debug/Expert Options
  # Enable full KVM virtualization, for performance.
  qemu_opts+=" -enable-kvm"
  # Daemonize QEMU, to manually run the SPICE client.
  # qemu_opts+=" -daemonize"

  # Generic Object Creation Options

  # Device URL Syntax Options

  info "QEMU Reeves starting up with options \"$qemu_opts\"."
  # Start the new system.
  # shellcheck disable=SC2086
  "$QEMU_EXE" $qemu_opts
}

# Calls launch-qemu(), prompting the user with a dialog to select a QEMU image if needed.
# Arguments:
#   - (Optional) Name of the image to launch. Defaults to user selection.
#   - (Optional) Video driver to use, out of "qxl", "virtio", and "std". Default "qxl".
#   - (Optional) Viewer to use, out of "spice", "qemu-stl", and "qemu-gtk". Default "spice".
# Outputs:
#   Output of QEMU.
function qemu_reeves() {
  local -r ACTION=${1-run}
  local -r IMAGE_NAME=$2
  local -r VIDEO_DRIVER=${3-qxl}
  local -r VIEWER=${4-spice}
  local -r INSTALLER_IMAGE=$5
  local -r DRIVER_IMAGE=$6

  while getopts "h" opt; do
    case $opt in
    h)
      print_help
      ;;
    *)
      break
      ;;
    esac
  done

  info "QEMU Reeves Starting"
  info "https://gitlab.com/CodingKoopa/comet-observatory"

  if [[ $ACTION = "run" || $ACTION = "install" ]]; then
    local image=$HOME/Terrace/Documents/Virtualization/$IMAGE_NAME.img

    if [[ ! -f "$image" ]]; then
      # Make the file array empty if there aren't matches.
      shopt -s nullglob
      # Make an array of QEMU images.
      local -ra IMAGES=("$HOME"/Terrace/Documents/Virtualization/*.img)

      image=$(zenity --list \
        --width 1000 \
        --height 400 \
        --title "Select an image to launch" \
        --column="Name" \
        "${IMAGES[@]}")
    fi
    if [[ -n "$image" ]]; then
      if [[ -f "$image" ]]; then
        if [[ $ACTION = "install" ]]; then
          if [[ ! -f "$INSTALLER_IMAGE" ]]; then
            zenity --error \
              --width 1000 \
              --height 400 \
              --title "Install image not provided" \
              --text="You must provide an installer image to be mounted."
            return 1
          else
            launch_qemu "$image" "$VIDEO_DRIVER" "$VIEWER" "$INSTALLER_IMAGE" "$DRIVER_IMAGE"
          fi
        else
          launch_qemu "$image" "$VIDEO_DRIVER" "$VIEWER"
        fi
      else
        zenity --error --text "Image not found."
      fi
    fi
  elif [[ $ACTION = "create" ]]; then
    info "Creating a blank image."
    qemu-img create -f qcow2 blank-image.img 30G
  elif [[ "$ACTION" = "uefi" ]]; then
    info "Booting into Tianocore UEFI."
    launch_qemu none "$VIDEO_DRIVER" "$VIEWER"
  else
    print_help
  fi
}
