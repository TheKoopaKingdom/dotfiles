#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh

shopt -s nocasematch

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
#   - (Optional) Video driver to use, out of "qxl", "virgil", and "std". Default "std".
#   - (Optional) Viewer to use, out of "spice", "qemu-std", and "qemu-gtk". Default "qemu-gtk".
#   - (Optional) An installer image to mount to the CD drive.
#   - (Optional) A driver image to mount to another CD drive.
function launch_qemu() {
  # Use arguments.
  local -r main_img=$1
  local -r qemu_video_driver=$2
  local -r qemu_viewer=$3
  if [[ -n $4 ]]; then
    local -r installer_img=$4
  fi
  if [[ -n $5 ]]; then
    local -r driver_img=$5
  fi
  case ${qemu_video_driver,,} in
  *qxl*)
    info "Using QXL video driver."
    local -r video_driver_qxl=true
    local -r video_driver_str=QXL
    ;;
  *virgil*)
    info "Using Virgil video driver."
    local -r video_driver_virgil=true
    local -r video_driver_str=Virgil
    ;;
  *)
    info "Using standard video driver."
    local -r video_driver_std=true
    local -r video_driver_str=Standard
    ;;
  esac
  case ${qemu_viewer,,} in
  *spice*)
    info "Using SPICE viewer."
    local -r viewer_spice=true
    local -r viewer_str=SPICE
    ;;
  *qemu-sdl)
    info "Using QEMU SDL viewer."
    local -r viewer_qemu_sdl=true
    local -r viewer_str=QEMU-SDL
    ;;
  *)
    info "Using QEMU GTK viewer."
    local -r viewer_qemu_gtk=true
    local -r viewer_str=QEMU-GTK
    ;;
  esac
  local -r vm_name=$(basename "$main_img" .img).$video_driver_str.$viewer_str
  local -r vm_socket_addr=/tmp/$vm_name.socket
  if [[ -n $installer_img ]]; then
    info "Using installer image \"$installer_img\"."
  fi
  if [[ -n $driver_img ]]; then
    info "Using driver image \"$driver_img\"."
  fi

  # Define constants.
  local -r qemu_exe="qemu-system-x86_64"

  # Define options.
  local -a qemu_opts

  # Standard Options
  # Emulate a PC with KVM acceleration. KVM is the best hypervisor currently, requiring the least
  # setup, and with good results.
  qemu_opts+="-machine pc,accel=kvm"
  if [[ $main_img =~ win || $main_img =~ w10 ]]; then
    # Workaround: For Windows, core2duo is sometimes needed to avoid a BSOD on boot.
    qemu_opts+=" -cpu core2duo"
    # This and the above workaround are mutually exclusive!
    # qemu_opts+=" -cpu host"
  else
    # Pass through CPU attributes so that specific optimizations can be applied. An issue with this
    # is that it results in the following warning being printed:
    #
    # kernel: Decoding supported only on Scalable MCA processors.
    #
    # Disabling the mca or mce flags doesn't seem to help this.
    qemu_opts+=" -cpu host"
  fi
  # Enable Hyper-V enlightenments. More info:
  # https://blog.wikichoon.com/2014/07/enabling-hyper-v-enlightenments-with-kvm.html
  # This is dependent on "-cpu"!
  qemu_opts+=",hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time"
  # Use multiple CPU cores.
  qemu_opts+=" -smp 4"
  # Use 16GB of RAM.
  qemu_opts+=" -m 16G"
  if [[ $main_img == *"temple"* ]]; then
    # For TempleOS, add a basic PC speaker.
    qemu_opts+=" -soundhw pcspk "
  elif [[ $main_img == *"wxp"* ]]; then
    # For Windows XP, add its supported Intel 82801AA AC97 audio.
    qemu_opts+=" -soundhw ac97"
  else
    # Add Intel HD Audio.
    qemu_opts+=" -soundhw hda"
  fi
  # Workaround: max_outputs is required to avoid a low-resolution issue with QXL video. This is also
  # necessary to support multiple heads of decent resolution. In order to apply this configuration,
  # we add a QXL paravirtual graphics card here.
  # This and "-vga qxl" are mutually exclusive!
  # This is dependent on "-vga none"!
  qemu_opts+=${video_driver_qxl+" -device qxl-vga,max_outputs=1,vgamem_mb=64"}
  # For virgil graphics, add a virtio graphics card, for performance. Doing this from here seems to
  # work better.
  # This and "-vga virtio" are mutually exclusive!
  qemu_opts+=${video_driver_virgil+" -device virtio-vga"}
  # For SPICE, add a virtio serial device.
  qemu_opts+=${viewer_spice+" -device virtio-serial"}
  # For SPICE, add a virtio serial port input device, for vdagent. This is used to propagate changes
  # in the monitor configuration, and clipboard.
  # This is dependent on the vdagentchannel "-chardev"!
  qemu_opts+=${viewer_spice+" -device virtserialport,chardev=vdagentchannel,\
name=com.redhat.spice.0"}
  # For SPICE, add a virtio serial port input device, for webdav. This is used for folder sharing.
  qemu_opts+=${viewer_spice+" -device virtserialport,chardev=webdavport,\
name=org.spice-space.webdav.0"}
  # Set the name of the VM.
  qemu_opts+=" -name $vm_name"

  # Block Device Options
  if [[ $main_img != "none" ]]; then
    # Use the disk image as vda, through virtio. Use native Linux AIO, and disable the cache.
    qemu_opts+=" -drive file=$main_img,if=virtio,index=0,media=disk,aio=native,cache=none"
  fi
  # Use an installer ISO as a CD-ROM image, if specified.
  qemu_opts+=${installer_img+" -drive file=$installer_img,index=1,media=cdrom"}
  if [[ $main_img != *"wxp"* ]]; then
    # Use a drive ISO as a CD-ROM image, if specified. This is meant for an image with virtio
    # drivers.
    qemu_opts+=${driver_img+" -drive file=$driver_img,index=2,media=cdrom"}
  else
    # For Windows XP, use a floppy disk device. Enable the boot menu so that QEMU doesn't boot the
    # floppy.
    qemu_opts+=${driver_img+" -drive file=$driver_img,index=0,if=floppy,format=raw -boot menu=on"}
  fi
  if [[ $main_img != *"bios"* && $main_img != *"wxp"* ]]; then
    # For images that use UEFI (the default, for images without "bios" in them), use the OVMF binary
    # as the bios file.
    qemu_opts+=" -bios /usr/share/edk2-ovmf/x64/OVMF.fd"
  fi
  # Add a virtual filesystem share.
  # This and the smb share are mutually exclusive!
  # qemu_opts+=" -virtfs local,path=$HOME,mount_tag=share,security_model=none"

  # USB Options

  # Display Options
  # For QEMU GTK, enable the respective UI.
  # OpenGL support does not seem to work properly here.
  qemu_opts+=${viewer_qemu_gtk+" -display gtk"}
  # For QEMU SDL, enable the respective UI.
  # For virgl, enable OpenGL.
  qemu_opts+=${viewer_qemu_sdl+" -display sdl"${video_driver_virgil+",gl=on"}}
  # For Spice, enable the respective UI.
  # I have no idea how one would go about changing the app here. There doesn't seem to be a SPICE
  # mime type, and xdg-open just beelines for remote-viewer. perl-file-mimeinfo has no idea what
  # it's even looking at.
  # OpenGL support does not seem to work properly here.
  # qemu_opts+=${viewer_spice+" -display spice-app"}
  # For standard, enable the standard video driver.
  qemu_opts+=${video_driver_std+" -vga std"}
  # For certain QXL configurations, disable the VGA card because we will have a separate QXL device.
  # This and "-vga qxl" are mutually exclusive!
  qemu_opts+=${video_driver_qxl+" -vga none"}
  # For QXL, enable the qxl video driver.
  # This and "-device qxl-vga" are mutually exclusive!
  # qemu_opts+=${video_driver_qxl+" -vga qxl"}
  # For virgl, enable the virtio video driver.
  # This and "-device virtio-vga" are mutually exclusive!
  # qemu_opts+=${video_driver_virgil+" -vga virtio"}
  # Enable SPICE, using a Unix socket, without authentication. Specifying a Unix socket path is not
  # necessary, because we are using the Spice applicationas the display. To make full use of SPICE,
  # Debian packages "spice-vdagent xserver-xorg-video-qxl" should be installed. See:
  # https://wiki.archlinux.org/index.php/QEMU#SPICE_support_on_the_guest
  # For virgl, enable OpenGL.
  qemu_opts+=${viewer_spice+" -spice unix,addr=$vm_socket_addr,disable-ticketing\
${video_driver_virgil+",gl=on"}"}

  # i386 Target Options

  # Network Options
  # Add a user mode host network backend, and its accompanying virtio NIC hardware.
  qemu_opts+=" -nic user,model=virtio-net-pci"
  # Add an SMB share.
  # This and the virtfs share are mutually exclusive!
  # This is dependent on "-nic"!
  # qemu_opts+=",smb=$HOME"

  # Character Device Options
  # Add a spicevmc channel for vdagent.
  qemu_opts+=${viewer_spice+" -chardev spicevmc,id=vdagentchannel,name=vdagent"}
  # Add a SPICE port for webdav.
  qemu_opts+=${viewer_spice+" -chardev spiceport,id=webdavport,name=org.spice-space.webdav.0"}

  # Bluetooth Options

  # TPM Options

  # Linux/Multiboot Boot Options

  # Debug/Expert Options
  if [[ -n $viewer_spice ]]; then
    # Daemonize QEMU, to manually run the SPICE client.
    qemu_opts+=" -daemonize"
  fi
  # Don't create default devices, so that there aren't extreneous CD and floppy drive.
  qemu_opts+=" -nodefaults"

  # Generic Object Creation Options

  # Device URL Syntax Options

  info "QEMU Reeves starting up with options \"$qemu_opts\"."
  # Start the new system.
  # shellcheck disable=SC2086
  "$qemu_exe" $qemu_opts

  if [[ -n $viewer_spice ]]; then
    # Start spicy manually.
    spicy --uri="spice+unix://$vm_socket_addr" --spice-shared-dir="$HOME" -f
    # Start virt-viewer manually.
    # remote-viewer "spice+unix://$vm_socket_addr"
  fi
}

