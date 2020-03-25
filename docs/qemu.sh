#!/bin/bash

# These are some notes of useful commands I've written while setting up a QEMU Virtual Machine for
# Debian versions 9 and 10.
echo "This is not meant to be ran as a script!"
exit 0

# This command creates a new disk to install to:
qemu-img create -f qcow2 debian-base.img 15G
# The qcow2 format allows zlib file compression (As opposed to the file "compression" of a raw disk
# with "holes", only writing used parts to the disk.), as well as snapshots. It's the format for
# QEMU, but can be exported with the qemu-nbd tool, or converted with qemu-img convert. The
# tradeoff of using this format is that it's less performant than the raw disk image.

qemu-system-x86_64 -machine pc,accel=kvm -cpu host -m 512M debian-9.9.0-amd64-xfce-CD-1.iso --enable-kvm
# This command specifies the installation media as the main raw hard disk image, but QEMU always
# complains about the format for it not being specified. I'm not really sure how I would
# specify the installer though.

# This is the final command I ended up with for running the installer.
qemu-system-x86_64 -machine pc,accel=kvm -cpu host -boot d -m 2G -hda debian-base.img -cdrom debian-9.9.0-amd64-xfce-CD-1.iso --enable-kvm

# This command creates a disk to record changes made to the base. The potential use for this would
# be running the installer, installing Debian to "debian-base.img", and not writing to that image
# from that point on. Therefore, we can derive images, like "debian-main.img", and still have the
# ability to start fresh. The issue of this in practice is that the base image becomes quickly
# outdated.
qemu-img create -f qcow2 -b debian-base.img debian-main.img 15G

# These commands create a bridge connection for use with QEMU. I never got this working, because
# there are somewhat significant complexities in setting up a bridge with a wireless connection.
nmcli c add type bridge ifname br0 con-name "QEMU Bridge" stp no
nmcli c add type bridge-slave ifname wlp37s0 con-name "Main Wireless Slave" master br0