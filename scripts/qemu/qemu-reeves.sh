#!/bin/bash

# shellcheck source=../bash/common.sh
source "$COMET_OBSERVATORY/scripts/bash/common.sh"

# Launches a QEMU image with the best options.
# Arguments:
#   - The name of the image to launch.
#   - (Optional) The video driver to use, out of "qxl", "virtio", and "std". Default "std".
#   - (Optional) The viewer to use, out of "spice", "qemu-sdl", and "qemu-gtk". Default "qemu-gtk".
function launch-qemu() {
  # Use arguments.
  local -r QEMU_IMG="$1"
  local -r QEMU_VIDEO_DRIVER="$2"
  local -r QEMU_VIEWER="$3"

  # Define constants.
  local -r QEMU_EXE="qemu-system-x86_64"

  # Define options.
  local -a qemu_opts
  case ${QEMU_VIDEO_DRIVER,,} in
    *qxl*)
      info "Using QXL video driver."
      local -r QXL=true
      local -r VIDEO_DRIVER_STR="QXL"
      ;;
    *virtio*)
      info "Using Virtio video driver."
      local -r VIRTIO=true
      local -r VIDEO_DRIVER_STR="Virtio"
      ;;
    *)
      info "Using standard video driver."
      local -r STD=true
      local -r VIDEO_DRIVER_STR="Standard"
  esac
  case ${QEMU_VIEWER,,} in
    *spice*)
      info "Using SPICE viewer."
      local -r SPICE=true
      local -r VIEWER_STR="SPICE"
      ;;
    *qemu-sdl)
      info "Using QEMU SDL viewer."
      local -r QEMUSDL=true
      local -r VIEWER_STR="QEMU-SDL"
      ;;
    *)
      info "Using QEMU GTK viewer."
      local -r QEMUGTK=true
      local -r VIEWER_STR="QEMU-GTK"
      ;;
  esac

  # Standard Options
  # Emulate a PC with KVM acceleration. KVM is the best hypervisor currently, requiring the least 
  # setup, and with good results.
  qemu_opts+="-machine pc,accel=kvm"
  # Pass through CPU attributes so that specific optimizations can be applied. This will result in
  # the following warning being printed:
  # "kernel: Decoding supported only on Scalable MCA processors."
  # Disabling the mca or mce flags doesn't seem to help this.
  qemu_opts+=" -cpu host"
  # Allow 4 CPU cores.
  qemu_opts+=" -smp 4"
  # Allow the VM 2GB of RAM.
  qemu_opts+=" -m 2G"
  # For QXL, add QXL paravirtual graphics card, for performance. Doing this from here allows us to
  # allocate more video memory, for supporting multiple heads if needed.
  qemu_opts+=${QXL+" -device qxl-vga,vgamem_mb=32"}
  # For Virtio graphics, add Virtio graphics card, for performance. Doing this from here seems to
  # work better
  qemu_opts+=${VIRTIO+" -device virtio-vga"}
  # Add a virtio serial port PCI device, to integrate with SPICE.
  qemu_opts+=${SPICE+" -device virtio-serial-pci"}
  # Add a virtio serial port input device, that the guest spice-vdagent can access. 
  qemu_opts+=${SPICE+" -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"}
  # Set the name of the VM.
  qemu_opts+=" -name Debian.$VIDEO_DRIVER_STR.$VIEWER_STR"

  # Block Device Options

  # Add a virtual filesystem for a directory shared with the host.
  qemu_opts+=" -virtfs local,path=${QR_SHARE-/home/kyle/Library/Virtualization/Share},\
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
  "$QEMU_EXE" $qemu_opts "$QEMU_IMG"
}

# Calls launch-qemu(), prompting the user with a dialog to select a QEMU image if needed.
# Arguments:
#   - (Optional) Name of the image to launch. Defaults to user selection.
#   - (Optional) Video driver to use, out of "qxl", "virtio", and "std". Default "virtio".
#   - (Optional) Viewer to use, out of "spice", "qemu-stl", and "qemu-gtk". Default "spice".
# Outputs:
#   Output of QEMU.
function qemu-reeves()
{
  local -r IMAGE_NAME="$1"
  local -r VIDEO_DRIVER=${2-virtio}
  local -r VIEWER=${3-spice}

  info "QEMU Reeves Starting"
  info "https://gitlab.com/CodingKoopa/comet-observatory"

  local image="$HOME"/Library/Virtualization/"$IMAGE_NAME".img

  if [[ ! -f "$image" ]]; then
    # Make the file array empty if there aren't matches.
    shopt -s nullglob
    # Make an array of QEMU images.
    local -ra IMAGES=("$HOME"/Library/Virtualization/*.img)

    image=$(zenity --list \
        --width 1000 \
        --height 400 \
        --title "Select an image to launch" \
        --column="Name" \
        "${IMAGES[@]}")
  fi

  if [[ -n "$image" ]]; then
    if [[ -f "$image" ]]; then
      launch-qemu "$image" "$VIDEO_DRIVER" "$VIEWER"
    else
      zenity --error --text "Image not found."
    fi
  fi
}