# Calls launch_qemu(), handling defaults for unspecified options.
# Arguments:
#   - The subcommand to run, one of:
#     - "help", to print the usage message.
#     - "run", to run a virtualized operating system.
#     - "install", to install a virtualized operating system. This is identical to "run", but adds
# block devices for the installer and driver image.
#   - (Optional) Name of the image to launch. Defaults to user selection.
#   - (Optional) Video driver to use, out of "qxl", "virgil", and "std". Defaults to QXL.
#   - (Optional) Viewer to use, out of "spice", "qemu-sdl", and "qemu-gtk". Defaults to SPICE.
#   - (Required for "install") Path to the installer image.
#   - (Optional for "install") Path to the driver image. Omitted by default.
# Outputs:
#   Output of QEMU.
function qemu_reeves() {
  local -r action=${1-run}
  local -r image_name=$2
  local -r video_driver=${3-qxl}
  local -r viewer=${4-spice}
  local -r _installer_img=$5
  local -r _driver_img=$6

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

  if [[ $action = "run" || $action = "install" ]]; then
    # Strip the extension if present, to allow this to be used with or without that.
    local image=$HOME/Terrace/Documents/Virtualization/${image_name%.*}.img

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
        if [[ $action = "install" ]]; then
          if [[ ! -f "$_installer_img" ]]; then
            zenity --error \
              --width 1000 \
              --height 400 \
              --title "Install image not provided" \
              --text="You must provide an installer image to be mounted."
            return 1
          else
            launch_qemu "$image" "$video_driver" "$viewer" "$_installer_img" "$_driver_img"
          fi
        else
          launch_qemu "$image" "$video_driver" "$viewer"
        fi
      else
        zenity --error --text "Image not found."
      fi
    fi
  elif [[ $action = "create" ]]; then
    info "Creating a blank image."
    qemu-img create -f qcow2 blank-image.img 10G
  elif [[ "$action" = "uefi" ]]; then
    info "Booting into Tianocore UEFI."
    launch_qemu none "$video_driver" "$viewer"
  else
    print_help
  fi
}
